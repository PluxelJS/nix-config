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
    printf '%s-container\n' "${@: -1}"
  fi
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

cat >"$fake_bin/proxy-llm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'proxy-llm state=%s' "${PROXY_LLM_STATE_DIR:-}"
  printf ' %s' "$@"
  printf '\n'
} >>"${DEV_RUNTIME_TEST_LOG:?}"
EOF
chmod +x "$fake_bin/proxy-llm"

env_prefix=(
  "PATH=$fake_bin:$PATH"
  "HOME=$home"
  "DEV_RUNTIME_STATE_DIR=$state"
  "DEV_RUNTIME_TEST_LOG=$log"
)

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
grep -qx 'PROXY_LLM_STATE_DIR=.*/proxy-llm-dev-runtime' "$state/.env" \
  || fail "parallel proxy state dir was not isolated"
grep -qx 'PROXY_LLM_DB_USER=proxy_llm' "$state/.env" \
  || fail "parallel proxy database role was not isolated"
grep -qx 'PROXY_LLM_DB_PASSWORD=[[:xdigit:]]\{48\}' "$state/.env" \
  || fail "parallel proxy database password was not generated"
grep -qx 'PROXY_LLM_PORT=23001' "$state/.env" || fail "parallel hub port was not isolated"
grep -qx 'CLIPROXY_PORT=8318' "$state/.env" || fail "parallel api port was not isolated"

proxy_db_password="$(sed -n 's/^PROXY_LLM_DB_PASSWORD=//p' "$state/.env")"
env_output="$(env "${env_prefix[@]}" "$script" env)"
[[ "$env_output" == *"DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5432/postgres"* ]] \
  || fail "env did not print base postgres URL"
[[ "$env_output" == *"PROXY_LLM_DATABASE_URL=postgresql://proxy_llm:$proxy_db_password@127.0.0.1:5432/claude_code_hub"* ]] \
  || fail "env did not print isolated proxy postgres URL"
[[ "$env_output" == *"PROXY_LLM_URL=http://127.0.0.1:23001"* ]] \
  || fail "env did not print isolated proxy URL"

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
grep -qx '2' "$legacy_state/schema-version" || fail "legacy state was not marked as migrated"

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

env "${env_prefix[@]}" "$script" enable vmetrics >/dev/null
grep -qx 'vmetrics' "$state/enabled" || fail "enable did not persist vmetrics"
grep -q -- 'compose .* --profile vmetrics up -d postgres dragonfly vmetrics' "$log" \
  || fail "vmetrics profile was not passed before up"

env "${env_prefix[@]}" "$script" enable proxy-llm >/dev/null
grep -qx 'proxy-llm' "$state/enabled" || fail "enable did not persist proxy-llm"
grep -qx 'postgres' "$state/enabled" || fail "proxy-llm did not keep postgres enabled"
grep -qx 'dragonfly' "$state/enabled" || fail "proxy-llm did not keep dragonfly enabled"
grep -q -- 'proxy-llm state=.*/proxy-llm-dev-runtime init --no-show-secrets' "$log" \
  || fail "proxy init did not use isolated state"
grep -q -- 'exec -i postgres-container psql -U postgres -d postgres.*target_db=claude_code_hub.*target_role=proxy_llm.*target_password='"$proxy_db_password" "$log" \
  || fail "proxy database role was not created before startup"
grep -q -- 'exec -i postgres-container psql -U postgres -d claude_code_hub.*target_role=proxy_llm' "$log" \
  || fail "proxy database schema privileges were not granted before startup"
grep -q -- 'compose .* --profile vmetrics --profile proxy-llm up -d postgres dragonfly vmetrics proxy-llm cli-proxy-api' "$log" \
  || fail "proxy profile was not started with shared base services"

env "${env_prefix[@]}" "$script" disable vmetrics >/dev/null
if grep -qx 'vmetrics' "$state/enabled"; then
  fail "disable did not remove vmetrics"
fi
grep -q -- 'compose .* --profile vmetrics stop vmetrics' "$log" \
  || fail "disable did not stop the optional vmetrics service"

if env "${env_prefix[@]}" "$script" disable postgres >"$test_root/disable-postgres.out" 2>&1; then
  fail "disable postgres succeeded while proxy-llm still required it"
fi
grep -q 'proxy-llm requires postgres' "$test_root/disable-postgres.out" \
  || fail "dependency error for postgres was unclear"

env "${env_prefix[@]}" "$script" disable proxy-llm postgres dragonfly >/dev/null
if [[ -s "$state/enabled" ]]; then
  fail "disable proxy-llm postgres dragonfly did not clear enabled targets"
fi

: >"$log"
env "${env_prefix[@]}" "$script" start vlogs >/dev/null
grep -q -- 'compose .* --profile vlogs up -d vlogs' "$log" \
  || fail "transient vlogs start unexpectedly pulled in default services"

echo "dev-runtime tests passed"
