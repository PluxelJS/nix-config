#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}"
script_dir="$repo_root/bootstrap/codestudio"
manifest="$script_dir/io.github.trumank.CodeStudio.yml"
build_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ahdg-code-studio-flatpak-build"

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

for old_app_id in com.mint.DevCode io.github.trumank.MintCodeStudio; do
  if flatpak --user info "$old_app_id" >/dev/null 2>&1; then
    flatpak --user uninstall -y --delete-data "$old_app_id"
  fi
done

bash "$script_dir/apply-desktop-overrides.sh"

if ! flatpak --user info org.freedesktop.Sdk//24.08 >/dev/null 2>&1; then
  flatpak --user install -y flathub org.freedesktop.Sdk//24.08
fi

flatpak-builder --user --install --force-clean "$build_dir" "$manifest"

rm -f "$HOME/.local/share/applications/mint-container-code.desktop"
rm -f "$HOME/.local/share/applications/com.mint.DevCode.desktop"
rm -f "$HOME/.local/share/applications/mint-dev-code.desktop"
rm -f "$HOME/.local/share/applications/io.github.trumank.MintCodeStudio.desktop"
rm -f "$HOME/.local/bin/mint-desktop-launch"
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

echo "Installed io.github.trumank.CodeStudio"
echo "Stale Code Studio desktop entries and old app ids cleaned."
