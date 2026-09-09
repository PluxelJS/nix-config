#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

state="$test_root/state"
home="$test_root/home"
fake_bin="$test_root/bin"
script="$test_root/dev-runtime"
log="$test_root/calls.log"
mkdir -p "$home" "$fake_bin"

sed "s#@resourceRoot@#$repo_root/home/files/dev-runtime#g" \
  "$repo_root/home/files/dev-runtime/dev-runtime" >"$script"
chmod +x "$script"

cat >"$fake_bin/podman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log() {
  {
    printf 'podman'
    printf ' %s' "$@"
    printf '\n'
  } >>"${DEV_RUNTIME_TEST_LOG:?}"
}

contains_arg() {
  local needle="$1"
  shift
  local arg
  for arg in "$@"; do
    [[ "$arg" == "$needle" ]] && return 0
  done
  return 1
}

if [[ "${1:-}" == compose ]]; then
  shift
  log compose "$@"
  if contains_arg ps "$@" && contains_arg -q "$@"; then
    echo 'podman-compose ps does not accept service arguments' >&2
    exit 2
  fi
  exit 0
fi

if [[ "${1:-}" == ps ]]; then
  log "$@"
  for arg in "$@"; do
    case "$arg" in
      label=com.docker.compose.service=*)
        printf '%s-container\n' "${arg#label=com.docker.compose.service=}"
        ;;
    esac
  done
  exit 0
fi

if [[ "${1:-}" == exec ]]; then
  shift
  log exec "$@"
  exit 0
fi

log "$@"
EOF
chmod +x "$fake_bin/podman"

cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'curl'
  printf ' %s' "$@"
  printf '\n'
} >>"${DEV_RUNTIME_TEST_LOG:?}"
EOF
chmod +x "$fake_bin/curl"


cat >"$fake_bin/cliproxy-runtime" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'cliproxy %s state=%s network=%s\n' "$*" "$CLIPROXY_STATE_DIR" "$CLIPROXY_EXTERNAL_NETWORK" >>"${DEV_RUNTIME_TEST_LOG:?}"
if [[ "$1" == up ]]; then
  mkdir -p "$CLIPROXY_STATE_DIR"
  touch "$CLIPROXY_STATE_DIR/compose.json"
fi
EOF
chmod +x "$fake_bin/cliproxy-runtime"

env_prefix=(
  "PATH=$fake_bin:$PATH"
  "DEV_RUNTIME_CLIPROXY_COMMAND=$fake_bin/cliproxy-runtime"
  "HOME=$home"
  "DEV_RUNTIME_STATE_DIR=$state"
  "DEV_RUNTIME_TEST_LOG=$log"
)

usage_spec="$(env "${env_prefix[@]}" "$script" --usage)"
[[ "$usage_spec" == *'cmd "pg-create"'* ]] || fail "--usage did not expose pg-create"
[[ "$usage_spec" == *'"new-api"'* ]] || fail "--usage did not expose new-api"
[[ ! -e "$state" ]] || fail "--usage unexpectedly initialized state"

env "${env_prefix[@]}" "$script" init
[[ -f "$state/.env" ]] || fail "init did not create .env"
[[ -f "$state/enabled" ]] || fail "init did not create enabled"
[[ -f "$state/schema-version" ]] || fail "init did not create schema marker"
[[ -d "$state/postgres-databases" ]] || fail "init did not create managed database state dir"
[[ "$(stat -c %a "$state/.env")" == 600 ]] || fail ".env mode is not 0600"
[[ "$(stat -c %a "$state/enabled")" == 600 ]] || fail "enabled mode is not 0600"
[[ "$(stat -c %a "$state/schema-version")" == 600 ]] || fail "schema marker mode is not 0600"
[[ "$(stat -c %a "$state/postgres-databases")" == 700 ]] \
  || fail "managed database state dir mode is not 0700"
grep -qx 'postgres' "$state/enabled" || fail "postgres was not enabled by default"
grep -qx 'dragonfly' "$state/enabled" || fail "dragonfly was not enabled by default"
grep -qx 'POSTGRES_EXTRA_DATABASES=' "$state/.env" \
  || fail "proxy database was still pre-created through extra database defaults"
