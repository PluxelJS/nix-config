#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}"
script_dir="$repo_root/bootstrap/codestudio"
source_file="$script_dir/overrides/global"
target_file="${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/overrides/global"

if [[ ! -f "$source_file" ]]; then
  echo "run from the repository root" >&2
  exit 1
fi

if [[ -f "$target_file" ]] && ! cmp -s "$source_file" "$target_file"; then
  if [[ "${CODE_STUDIO_REPLACE_FLATPAK_OVERRIDE:-0}" != "1" ]]; then
    echo "refusing to replace existing Flatpak global override: $target_file" >&2
    echo "review the diff first:" >&2
    echo "  diff -u '$target_file' '$source_file'" >&2
    echo "then rerun with CODE_STUDIO_REPLACE_FLATPAK_OVERRIDE=1 to back it up and replace it" >&2
    exit 1
  fi

  backup_file="$target_file.backup.$(date +%Y%m%d%H%M%S)"
  install -Dm644 "$target_file" "$backup_file"
  echo "Backed up existing Flatpak global override: $backup_file"
fi

install -Dm644 "$source_file" "$target_file"

echo "Installed user-level Flatpak global override: $target_file"
