#!/usr/bin/env bash
set -euo pipefail

failures=0
profile="${1:-}"
enabled_features_file="$HOME/.config/ahdg/enabled-features"

if [[ -z "$profile" && -f "$HOME/.config/ahdg/profile" ]]; then
  profile="$(tr -d '\n' < "$HOME/.config/ahdg/profile")"
fi

profile="${profile:-desktop}"

pass() {
  printf '[ok] %s\n' "$1"
}

fail() {
  printf '[fail] %s\n' "$1" >&2
  failures=$((failures + 1))
}

check_symlink() {
  local path=$1
  if [[ -L "$path" ]]; then
    pass "$path is managed by Home Manager"
  else
    fail "$path is not a Home Manager symlink"
  fi
}

check_file() {
  local path=$1
  if [[ -f "$path" ]]; then
    pass "$path exists"
  else
    fail "$path is missing"
  fi
}

has_feature() {
  local feature=$1

  if [[ -f "$enabled_features_file" ]]; then
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

check_symlink "$HOME/.zshenv"
check_symlink "$HOME/.config/zsh/.zshenv"
check_symlink "$HOME/.config/zsh/.zshrc"
check_symlink "$HOME/.config/starship/starship.toml"
check_symlink "$HOME/.config/atuin/config.toml"
check_file "$HOME/.config/ahdg/profile"

if [[ "$(tr -d '\n' < "$HOME/.config/ahdg/profile")" == "$profile" ]]; then
  pass "runtime profile marker matches $profile"
else
  fail "runtime profile marker does not match $profile"
fi

if has_feature ghostty; then
  check_symlink "$HOME/.config/ghostty/config"
fi

if has_feature fastfetch; then
  check_symlink "$HOME/.config/fastfetch/config.jsonc"
fi

if has_feature desktopXdg; then
  check_symlink "$HOME/.config/mimeapps.list"
  check_symlink "$HOME/.config/user-dirs.dirs"
  check_symlink "$HOME/.config/user-dirs.locale"
fi

if has_feature ghostty; then
  check_symlink "$HOME/.config/xdg-terminals.list"
fi

if has_feature gui; then
  check_file "$HOME/.gtkrc-2.0"
  check_file "$HOME/.config/fcitx5/config"
  check_file "$HOME/.config/fcitx5/profile"
  check_file "$HOME/.config/fcitx5/conf/classicui.conf"
  check_file "$HOME/.local/share/fcitx5/themes/plasma/theme.conf"
  check_file "$HOME/.local/share/fcitx5/themes/catppuccin-macchiato-lavender/theme.conf"
  check_file "$HOME/.local/share/fcitx5/themes/catppuccin-mocha-lavender/theme.conf"
  check_file "$HOME/.local/share/fcitx5/rime/default.yaml"
  check_file "$HOME/.local/share/fcitx5/rime/wanxiang.schema.yaml"
  check_file "$HOME/.local/share/fcitx5/rime/wanxiang-lts-zh-hans.gram"
  check_file "$HOME/.config/gtk-3.0/settings.ini"
  check_file "$HOME/.config/gtk-4.0/gtk.css"
  check_file "$HOME/.config/xsettingsd/xsettingsd.conf"
  check_file "$HOME/.config/ahdg/theme/session.env"
  check_file "$HOME/.config/ahdg/theme/mode"
  check_file "$HOME/.local/share/themes/Catppuccin-Macchiato/index.theme"
  check_file "$HOME/.local/share/themes/Catppuccin-Latte/index.theme"
  check_file "$HOME/.local/share/icons/Papirus/index.theme"
  check_file "$HOME/.local/share/icons/breeze/index.theme"
  check_file "$HOME/.local/share/icons/Bibata-Modern-Ice/index.theme"
  check_file "$HOME/.config/color-schemes/CatppuccinMacchiatoLavender.colors"
  check_file "$HOME/.local/share/color-schemes/CatppuccinMacchiatoLavender.colors"
  check_file "$HOME/.config/color-schemes/CatppuccinLatteLavender.colors"
  check_file "$HOME/.local/share/color-schemes/CatppuccinLatteLavender.colors"
  check_symlink "$HOME/.local/share/plasma/look-and-feel/Catppuccin-Macchiato-Lavender"
  check_symlink "$HOME/.local/share/plasma/look-and-feel/Catppuccin-Latte-Lavender"
  check_symlink "$HOME/.local/share/aurorae/themes/CatppuccinMacchiato-Modern"
  check_symlink "$HOME/.local/share/aurorae/themes/CatppuccinLatte-Modern"

  current_theme_mode="$(cat "$HOME/.config/ahdg/theme/mode" 2>/dev/null || true)"
  case "$current_theme_mode" in
    light)
      expected_kde_scheme="CatppuccinLatteLavender"
      expected_kde_view_bg="239, 241, 245"
      ;;
    dark)
      expected_kde_scheme="CatppuccinMacchiatoLavender"
      expected_kde_view_bg="36, 39, 58"
      ;;
    *)
      expected_kde_scheme=""
      expected_kde_view_bg=""
      ;;
  esac

  actual_kde_view_bg="$(
    awk -F= '
      $0 == "[Colors:View]" { in_view = 1; next }
      /^\[/ { in_view = 0 }
      in_view && $1 == "BackgroundNormal" { print $2; exit }
    ' "$HOME/.config/kdeglobals" 2>/dev/null || true
  )"

  if [[ -n "$expected_kde_scheme" ]] \
    && rg -q "^ColorScheme=${expected_kde_scheme}$" "$HOME/.config/kdeglobals" \
    && [[ "$actual_kde_view_bg" == "$expected_kde_view_bg" ]]; then
    pass "KDE runtime color sections match the active theme mode"
  else
    fail "KDE runtime color sections do not match the active theme mode"
  fi
