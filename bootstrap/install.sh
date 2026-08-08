#!/usr/bin/env bash
set -euo pipefail

repo_url="${NIX_CONFIG_REPO_URL:-https://github.com/PluxelJS/nix-config.git}"

if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo "This bootstrap currently supports x86_64 Linux only." >&2
  exit 1
fi
if [[ "$(id -u)" -eq 0 ]]; then
  echo "Run this as the target desktop user, not as root." >&2
  exit 1
fi
if [[ -z "${HOME:-}" || ! -d "$HOME" ]]; then
  echo "The desktop user's HOME is missing or unavailable." >&2
  exit 1
fi
if ! command -v pacman >/dev/null 2>&1; then
  echo "This bootstrap targets CachyOS/Arch hosts with pacman." >&2
  exit 1
fi

target_dir="${NIX_CONFIG_TARGET:-${XDG_CONFIG_HOME:-$HOME/.config}/nix}"

if ! command -v git >/dev/null 2>&1; then
  sudo pacman -S --needed git
fi

if [[ -e "$target_dir" ]]; then
  if [[ ! -d "$target_dir/.git" ]]; then
    echo "Target exists but is not a Git checkout: $target_dir" >&2
    exit 1
  fi
else
  mkdir -p "$(dirname "$target_dir")"
  git clone --depth=1 "$repo_url" "$target_dir"
fi

exec "$target_dir/setup" "$@"
