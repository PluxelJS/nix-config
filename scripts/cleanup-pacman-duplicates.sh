#!/usr/bin/env bash
set -euo pipefail

# These packages are installed by the Nix/Home Manager shell setup and can be
# removed from pacman once you have validated the migration.
replaced_by_nix=(
  bat
  delta
  darkly-bin
  eza
  fastfetch
  fd
  fzf
  ghostty
  ghostty-shell-integration
  ghostty-terminfo
  git
  github-cli
  mise
  maplemono-cn
  maplemono-nf-cn
  ripgrep
  starship
  zoxide
  adobe-source-han-sans-otc-fonts
  adobe-source-han-serif-otc-fonts
  bibata-cursor-theme
  noto-fonts-emoji
  noto-fonts-color-emoji
  papirus-icon-theme
  inter-font
  ttf-inter
  ttf-twemoji-color
)

# These were part of the old Qt theming path and are no longer used now that
# Plasma + Darkly + Catppuccin are the only supported path.
retired_qt_theme_stack=(
  kvantum
  kvantum-qt5
)

# These are not migrated to Nix, but they belong to the old fish-based shell
# stack that the current setup no longer uses.
retired_shell_stack=(
  cachyos-fish-config
  fish
  fish-autopair
  fish-pure-prompt
  fisher
)

# The shell migration no longer relies on the old GUI config helper.
retired_input_method_tools=(
  fcitx5-configtool
)

contains() {
  local needle=$1
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

reverse_dependents_outside_set() {
  local pkg=$1
  shift
  local removal_set=("$@")
  local line
  local dep
  local dependents=()

  if ! command -v pactree >/dev/null 2>&1; then
    return 0
  fi

  while IFS= read -r line; do
    dep="${line##* }"
    dep="${dep%%[*}"
    dep="${dep%%:}"

    [[ -n "$dep" ]] || continue
    [[ "$dep" == "$pkg" ]] && continue

    if ! contains "$dep" "${removal_set[@]}" && ! contains "$dep" "${dependents[@]}"; then
      dependents+=("$dep")
    fi
  done < <(pactree -ru "$pkg" 2>/dev/null || true)

  printf '%s\n' "${dependents[@]}"
}

replaced_packages=()
for pkg in "${replaced_by_nix[@]}"; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    replaced_packages+=("$pkg")
  fi
done

retired_packages=()
for pkg in "${retired_shell_stack[@]}"; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    retired_packages+=("$pkg")
  fi
done

retired_input_method_packages=()
for pkg in "${retired_input_method_tools[@]}"; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    retired_input_method_packages+=("$pkg")
  fi
done

retired_qt_packages=()
for pkg in "${retired_qt_theme_stack[@]}"; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    retired_qt_packages+=("$pkg")
  fi
done

packages=("${replaced_packages[@]}" "${retired_qt_packages[@]}" "${retired_packages[@]}" "${retired_input_method_packages[@]}")
safe_packages=()
blocked_packages=()

for pkg in "${packages[@]}"; do
  blockers=()
  while IFS= read -r dependent; do
    [[ -n "$dependent" ]] || continue
    blockers+=("$dependent")
  done < <(reverse_dependents_outside_set "$pkg" "${packages[@]}")

  if [[ ${#blockers[@]} -eq 0 ]]; then
    safe_packages+=("$pkg")
  else
    blocked_packages+=("$pkg <- ${blockers[*]}")
  fi
done

if [[ ${#safe_packages[@]} -eq 0 ]] && [[ ${#blocked_packages[@]} -eq 0 ]]; then
  cat <<EOF
No cleanup candidates from the migrated shell set are currently installed.

Still kept on purpose:
  zsh
Reason:
  Your login shell is still /usr/bin/zsh, so removing the system zsh package is unsafe.
EOF
  exit 0
fi

if [[ "${1:-}" == "--apply" ]]; then
  if [[ ${#safe_packages[@]} -eq 0 ]]; then
    echo "No safe duplicate packages can be removed right now."
    echo "Everything detected is still required by other pacman/AUR packages."
    exit 0
  fi

  echo "Removing pacman packages that are now replaced by Nix or retired with the old fish stack..."
  echo "Keeping zsh installed because the login shell is still /usr/bin/zsh."
  exec sudo pacman -Rns "${safe_packages[@]}"
fi

cat <<EOF
Dry run only.

Safe to remove now:
  ${safe_packages[*]:-(none)}

Blocked by reverse dependencies:
  ${blocked_packages[*]:-(none)}

Retired from the old Qt theme stack:
  ${retired_qt_packages[*]:-(none)}

Retired from the old fish-based shell setup:
  ${retired_packages[*]:-(none)}

Retired from the old fcitx GUI tooling path:
  ${retired_input_method_packages[*]:-(none)}

Not included on purpose:
  fcitx5 fcitx5-gtk fcitx5-qt fcitx5-rime librime librime-data zsh
Reason:
  Your login shell is still /usr/bin/zsh, so removing the system zsh package is unsafe.
  The system fcitx stack now owns the runtime side again; Nix only manages the
  config, theme, and Rime data layer around it.

To remove the duplicates, run:
  ~/.config/nix/scripts/cleanup-pacman-duplicates.sh --apply
EOF