fi

if has_feature portal; then
  check_symlink "$HOME/.config/xdg-desktop-portal/portals.conf"
fi

if has_feature flatpak; then
  check_symlink "$HOME/.local/share/flatpak/overrides/global"
fi

if has_feature fonts; then
  check_file "$HOME/.config/fontconfig/fonts.conf"
  check_file "$HOME/.config/fontconfig/conf.d/90-hm-ahdg-custom-font-rules.conf"
  check_file "$HOME/.local/share/fonts/nix/inter/Inter.ttc"
  check_file "$HOME/.local/share/fonts/nix/maple-mono-nf-cn/MapleMono-NF-CN-Regular.ttf"
  check_file "$HOME/.local/share/fonts/custom/README.txt"
fi

if [[ ! -e "$HOME/.config/environment.d/90-dms.conf" ]]; then
  pass "$HOME/.config/environment.d/90-dms.conf legacy file is removed"
else
  fail "$HOME/.config/environment.d/90-dms.conf should no longer exist"
fi

if [[ -L "$HOME/.gitconfig" ]]; then
  pass "$HOME/.gitconfig is managed by Home Manager as a compatibility entrypoint"
else
  fail "$HOME/.gitconfig should be a Home Manager symlink"
fi

if [[ "$(git config --global --get user.name 2>/dev/null || true)" == "ahdg6" ]] && [[ -n "$(git config --global --get user.email 2>/dev/null || true)" ]]; then
  pass "global git author identity resolves through the managed compatibility entrypoint"
else
  fail "global git author identity should resolve through ~/.gitconfig"
fi

if [[ ! -e "$HOME/.config/gtkrc" ]]; then
  pass "$HOME/.config/gtkrc legacy file is removed"
else
  fail "$HOME/.config/gtkrc should no longer exist"
fi

if [[ ! -e "$HOME/.config/amzxyz" ]]; then
  pass "$HOME/.config/amzxyz legacy config tree is removed"
else
  fail "$HOME/.config/amzxyz should no longer exist"
fi

if has_feature fonts; then
  if [[ ! -L "$HOME/.config/fontconfig/fonts.conf" ]]; then
    pass "$HOME/.config/fontconfig/fonts.conf is materialized for Flatpak"
  else
    fail "$HOME/.config/fontconfig/fonts.conf should be a regular file for Flatpak compatibility"
  fi
fi

