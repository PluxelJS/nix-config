#!/usr/bin/env bash
set -euo pipefail

profile=""
profile_explicit=0
mode="check"
include_recommended=0
enabled_features_file="$HOME/.config/ahdg/enabled-features"

while (($# > 0)); do
  case "$1" in
    --apply)
      mode="apply"
      ;;
    --with-recommended)
      include_recommended=1
      ;;
    --profile)
      shift
      profile="${1:-}"
      profile_explicit=1
      ;;
    desktop|shell|container|shell-minimal|container-fonts|desktop-custom|shell-custom|container-custom)
      profile="$1"
      profile_explicit=1
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

if [[ -z "$profile" && -f "$HOME/.config/ahdg/profile" ]]; then
  profile="$(tr -d '\n' < "$HOME/.config/ahdg/profile")"
fi

profile="${profile:-desktop}"

failures=0
repo_missing=()
aur_missing=()
recommended_repo_missing=()
notes=()

pass() {
  printf '[ok] %s\n' "$1"
}

warn() {
  printf '[warn] %s\n' "$1"
}

fail() {
  printf '[missing] %s\n' "$1"
  failures=$((failures + 1))
}

has_feature() {
  local feature=$1

  if [[ "$profile_explicit" == "0" && -f "$enabled_features_file" ]]; then
    rg -qx -- "$feature" "$enabled_features_file"
    return $?
  fi

  case "$profile:$feature" in
    desktop:fastfetch|desktop:ghostty|desktop:desktopXdg|desktop:fonts|desktop:gui|desktop:portal|desktop:flatpak|desktop:graphics|desktop:themeRuntime)
      return 0
      ;;
    shell:fonts|container-fonts:fonts)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

package_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

command_available() {
  command -v "$1" >/dev/null 2>&1
}

ensure_repo_package() {
  local pkg=$1
  local reason=$2

  if package_installed "$pkg"; then
    pass "repo package \`$pkg\` installed ($reason)"
  else
    fail "repo package \`$pkg\` missing ($reason)"
    repo_missing+=("$pkg")
  fi
}

ensure_recommended_repo_package() {
  local pkg=$1
  local reason=$2

  if package_installed "$pkg"; then
    pass "recommended repo package \`$pkg\` installed ($reason)"
  else
    warn "recommended repo package \`$pkg\` missing ($reason)"
    recommended_repo_missing+=("$pkg")
  fi
}

