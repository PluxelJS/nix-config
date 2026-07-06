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

for old_app_id in com.mint.DevCode io.github.trumank.MintCodeStudio; do
  if flatpak --user info "$old_app_id" >/dev/null 2>&1; then
    flatpak --user uninstall -y --delete-data "$old_app_id"
  fi
done

bash "$script_dir/apply-desktop-overrides.sh"

if ! flatpak --user info org.freedesktop.Sdk//24.08 >/dev/null 2>&1; then
  flatpak --user install -y flathub org.freedesktop.Sdk//24.08
fi

mkdir -p "$(dirname "$repo_dir")"
flatpak-builder --force-clean --repo="$repo_dir" "$build_dir" "$manifest"
flatpak --user remote-add --if-not-exists --no-gpg-verify --no-enumerate "$remote_name" "file://$repo_dir"
flatpak --user install -y --or-update "$remote_name" io.github.trumank.CodeStudio

old_remote_url="$(flatpak --user remotes --columns=name,url | awk '$1 == "codestudio-origin" { print $2; exit }' || true)"
if [[ "$old_remote_url" == file://"$HOME"/mint/* ]]; then
  flatpak --user remote-delete codestudio-origin >/dev/null 2>&1 || true
fi

rm -f "$HOME/.local/share/applications/mint-container-code.desktop"
rm -f "$HOME/.local/share/applications/com.mint.DevCode.desktop"
rm -f "$HOME/.local/share/applications/mint-dev-code.desktop"
rm -f "$HOME/.local/share/applications/io.github.trumank.MintCodeStudio.desktop"
rm -f "$HOME/.local/bin/mint-desktop-launch"
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

echo "Installed io.github.trumank.CodeStudio"
echo "Stale Code Studio desktop entries and old app ids cleaned."