grep -qx 'NEW_API_PORT=23000' "$state/.env" || fail "New API default port changed"
secret="$(sed -n 's/^NEW_API_SESSION_SECRET=//p' "$state/.env")"
[[ ${#secret} == 64 ]] || fail "session secret missing"
env "${env_prefix[@]}" "$script" init
[[ "$(sed -n 's/^NEW_API_SESSION_SECRET=//p' "$state/.env")" == "$secret" ]] || fail "session secret rotated on init"
[[ "$(stat -c %a "$state/new-api")" == 700 ]] || fail "New API data directory is not private"
env_output="$(env "${env_prefix[@]}" "$script" env)"
[[ "$env_output" == *"NEW_API_URL=http://127.0.0.1:23000"* ]] || fail "New API URL missing"

: >"$log"
app_url="$(env "${env_prefix[@]}" "$script" pg-create sample-api)"
[[ -f "$state/postgres-databases/sample_api.env" ]] \
  || fail "pg-create did not persist managed database metadata"
[[ "$(stat -c %a "$state/postgres-databases/sample_api.env")" == 600 ]] \
  || fail "managed database metadata mode is not 0600"
app_db_password="$(sed -n 's/^PGPASSWORD=//p' "$state/postgres-databases/sample_api.env")"
[[ "$app_url" == "DATABASE_URL=postgresql://sample_api_owner:$app_db_password@127.0.0.1:5432/sample_api" ]] \
  || fail "pg-create did not print the managed database URL"
[[ "$(env "${env_prefix[@]}" "$script" pg-url sample-api)" == "$app_url" ]] \
  || fail "pg-url did not return the stored managed database URL"
[[ "$(env "${env_prefix[@]}" "$script" pg-list)" == "sample_api" ]] \
  || fail "pg-list did not show the managed database"
grep -q -- 'exec -i postgres-container psql -U postgres -d postgres.*target_db=sample_api.*target_role=sample_api_owner.*target_password='"$app_db_password" "$log" \
  || fail "pg-create did not create the isolated database role"
grep -q -- 'exec -i postgres-container psql -U postgres -d sample_api.*target_role=sample_api_owner' "$log" \
  || fail "pg-create did not grant schema privileges"

if env "${env_prefix[@]}" "$script" pg-create BadName >"$test_root/bad-db.out" 2>&1; then
  fail "invalid PostgreSQL database name was accepted"
fi
grep -q 'PostgreSQL database names must match' "$test_root/bad-db.out" \
  || fail "invalid PostgreSQL database name error was unclear"

legacy_state="$test_root/legacy-state"
mkdir -p "$legacy_state"
printf '%s\n' vlogs >"$legacy_state/enabled"
env "${env_prefix[@]}" DEV_RUNTIME_STATE_DIR="$legacy_state" "$script" init
grep -qx 'postgres' "$legacy_state/enabled" || fail "legacy enabled state did not gain postgres"
grep -qx 'dragonfly' "$legacy_state/enabled" || fail "legacy enabled state did not gain dragonfly"
grep -qx 'vlogs' "$legacy_state/enabled" || fail "legacy enabled state did not keep existing target"
grep -qx '4' "$legacy_state/schema-version" || fail "legacy state was not marked as migrated"

typo_state="$test_root/typo-state"
mkdir -p "$typo_state"
printf '%s\n' postgres typo-target >"$typo_state/enabled"
printf '%s\n' 2 >"$typo_state/schema-version"
if env "${env_prefix[@]}" DEV_RUNTIME_STATE_DIR="$typo_state" "$script" list \
    >"$test_root/typo.out" 2>&1; then
  fail "unknown enabled target was accepted"
fi
grep -q 'unknown target' "$test_root/typo.out" \
  || fail "unknown enabled target error was unclear"

# New API has no database dependencies, including on persistent enablement.
env "${env_prefix[@]}" "$script" disable postgres dragonfly >/dev/null
: >"$log"
env "${env_prefix[@]}" "$script" enable --no-start new-api >/dev/null
[[ "$(cat "$state/enabled")" == new-api ]] || fail "New API enabled dependencies"
[[ ! -s "$log" ]] || fail "--no-start started containers"
env "${env_prefix[@]}" "$script" up >/dev/null
grep -q -- '--profile new-api up -d new-api' "$log" || fail "New API was not started"
if grep -q -- 'psql\|proxy-llm\|up -d postgres' "$log"; then
  fail "New API invoked legacy gateway or PostgreSQL"
fi
env "${env_prefix[@]}" "$script" disable new-api >/dev/null
[[ ! -s "$state/enabled" ]] || fail "disable did not persist"
grep -q -- 'stop new-api' "$log" || fail "disable did not stop New API"
: >"$log"
env "${env_prefix[@]}" "$script" down >/dev/null
grep -Fq -- '--profile vmetrics --profile vlogs --profile new-api down' "$log" || fail "down omitted optional profiles"
# CLIProxyAPI is delegated, with its own state but one dev-runtime owner.
: >"$log"
env "${env_prefix[@]}" "$script" enable --no-start cliproxy >/dev/null
[[ "$(cat "$state/enabled")" == cliproxy ]] || fail "cliproxy enablement missing"
[[ ! -s "$log" ]] || fail "cliproxy --no-start started services"
env "${env_prefix[@]}" "$script" up >/dev/null
grep -q 'cliproxy up' "$log" || fail "cliproxy was not started"
if grep -q 'compose .* up -d' "$log"; then fail "cliproxy started unrelated base services"; fi
grep -q "state=$state/cliproxy network=ahdg-dev-llm" "$log" || fail "cliproxy state or network incorrect"
env "${env_prefix[@]}" "$script" check cliproxy >/dev/null
grep -q 'cliproxy check' "$log" || fail "proxy check not delegated"
env "${env_prefix[@]}" "$script" ui cliproxy >/dev/null
grep -q 'cliproxy ui' "$log" || fail "web management not delegated"
env "${env_prefix[@]}" "$script" disable cliproxy >/dev/null
grep -q 'cliproxy down' "$log" || fail "cliproxy disable did not stop it"
[[ ! -s "$state/enabled" ]] || fail "cliproxy disable not persisted"
echo "dev-runtime tests passed"