if has_feature gui; then
  for materialized_path in \
    "$HOME/.gtkrc-2.0" \
    "$HOME/.config/fcitx5/config" \
    "$HOME/.config/fcitx5/profile" \
    "$HOME/.config/fcitx5/conf/classicui.conf" \
    "$HOME/.local/share/fcitx5/themes/plasma" \
    "$HOME/.local/share/fcitx5/themes/catppuccin-macchiato-lavender" \
    "$HOME/.local/share/fcitx5/themes/catppuccin-mocha-lavender" \
    "$HOME/.config/gtk-3.0/settings.ini" \
    "$HOME/.config/xsettingsd/xsettingsd.conf" \
    "$HOME/.config/gtk-4.0" \
    "$HOME/.local/share/themes/Catppuccin-Macchiato" \
    "$HOME/.local/share/themes/Catppuccin-Latte" \
    "$HOME/.local/share/icons/Papirus" \
    "$HOME/.local/share/icons/breeze" \
    "$HOME/.local/share/icons/Bibata-Modern-Ice" \
    "$HOME/.config/color-schemes/CatppuccinMacchiatoLavender.colors" \
    "$HOME/.local/share/color-schemes/CatppuccinMacchiatoLavender.colors" \
    "$HOME/.config/color-schemes/CatppuccinLatteLavender.colors" \
    "$HOME/.local/share/color-schemes/CatppuccinLatteLavender.colors"
  do
    if [[ ! -L "$materialized_path" ]]; then
      pass "$materialized_path is materialized for Flatpak"
    else
      fail "$materialized_path should be a regular file or directory for Flatpak compatibility"
    fi
  done
fi

if has_feature gui && [[ ! -e "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop" ]]; then
  pass "system fcitx autostart is no longer masked by a user override"
elif has_feature gui; then
  fail "system fcitx autostart should not be masked under ~/.config/autostart"
fi

if has_feature flatpak && [[ -d "$HOME/.local/share/flatpak/overrides" ]]; then
  flatpak_app_override_issue=0
  while IFS= read -r override_path; do
    if [[ "$override_path" == "$HOME/.local/share/flatpak/overrides/global" ]]; then
      continue
    fi

    if [[ -L "$override_path" ]]; then
      fail "$override_path should remain app-managed, not Nix-managed"
      flatpak_app_override_issue=1
    fi
  done < <(find "$HOME/.local/share/flatpak/overrides" -maxdepth 1 -type f | sort)

  if [[ $flatpak_app_override_issue -eq 0 ]]; then
    pass "Flatpak app-specific overrides remain activation-managed and writable"
  fi
else
  if has_feature flatpak; then
    fail "$HOME/.local/share/flatpak/overrides is missing"
  fi
fi

if has_feature gui && [[ ! -e "$HOME/.config/qt5ct" ]] && [[ ! -e "$HOME/.config/qt6ct" ]]; then
  pass "unused qt5ct/qt6ct config trees are removed"
elif has_feature gui; then
  fail "unused qt5ct/qt6ct config trees should no longer exist"
fi

if has_feature gui && [[ ! -e "$HOME/.local/share/icons/Papirus-kanagawa" ]]; then
  pass "legacy Papirus-kanagawa icon tree is removed"
elif has_feature gui; then
  fail "legacy Papirus-kanagawa icon tree should no longer exist"
fi

if has_feature gui && [[ ! -e "$HOME/.local/share/icons/Kanagawa" ]]; then
  pass "legacy Kanagawa icon tree is removed"
elif has_feature gui; then
  fail "legacy Kanagawa icon tree should no longer exist"
fi

if has_feature gui && [[ ! -e "$HOME/.local/share/themes/Catppuccin-Mocha" ]] && [[ ! -e "$HOME/.local/share/themes/Wallbash-Gtk" ]]; then
  pass "retired GTK theme trees are removed"
elif has_feature gui; then
  fail "retired GTK theme trees should no longer exist"
fi

if has_feature gui && [[ ! -e "$HOME/.local/share/themes/Abyssal-Wave" ]] && [[ ! -e "$HOME/.local/share/themes/Decay-Green" ]] && [[ ! -e "$HOME/.local/share/themes/Edge-Runner" ]] && [[ ! -e "$HOME/.local/share/themes/Everforest-Dark" ]] && [[ ! -e "$HOME/.local/share/themes/Frosted-Glass" ]] && [[ ! -e "$HOME/.local/share/themes/Graphite-Mono" ]] && [[ ! -e "$HOME/.local/share/themes/Gruvbox-Retro" ]] && [[ ! -e "$HOME/.local/share/themes/Material-Sakura" ]] && [[ ! -e "$HOME/.local/share/themes/Nordic-Blue" ]] && [[ ! -e "$HOME/.local/share/themes/Rose-Pine" ]] && [[ ! -e "$HOME/.local/share/themes/Synth-Wave" ]] && [[ ! -e "$HOME/.local/share/themes/Tokyo-Night" ]]; then
  pass "legacy manual GTK theme trees are removed"
