#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
nixup="$repo_root/home/files/bin/nixup"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

usage_spec="$("$nixup" --usage)"
[[ "$usage_spec" == *'flag "--latest"'* ]] || fail "--usage did not expose --latest"
[[ "$usage_spec" == *'flag "--check"'* ]] || fail "--usage did not expose --check"

git_init() {
  git -c init.defaultBranch=main init "$1" >/dev/null
  git -C "$1" config user.name Test
  git -C "$1" config user.email test@example.invalid
}

seed="$test_root/seed"
remote="$test_root/remote.git"
work="$test_root/work"
home="$test_root/home"
mkdir -p "$home/.config/ahdg"
git_init "$seed"

cat >"$seed/setup" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$HOME/setup-args"
EOF
chmod +x "$seed/setup"
echo initial >"$seed/flake.lock"
git -C "$seed" add setup flake.lock
git -C "$seed" commit -m initial >/dev/null
git clone --bare "$seed" "$remote" >/dev/null 2>&1
git clone "$remote" "$work" >/dev/null 2>&1
git -C "$work" config user.name Test
git -C "$work" config user.email test@example.invalid

echo shell >"$home/.config/ahdg/profile"
echo updated >"$seed/flake.lock"
git -C "$seed" commit -am update >/dev/null
git -C "$seed" push "$remote" main >/dev/null

before="$(git -C "$work" rev-parse HEAD)"
check_output="$(HOME="$home" XDG_CONFIG_HOME="$home/.config" AHDG_NIX_REPO="$work" "$nixup" --check)"
after_check="$(git -C "$work" rev-parse HEAD)"
[[ "$before" == "$after_check" ]] || fail "--check changed HEAD"
[[ "$check_output" == *"Available Nix config updates"* ]] || fail "--check did not report update"

HOME="$home" XDG_CONFIG_HOME="$home/.config" AHDG_NIX_REPO="$work" "$nixup" >/dev/null
[[ "$(git -C "$work" rev-parse HEAD)" == "$(git -C "$seed" rev-parse HEAD)" ]] || fail "nixup did not fast-forward"
[[ "$(<"$work/flake.lock")" == updated ]] || fail "nixup did not update flake.lock"
[[ "$(<"$home/setup-args")" == "--profile shell" ]] || fail "nixup did not preserve active profile"

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == flake && "${2:-}" == update ]]; then
  printf 'latest\n' >flake.lock
  exit 0
fi
printf '%s\n' "$*" >"$HOME/nix-args"
EOF
chmod +x "$fake_bin/nix"
rm -f "$home/setup-args"
PATH="$fake_bin:$PATH" HOME="$home" XDG_CONFIG_HOME="$home/.config" AHDG_NIX_REPO="$work" "$nixup" --latest >/dev/null
[[ "$(<"$work/flake.lock")" == latest ]] || fail "--latest did not update flake inputs"
[[ ! -e "$home/setup-args" ]] || fail "--latest unexpectedly ran setup"
[[ "$(<"$home/nix-args")" == *"#current-shell"* ]] || fail "--latest did not switch the active profile"

echo dirty >>"$work/flake.lock"
if HOME="$home" XDG_CONFIG_HOME="$home/.config" AHDG_NIX_REPO="$work" "$nixup" >"$test_root/dirty.out" 2>&1; then
  fail "nixup accepted a dirty checkout"
fi
grep -q "local changes detected" "$test_root/dirty.out" || fail "dirty checkout error was unclear"

dirty_check="$(HOME="$home" XDG_CONFIG_HOME="$home/.config" AHDG_NIX_REPO="$work" "$nixup" --check)"
[[ "$dirty_check" == *"Local changes currently block nixup"* ]] || fail "--check did not report dirty blocker"

git -C "$work" checkout -b local-test >/dev/null
git -C "$work" remote remove origin
local_before="$(git -C "$work" status --porcelain)"
lock_before="$(cat "$work/flake.lock")"
PATH="$fake_bin:$PATH" HOME="$home" XDG_CONFIG_HOME="$home/.config" AHDG_NIX_REPO="$work" "$nixup" --local >/dev/null
[[ "$(<"$home/nix-args")" == *"switch --flake path:$work#current-shell"* ]] || fail "--local did not switch the workspace path and active profile"
[[ "$(git -C "$work" status --porcelain)" == "$local_before" ]] || fail "--local changed the checkout"
[[ "$(cat "$work/flake.lock")" == "$lock_before" ]] || fail "--local changed flake.lock"
[[ ! -e "$home/setup-args" ]] || fail "--local unexpectedly ran setup"

echo "nixup integration tests passed"
