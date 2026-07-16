#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}"
script_dir="$repo_root/bootstrap/codestudio"
manifest="$script_dir/io.github.trumank.CodeStudio.yml"
build_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ahdg-code-studio-flatpak-build"
repo_dir="${XDG_DATA_HOME:-$HOME/.local/share}/ahdg/flatpak-repos/code-studio"
remote_name="ahdg-code-studio"

if [[ ! -f "$manifest" ]]; then
  echo "run from the repository root" >&2
  exit 1
fi

if ! command -v flatpak >/dev/null 2>&1; then
  echo "flatpak is required" >&2
  exit 1
fi

if ! command -v flatpak-builder >/dev/null 2>&1; then
  echo "flatpak-builder is required" >&2
  exit 1
fi

if ! flatpak --user info org.freedesktop.Sdk//24.08 >/dev/null 2>&1; then
  flatpak --user install -y flathub org.freedesktop.Sdk//24.08
fi

mkdir -p "$(dirname "$repo_dir")"
flatpak-builder --force-clean --repo="$repo_dir" "$build_dir" "$manifest"
flatpak --user remote-add --if-not-exists --no-gpg-verify --no-enumerate "$remote_name" "file://$repo_dir"
flatpak --user install -y --or-update "$remote_name" io.github.trumank.CodeStudio

update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

echo "Installed io.github.trumank.CodeStudio"