elif has_feature gui; then
  fail "legacy manual GTK theme trees should no longer exist"
fi

if has_feature gui && [[ ! -e "$HOME/.local/share/icons/Papirus-kanagawa" ]] && [[ ! -e "$HOME/.local/share/icons/Wallbash-Icon" ]]; then
  pass "retired icon-theme trees are removed"
elif has_feature gui; then
  fail "retired icon-theme trees should no longer exist"
fi

if has_feature gui && [[ ! -e "$HOME/.local/share/icons/BeautyLine" ]] && [[ ! -e "$HOME/.local/share/icons/Gruvbox-Plus-Dark" ]] && [[ ! -e "$HOME/.local/share/icons/Gruvbox-Retro" ]] && [[ ! -e "$HOME/.local/share/icons/Nordzy" ]] && [[ ! -e "$HOME/.local/share/icons/Tela-circle-black" ]] && [[ ! -e "$HOME/.local/share/icons/Tela-circle-blue" ]] && [[ ! -e "$HOME/.local/share/icons/Tela-circle-dracula" ]] && [[ ! -e "$HOME/.local/share/icons/Tela-circle-green" ]] && [[ ! -e "$HOME/.local/share/icons/Tela-circle-grey" ]] && [[ ! -e "$HOME/.local/share/icons/Tela-circle-pink" ]] && [[ ! -e "$HOME/.local/share/icons/Tela-circle-purple" ]] && [[ ! -e "$HOME/.local/share/icons/Tela-circle-yellow" ]]; then
  pass "legacy manual icon-theme trees are removed"
elif has_feature gui; then
  fail "legacy manual icon-theme trees should no longer exist"
fi

if has_feature gui && [[ ! -e "$HOME/.config/gtk-3.0/gtk.css" ]] && [[ ! -e "$HOME/.config/gtk-3.0/dank-colors.css" ]]; then
  pass "legacy GTK custom CSS overlays are removed"
elif has_feature gui; then
  fail "legacy GTK custom CSS overlays should no longer exist"
fi

if has_feature gui && [[ ! -e "$HOME/.local/share/icons/Catppuccin-Macchiato-Lavender-Cursors" ]]; then
  pass "unused Catppuccin cursor tree is removed"
elif has_feature gui; then
  fail "unused Catppuccin cursor tree should no longer exist"
fi

if has_feature themeRuntime && [[ -f "$HOME/.config/ghostty/config-dankcolors" ]] && [[ ! -L "$HOME/.config/ghostty/config-dankcolors" ]] && [[ -w "$HOME/.config/ghostty/config-dankcolors" ]]; then
  pass "$HOME/.config/ghostty/config-dankcolors is writable for DMS"
elif has_feature themeRuntime; then
  fail "$HOME/.config/ghostty/config-dankcolors must be a writable regular file"
fi

if has_feature fastfetch; then
  check_file "$HOME/.config/fastfetch/assets/1544x1544_circle.png"
fi

expected_tools=(zsh starship git gh fzf zoxide mise atuin)
if has_feature fastfetch; then
  expected_tools+=(fastfetch)
fi
if has_feature ghostty; then
  expected_tools+=(ghostty)
fi
expected_tools_check="command -v ${expected_tools[*]} >/dev/null"

if zsh -i -c "$expected_tools_check"; then
  pass "interactive zsh resolves the migrated toolchain"
else
  fail "interactive zsh cannot resolve one or more migrated tools"
fi

if has_feature ghostty && zsh -i -c '[[ "$ELECTRON_OZONE_PLATFORM_HINT" == "auto" && "$TERMINAL" == "ghostty" ]]'; then
  pass "interactive zsh exports the migrated desktop helper environment"
elif has_feature ghostty; then
  fail "interactive zsh is missing migrated desktop helper environment variables"
fi

if has_feature desktopXdg && zsh -i -c '[[ "$XDG_DESKTOP_DIR" == "$HOME/桌面" && "$XDG_DOWNLOAD_DIR" == "$HOME/下载" ]]'; then
  pass "interactive zsh exports the migrated XDG user directories"
