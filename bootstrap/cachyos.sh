#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

mode="check"
profile="desktop"
flake_attr=""
include_recommended=0
install_nix=1
install_paru=1
switch_after=1

recommended_desktop_flatpaks=(
  io.missioncenter.MissionCenter
  org.gnome.eog
  org.telegram.desktop
)

usage() {
  cat <<EOF
Usage: $0 [--apply] [--profile desktop|shell|container] [--with-recommended]

Bootstrap a fresh CachyOS/Arch user environment for this Home Manager flake.

Default mode is a dry run. Use --apply to install missing pieces.

Options:
  --apply              install missing prerequisites and run Home Manager
  --profile NAME       deployment profile; default: desktop
  --flake ATTR         flake output; default follows profile
  --with-recommended   include recommended desktop packages and Flatpak apps
  --no-install-nix     skip Nix installation/daemon setup
  --no-install-paru    skip paru installation
  --no-switch          do not run Home Manager switch
  --switch             run Home Manager switch in --apply mode (default)
EOF
}

while (($# > 0)); do
  case "$1" in
    --apply)
      mode="apply"
      ;;
    --profile)
      shift
      profile="${1:-}"
      ;;
    --flake)
      shift
      flake_attr="${1:-}"
      ;;
    --with-recommended)
      include_recommended=1
      ;;
    --no-install-nix)
      install_nix=0
      ;;
    --no-install-paru)
      install_paru=0
      ;;
    --no-switch)
      switch_after=0
      ;;
    --switch)
      switch_after=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

case "$profile" in
  desktop)
    flake_attr="${flake_attr:-ahdg}"
    ;;
  shell)
    flake_attr="${flake_attr:-ahdg-shell}"
    ;;
  container)
    flake_attr="${flake_attr:-ahdg-container}"
    ;;
  *)
    echo "Unsupported profile: $profile" >&2
    exit 2
    ;;
esac

pass() {
  printf '[ok] %s\n' "$1"
}

warn() {
  printf '[warn] %s\n' "$1"
}

fail() {
  printf '[missing] %s\n' "$1"
}

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  "$@"
}

pacman_has_package() {
  pacman -Si "$1" >/dev/null 2>&1
}

pacman_package_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

install_pacman_package() {
  local pkg=$1
  local reason=$2

  if pacman_package_installed "$pkg"; then
    pass "pacman package \`$pkg\` installed ($reason)"
    return
  fi

  fail "pacman package \`$pkg\` missing ($reason)"
  if [[ "$mode" == "apply" ]]; then
    run sudo pacman -S --needed "$pkg"
  fi
}

ensure_nix() {
  if command -v nix >/dev/null 2>&1; then
    pass "nix command available"
  elif ((install_nix)); then
    fail "nix command missing"
    if [[ "$mode" == "apply" ]]; then
      install_pacman_package nix "Nix daemon and CLI"
    fi
  else
    warn "nix command missing and --no-install-nix was set"
  fi

  if [[ "$mode" == "apply" ]] && command -v systemctl >/dev/null 2>&1; then
    run sudo systemctl enable --now nix-daemon.service
  fi

  if [[ "$mode" == "apply" ]] && getent group nix-users >/dev/null 2>&1; then
    if id -nG "$USER" | tr ' ' '\n' | grep -qx nix-users; then
      pass "$USER is already in nix-users"
    else
      run sudo usermod -aG nix-users "$USER"
      warn "log out and back in if nix-daemon rejects builds for this user"
    fi
  fi
}

ensure_paru() {
  if command -v paru >/dev/null 2>&1; then
    pass "paru command available"
    return
  fi

  if ((!install_paru)); then
    warn "paru command missing and --no-install-paru was set"
    return
  fi

  fail "paru command missing"
  if [[ "$mode" != "apply" ]]; then
    return
  fi

  install_pacman_package base-devel "required to build AUR packages"
  install_pacman_package git "required to fetch AUR package sources"

  if pacman_has_package paru; then
    install_pacman_package paru "AUR helper"
    return
  fi

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  run git clone https://aur.archlinux.org/paru-bin.git "$tmpdir/paru-bin"
  (
    cd "$tmpdir/paru-bin"
    run makepkg -si --noconfirm
  )
}

run_runtime_dependencies() {
  local args=("--profile" "$profile")

  if [[ "$mode" == "apply" ]]; then
    args+=("--apply")
  fi

  if ((include_recommended)); then
    args+=("--with-recommended")
  fi

  "$repo_dir/scripts/install-arch-runtime-deps.sh" "${args[@]}"
}

flatpak_app_installed() {
  flatpak info "$1" >/dev/null 2>&1
}

ensure_flathub() {
  if flatpak remotes --columns=name 2>/dev/null | grep -qx flathub; then
    pass "Flatpak remote \`flathub\` configured"
    return
  fi

  fail "Flatpak remote \`flathub\` missing"
  if [[ "$mode" == "apply" ]]; then
    run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}

ensure_flatpak_apps() {
  local app
  local missing=()

  [[ "$profile" == "desktop" ]] || return

  if ((!include_recommended)); then
    warn "recommended Flatpak apps skipped; pass --with-recommended to install desktop canaries and bound apps"
    return
  fi

  if ! command -v flatpak >/dev/null 2>&1; then
    warn "flatpak command missing; runtime dependency step must install it before recommended Flatpaks can be applied"
    return
  fi

  ensure_flathub

  for app in "${recommended_desktop_flatpaks[@]}"; do
    if flatpak_app_installed "$app"; then
      pass "Flatpak app \`$app\` installed"
    else
      fail "Flatpak app \`$app\` missing"
      missing+=("$app")
    fi
  done

  if [[ "$mode" == "apply" ]] && ((${#missing[@]} > 0)); then
    run flatpak install -y --or-update flathub "${missing[@]}"
  fi
}

run_home_manager() {
  local flake_ref="$repo_dir#$flake_attr"

  if [[ "$mode" != "apply" ]]; then
    cat <<EOF

Home Manager switch command:
  nix run github:nix-community/home-manager -- switch --flake ${flake_ref} -b pre-nix
EOF
    return
  fi

  export NIX_CONFIG=$'experimental-features = nix-command flakes\naccept-flake-config = true'
  run nix run github:nix-community/home-manager -- switch --flake "$flake_ref" -b pre-nix
  "$repo_dir/scripts/verify-shell-migration.sh" "$profile"
}

if ! command -v pacman >/dev/null 2>&1; then
  echo "This bootstrap script expects a pacman-based CachyOS/Arch host." >&2
  exit 1
fi

cat <<EOF
Bootstrap target:
  repo:    $repo_dir
  profile: $profile
  flake:   $flake_attr
  mode:    $mode
EOF

echo
ensure_nix
ensure_paru

echo
run_runtime_dependencies
ensure_flatpak_apps

if ((switch_after)); then
  run_home_manager
fi

cat <<EOF

Next checks after reboot/login:
  $repo_dir/scripts/verify-shell-migration.sh $profile
EOF
