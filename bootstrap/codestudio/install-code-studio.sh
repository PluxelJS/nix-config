#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}"
script_dir="$repo_root/bootstrap/codestudio"
manifest="$script_dir/io.github.trumank.CodeStudio.yml"
build_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ahdg-code-studio-flatpak-build"
repo_dir="${XDG_DATA_HOME:-$HOME/.local/share}/ahdg/flatpak-repos/code-studio"
remote_name="ahdg-code-studio"
runtime_ref="org.freedesktop.Sdk//24.08"

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

if ! flatpak --user info "$runtime_ref" >/dev/null 2>&1; then
  flatpak --user install -y flathub "$runtime_ref"
fi

mkdir -p "$(dirname "$repo_dir")"
flatpak-builder --force-clean --repo="$repo_dir" "$build_dir" "$manifest"
flatpak --user remote-add --if-not-exists --no-gpg-verify --no-enumerate "$remote_name" "file://$repo_dir"

app_id="io.github.trumank.CodeStudio"
installed_origin="$({
  flatpak --user list --app --columns=application,origin 2>/dev/null || true
} | awk -F '\t' -v app="$app_id" '$1 == app { print $2; exit }')"

if [[ -n "$installed_origin" && "$installed_origin" != "$remote_name" ]]; then
  # Flatpak refuses --or-update across remotes. --reinstall switches the
  # package origin without deleting its app-private home or user data.
  flatpak --user install -y --reinstall "$remote_name" "$app_id"
else
  flatpak --user install -y --or-update "$remote_name" "$app_id"
fi

update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

echo "Installed $app_id"