elif has_feature desktopXdg; then
  fail "interactive zsh is missing migrated XDG user directory variables"
fi

if has_feature gui && zsh -i -c 'command -v darkly-settings6 >/dev/null'; then
  pass "Darkly is provided by the Nix profile"
elif has_feature gui; then
  fail "Darkly is missing from the Nix profile"
fi

if has_feature gui && zsh -i -c '[[ "$INPUT_METHOD" == "fcitx" && "$XMODIFIERS" == "@im=fcitx" && "$GTK_IM_MODULE" == "fcitx" && "$QT_IM_MODULE" == "fcitx" && "$QT_IM_MODULES" == "wayland;fcitx" ]]'; then
  pass "interactive zsh exports the migrated fcitx environment"
elif has_feature gui; then
  fail "interactive zsh is missing part of the migrated fcitx environment"
fi

if has_feature fonts && fc-match sans-serif | rg -q '^Inter'; then
  pass "sans-serif resolves to the Nix-managed Inter stack"
elif has_feature fonts; then
  fail "sans-serif no longer resolves to Inter"
fi

if has_feature fonts && fc-match monospace | rg -q '^MapleMono-NF-CN|^MapleMono-NF-CN-|^Maple Mono NF CN'; then
  pass "monospace resolves to the Nix-managed Maple Mono stack"
elif has_feature fonts; then
  fail "monospace no longer resolves to Maple Mono NF CN"
fi