ensure_any_command() {
  local label=$1
  local reason=$2
  shift 2

  local found=()
  local cmd
  for cmd in "$@"; do
    if command_available "$cmd"; then
      found+=("$cmd")
    fi
  done

  if ((${#found[@]} > 0)); then
    pass "$label available via: ${found[*]} ($reason)"
  else
    fail "$label missing; expected one of: $* ($reason)"
  fi
}

append_note() {
  notes+=("$1")
}

echo "Profile: $profile"
echo "Mode: $mode"
if ((include_recommended)); then
  echo "Recommended packages: include in apply mode"
fi
echo

ensure_repo_package zsh "login shell still resolves to /usr/bin/zsh"
ensure_repo_package pkgfile "Arch-native command/package lookup backend"

if has_feature gui; then
  ensure_repo_package fcitx5 "system-owned input method runtime"
  ensure_repo_package fcitx5-gtk "GTK IM modules for host apps"
  ensure_repo_package fcitx5-qt "Qt IM modules for host apps"
  ensure_repo_package fcitx5-rime "Rime addon for fcitx5"
fi

if has_feature flatpak; then
  ensure_repo_package flatpak "Flatpak runtime stays on the host side"
fi

case "$profile" in
  desktop|desktop-custom)
    ensure_repo_package podman "user quadlets such as Verdaccio run through Podman"
    ;;
esac

if has_feature portal; then
  ensure_repo_package xdg-desktop-portal "portal broker service"
  ensure_repo_package xdg-desktop-portal-kde "preferred KDE portal backend"
fi

if has_feature gui; then
  ensure_any_command "Mango compositor" "session binary required by ~/.config/mango" mango
  ensure_any_command "Mango control tool" "helper used by Mango scripts and keybinds" mmsg
  ensure_any_command "DMS shell" "desktop shell invoked from Mango config" dms

  if ! command_available mango; then
    aur_missing+=("mangowc")
    append_note "No \`mango\` binary found. Preferred AUR package: \`mangowc\`. If you intentionally track the git build, install \`mangowm-git\` instead."
  elif ! command_available mmsg; then
    aur_missing+=("mangowc")
    append_note "No \`mmsg\` binary found. Reinstall the Mango package that provides both \`mango\` and \`mmsg\`."
  fi

  if ! command_available dms; then
    aur_missing+=("dms-shell")
    append_note "No \`dms\` binary found. Preferred AUR package: \`dms-shell\`."
  fi

  ensure_repo_package wlr-randr "monitor command used in Mango config"
  ensure_repo_package kservice "provides kbuildsycoca6 used by DMS startup"
  ensure_repo_package polkit-kde-agent "auth agent launched from DMS config"
  ensure_repo_package plasma-workspace "provides xembedsniproxy bridge for tray apps"
  ensure_repo_package dbus "provides dbus-update-activation-environment"

  ensure_recommended_repo_package baloo "balooctl6 is launched from Mango startup"
  ensure_recommended_repo_package copyq "clipboard manager bound in Mango config"
  ensure_recommended_repo_package dolphin "default file manager bound in Mango config"
fi

if has_feature gui; then
  if command_available zen-browser; then
    pass "browser command \`zen-browser\` available (used by Mango browser hotkey)"
  else
    warn "browser command \`zen-browser\` missing (browser hotkey will fail until you install it or override BROWSER_CMD)"
    append_note "Install your preferred browser and keep \`BROWSER_CMD\` / \`BROWSER_DESKTOP_ID\` aligned with ~/.config/nix/home/files/mango/scripts/browser-activate.sh."
  fi
fi

echo
if ((${#notes[@]} > 0)); then
  echo "Notes:"
  for note in "${notes[@]}"; do
    printf '  - %s\n' "$note"
  done
  echo
fi

if [[ "$mode" == "apply" ]]; then
  if ((${#repo_missing[@]} > 0)); then
    mapfile -t repo_missing < <(printf '%s\n' "${repo_missing[@]}" | sed '/^$/d' | sort -u)
    echo "Installing missing required repo packages..."
    sudo pacman -S --needed "${repo_missing[@]}"
  else
    echo "No required repo packages missing."
  fi

  if ((include_recommended)) && ((${#recommended_repo_missing[@]} > 0)); then
    mapfile -t recommended_repo_missing < <(printf '%s\n' "${recommended_repo_missing[@]}" | sed '/^$/d' | sort -u)
    echo
    echo "Installing missing recommended repo packages..."
    sudo pacman -S --needed "${recommended_repo_missing[@]}"
  elif ((${#recommended_repo_missing[@]} > 0)); then
    echo
    echo "Recommended repo packages left untouched:"
    printf '  %s\n' "${recommended_repo_missing[@]}" | sort -u
    echo "Re-run with --with-recommended if you want them installed too."
  fi

  if ((${#aur_missing[@]} > 0)); then
    mapfile -t aur_missing < <(printf '%s\n' "${aur_missing[@]}" | sed '/^$/d' | sort -u)
    echo
    if command -v paru >/dev/null 2>&1; then
      echo "Installing missing required AUR packages..."
      paru -S --needed "${aur_missing[@]}"
    else
      echo "Missing required AUR packages and no \`paru\` command is available:" >&2
      printf '  %s\n' "${aur_missing[@]}" >&2
      echo "Install paru first, or run scripts/bootstrap-cachyos.sh --apply." >&2
      exit 1
    fi
  fi

  exit 0
fi

cat <<EOF
Summary:
  Required repo packages missing: ${#repo_missing[@]}
  Required AUR packages missing: ${#aur_missing[@]}
  Recommended repo packages missing: ${#recommended_repo_missing[@]}

Apply required packages:
  ~/.config/nix/scripts/install-arch-runtime-deps.sh --apply

Apply required + recommended packages:
  ~/.config/nix/scripts/install-arch-runtime-deps.sh --apply --with-recommended
EOF

if ((${#repo_missing[@]} > 0)); then
  echo
  echo "Required repo packages to install:"
  printf '  %s\n' "${repo_missing[@]}" | sed '/^$/d' | sort -u
fi

if ((${#aur_missing[@]} > 0)); then
  echo
  echo "Required AUR packages to install:"
  printf '  %s\n' "${aur_missing[@]}" | sed '/^$/d' | sort -u
fi

if ((${#recommended_repo_missing[@]} > 0)); then
  echo
  echo "Recommended repo packages to consider:"
  printf '  %s\n' "${recommended_repo_missing[@]}" | sed '/^$/d' | sort -u
fi