if has_feature flatpak && flatpak info io.github.trumank.CodeStudio >/dev/null 2>&1; then
  if flatpak run --command=sh io.github.trumank.CodeStudio -c 'for cmd in zsh mise git gh opencode; do command -v "$cmd" >/dev/null 2>&1 || exit 1; done' >/dev/null 2>&1; then
    pass "Code Studio terminal resolves the shared host-managed toolchain"
  else
    fail "Code Studio terminal is missing part of the shared host-managed toolchain"
  fi

  if flatpak run --command=sh io.github.trumank.CodeStudio -c 'test -f /home/ahdg/.config/zsh/.zshrc && test -f /home/ahdg/.config/starship/starship.toml && test -f /home/ahdg/.config/atuin/config.toml && test -f /home/ahdg/.config/opencode/tui.json' >/dev/null 2>&1; then
    pass "Code Studio can read the host-side shared shell and opencode config"
  else
    fail "Code Studio cannot read the shared shell or opencode config"
  fi

  if flatpak run --command=sh io.github.trumank.CodeStudio -c 'test -f "$HOME/.codex/config.toml" && test "$(readlink -f "$HOME/.codex/config.toml")" = "/home/ahdg/.codex/config.toml"' >/dev/null 2>&1; then
    pass "Code Studio reuses the host Codex config without sharing the whole Codex state dir"
  else
    fail "Code Studio is not wired to the host Codex config as expected"
  fi

  if flatpak run --command=sh io.github.trumank.CodeStudio -c '
    policy_block="$(sed -n "/\\[Session Bus Policy\\]/,/^\\[/p" /.flatpak-info)"
    printf "%s\n" "$policy_block" | rg -q "^org.freedesktop.secrets=talk$" &&
    printf "%s\n" "$policy_block" | rg -q "^org.kde.kwalletd6=talk$" &&
    printf "%s\n" "$policy_block" | rg -q "^org.kde.secretservicecompat=talk$"
  ' >/dev/null 2>&1; then
    pass "Code Studio can reach the host secret service and KWallet session bus names"
  else
    fail "Code Studio is missing the host secret service or KWallet session bus policy"
  fi
fi

if has_feature flatpak && flatpak info com.jetbrains.CLion >/dev/null 2>&1; then
  if flatpak run --command=sh com.jetbrains.CLion -c 'for cmd in zsh git gh opencode; do command -v "$cmd" >/dev/null 2>&1 || exit 1; done' >/dev/null 2>&1; then
    pass "CLion terminal resolves the shared host-managed toolchain"
  else
    fail "CLion terminal is missing part of the shared host-managed toolchain"
  fi

  if flatpak run --command=sh com.jetbrains.CLion -c 'test -f /home/ahdg/.config/zsh/.zshrc && test -f /home/ahdg/.config/starship/starship.toml && test -f /home/ahdg/.config/atuin/config.toml && test -f /home/ahdg/.config/opencode/tui.json' >/dev/null 2>&1; then
    pass "CLion can read the host-side shared shell and opencode config"
  else
    fail "CLion cannot read the shared shell or opencode config"
  fi

  if flatpak run --command=sh com.jetbrains.CLion -c 'test -f "$HOME/.codex/config.toml" && test "$(readlink -f "$HOME/.codex/config.toml")" = "/home/ahdg/.codex/config.toml"' >/dev/null 2>&1; then
    pass "CLion reuses the host Codex config without sharing the whole Codex state dir"
  else
    fail "CLion is not wired to the host Codex config as expected"
  fi

  if flatpak run --command=sh com.jetbrains.CLion -c 'test -d "$XDG_CONFIG_HOME/JetBrains" && test -d "$XDG_DATA_HOME/JetBrains" && test -d "$XDG_CACHE_HOME/JetBrains"' >/dev/null 2>&1; then
    pass "CLion keeps JetBrains config, data, and cache in app-private XDG state"
  else
    fail "CLion is missing one of the app-private JetBrains XDG state directories"
  fi

  if flatpak run --command=sh com.jetbrains.CLion -c 'sed -n "/\\[Context\\]/,/\\[Session Bus Policy\\]/p" /.flatpak-info | rg -q "^sockets=wayland;$"' >/dev/null 2>&1; then
    pass "CLion stays on Wayland-only sockets without X11 fallback"
  else
    fail "CLion should stay on Wayland-only sockets without X11 fallback"
  fi

  if flatpak run --command=sh com.jetbrains.CLion -c '
    policy_block="$(sed -n "/\\[Session Bus Policy\\]/,/^\\[/p" /.flatpak-info)"
    printf "%s\n" "$policy_block" | rg -q "^org.freedesktop.secrets=talk$" &&
    printf "%s\n" "$policy_block" | rg -q "^org.kde.kwalletd6=talk$" &&
    printf "%s\n" "$policy_block" | rg -q "^org.kde.secretservicecompat=talk$"
  ' >/dev/null 2>&1; then
    pass "CLion can reach the host secret service and KWallet session bus names"
  else
    fail "CLion is missing the host secret service or KWallet session bus policy"
  fi

  if flatpak run --command=sh com.jetbrains.CLion -c '
    env_block="$(sed -n "/\\[Environment\\]/,/^\\[/p" /.flatpak-info)"
    printf "%s\n" "$env_block" | rg -q "^FLATPAK_IDE_ENV=1$" &&
    printf "%s\n" "$env_block" | rg -q "^GTK_IM_MODULE=$" &&
    printf "%s\n" "$env_block" | rg -q "^QT_IM_MODULE=$" &&
    printf "%s\n" "$env_block" | rg -q "^QT_IM_MODULES=wayland$" &&
    printf "%s\n" "$env_block" | rg -q "^XMODIFIERS=$"
  ' >/dev/null 2>&1; then
    pass "CLion keeps its Wayland-specific input env override instead of inheriting desktop IM settings"
  else
    fail "CLion should keep its Wayland-specific input env override"
  fi

  if flatpak run --command=sh com.jetbrains.CLion -c 'test -f "$HOME/.java/.userPrefs/jetbrains/region/prefs.xml" && rg -q "key=\"code\" value=\"apac\"" "$HOME/.java/.userPrefs/jetbrains/region/prefs.xml"' >/dev/null 2>&1; then
    pass "CLion persists JetBrains Java Preferences with a fixed region code"
  else
    fail "CLion is missing the persisted JetBrains Java Preferences region code"
  fi
fi

if has_feature flatpak && flatpak run --command=sh org.telegram.desktop -c 'fc-match sans-serif 2>/dev/null | grep -q "^Inter"' >/dev/null 2>&1; then
  pass "Telegram Flatpak now picks up the user fontconfig stack"
elif has_feature flatpak; then
  fail "Telegram Flatpak is still missing the user fontconfig stack"
fi

if has_feature flatpak && flatpak run --command=sh org.telegram.desktop -c 'test -f ~/.config/gtk-3.0/settings.ini && test -f ~/.local/share/themes/Catppuccin-Macchiato/index.theme && test -f ~/.local/share/themes/Catppuccin-Latte/index.theme && test -f ~/.local/share/icons/Papirus/index.theme && test -f ~/.local/share/icons/breeze/index.theme && test -f ~/.config/color-schemes/CatppuccinMacchiatoLavender.colors && test -f ~/.config/color-schemes/CatppuccinLatteLavender.colors' >/dev/null 2>&1; then
  pass "Telegram Flatpak can read the materialized theme stack"
elif has_feature flatpak; then
  fail "Telegram Flatpak is still missing part of the materialized theme stack"
fi

if has_feature flatpak && flatpak run --command=sh org.telegram.desktop -c 'test -f ~/.config/fcitx5/config && test -f ~/.local/share/fcitx5/themes/plasma/theme.conf && test -f ~/.local/share/fcitx5/rime/default.yaml && printenv XMODIFIERS | grep -qx "@im=fcitx" && printenv QT_IM_MODULES | grep -qx "wayland;fcitx"' >/dev/null 2>&1; then
  pass "Telegram Flatpak can read the migrated fcitx and rime stack"
elif has_feature flatpak; then
  fail "Telegram Flatpak is still missing part of the fcitx or rime stack"
fi

if has_feature flatpak \
  && [[ -f "$HOME/.local/share/flatpak/overrides/global" ]] \
  && rg -q '^filesystems=.*xdg-config/qt5ct:ro.*xdg-config/qt6ct:ro' "$HOME/.local/share/flatpak/overrides/global" \
  && ! rg -q '/usr/share/icons|/usr/share/themes' "$HOME/.local/share/flatpak/overrides/global"; then
  pass "Flatpak global override matches the Nix-managed host integration policy"
elif has_feature flatpak; then
  fail "Flatpak global override does not match the expected Nix-managed policy"
fi

if has_feature gui && rg -q '^Theme=Papirus$' "$HOME/.config/kdeglobals"; then
  pass "KDE icon theme is aligned to the Nix-managed Papirus set"
elif has_feature gui; then
  fail "KDE icon theme is not aligned to Papirus"
fi

if has_feature gui && rg -q '^TerminalApplication=.*/bin/ghostty --gtk-single-instance=true$' "$HOME/.config/kdeglobals"; then
  pass "KDE terminal launcher points at the Nix-managed Ghostty binary"
elif has_feature gui; then
  fail "KDE terminal launcher is still pointing at a non-Nix Ghostty path"
fi

if has_feature gui && [[ -f "$HOME/.config/kwinrc" ]] && rg -q '^InputMethod\[\$e\]=/usr/share/applications/org\.fcitx\.Fcitx5\.desktop$' "$HOME/.config/kwinrc"; then
  pass "KDE Wayland input-method entry points at the system fcitx desktop file"
elif has_feature gui; then
  fail "KDE Wayland input-method entry is not aligned to the system fcitx desktop file"
fi

if has_feature ghostty && [[ "$(head -n1 "$HOME/.config/xdg-terminals.list")" == "com.mitchellh.ghostty.desktop" ]]; then
  pass "Ghostty is the first XDG terminal preference"
elif has_feature ghostty; then
  fail "Ghostty is not the primary XDG terminal preference"
fi

if zsh -i -c "bindkey '^R' | rg -q 'atuin-search'"; then
  pass "Atuin owns the interactive history keybinding"
else
  fail "Ctrl-R is not bound to Atuin history search"
fi

if zsh -i -c 'command -v pay-respects >/dev/null && alias f >/dev/null'; then
  pass "pay-respects is installed and wired into zsh"
else
  fail "pay-respects is missing or its zsh alias is unavailable"
fi

if TERM= zsh -i -c ':' >/tmp/verify-shell-migration.zsh.log 2>&1; then
  if [[ ! -s /tmp/verify-shell-migration.zsh.log ]]; then
    pass "interactive zsh starts cleanly without TERM"
  else
    fail "interactive zsh produced output without TERM; inspect /tmp/verify-shell-migration.zsh.log"
  fi
else
  fail "interactive zsh exited non-zero without TERM; inspect /tmp/verify-shell-migration.zsh.log"
fi

if has_feature ghostty && infocmp -x ghostty >/dev/null 2>&1; then
  pass "ghostty terminfo is available"
elif has_feature ghostty; then
  fail "ghostty terminfo is missing"
fi

if has_feature graphics && command -v nixGLMesa >/dev/null 2>&1; then
  pass "nixGLMesa wrapper is installed"
elif has_feature graphics; then
  fail "nixGLMesa wrapper is missing"
fi

if has_feature portal && systemctl --user show-environment | rg -q '^NIX_XDG_DESKTOP_PORTAL_DIR='; then
  pass "systemd user environment exports the portal directory"
elif has_feature portal; then
  fail "systemd user environment is missing NIX_XDG_DESKTOP_PORTAL_DIR"
fi

if has_feature portal; then
  kde_portal_unit="$(systemctl --user cat plasma-xdg-desktop-portal-kde.service 2>/dev/null || true)"
  kwallet_unit="$(systemctl --user cat kwalletd6.service 2>/dev/null || true)"

  if [[ -n "$kde_portal_unit" ]] \
    && printf '%s\n' "$kde_portal_unit" | rg -q 'EnvironmentFile=.*/\.config/ahdg/theme/session\.env'; then
    pass "KDE portal backend reads the Nix-managed dynamic theme environment"
  else
    fail "KDE portal backend is missing the Nix-managed dynamic theme environment"
  fi

  if rg -q '^org\.freedesktop\.impl\.portal\.Settings=darkman;gtk;kde;\*$' "$HOME/.config/xdg-desktop-portal/portals.conf"; then
    pass "portal Settings prefers darkman for system color-scheme"
  elif rg -q '^org\.freedesktop\.impl\.portal\.Settings=gtk;kde;\*$' "$HOME/.config/xdg-desktop-portal/portals.conf"; then
    pass "portal Settings falls back to GTK/KDE when darkman auto-switching is disabled"
  else
    fail "portal Settings backend order is unexpected"
  fi

  if rg -q '^org\.freedesktop\.impl\.portal\.Secret=kwallet;\*$' "$HOME/.config/xdg-desktop-portal/portals.conf"; then
    pass "portal Secret prefers KWallet"
  else
    fail "portal Secret does not prefer KWallet"
  fi

  if [[ -n "$kwallet_unit" ]] \
    && printf '%s\n' "$kwallet_unit" | rg -q 'ExecStart=.*/kwalletd6'; then
    pass "kwalletd6 user unit is installed"
  else
    fail "kwalletd6 user unit is missing"
  fi

  if gdbus introspect --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop 2>/dev/null | rg -q 'interface org\.freedesktop\.portal\.Secret'; then
    pass "xdg-desktop-portal exposes the Secret interface"
  else
    fail "xdg-desktop-portal is missing the Secret interface"
  fi
fi

if has_feature gui; then
  dolphin_unit="$(systemctl --user cat plasma-dolphin.service 2>/dev/null || true)"

  if [[ -n "$dolphin_unit" ]] \
    && printf '%s\n' "$dolphin_unit" | rg -q 'EnvironmentFile=.*/\.config/ahdg/theme/session\.env'; then
    pass "Dolphin FileManager1 daemon reads the Nix-managed dynamic theme environment"
  else
    fail "Dolphin FileManager1 daemon is missing the Nix-managed dynamic theme environment"
  fi
fi

if has_feature gui && busctl --user status org.fcitx.Fcitx5 2>/dev/null | rg -q '^Exe=/usr/bin/fcitx5$'; then
  pass "fcitx runtime ownership is back on the system fcitx5 binary"
elif has_feature gui; then
  fail "fcitx runtime is not currently owned by the system fcitx5 binary"
fi

if has_feature ghostty; then
  if timeout 5s ghostty >/tmp/verify-shell-migration.ghostty.stdout 2>/tmp/verify-shell-migration.ghostty.stderr; then
    pass "ghostty exited cleanly during smoke test"
  else
    rc=$?
    if [[ $rc -ne 124 ]]; then
      fail "ghostty smoke test exited non-zero; inspect /tmp/verify-shell-migration.ghostty.stderr"
    fi
  fi

  if ! rg -q 'failed to make GL context current|创建 EGL 显示失败' /tmp/verify-shell-migration.ghostty.stderr; then
    pass "ghostty no longer shows EGL/OpenGL initialization failures"
  else
    fail "ghostty still shows GL/EGL initialization errors; inspect /tmp/verify-shell-migration.ghostty.stderr"
  fi
fi

if [[ $failures -eq 0 ]]; then
  printf '\nMigration checks passed.\n'
else
  printf '\nMigration checks failed: %d\n' "$failures" >&2
  exit 1
fi
