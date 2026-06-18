{ config, lib, pkgs, ... }:
let
  runtime = config.ahdg.theme.runtime;
  modes = runtime.modes;
  themeEnvFile = "${config.xdg.configHome}/ahdg/theme/session.env";

  envText =
    mode:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "${name}=${toString value}") mode.sessionVariables
    )
    + "\n";

  applyTheme = pkgs.writeShellApplication {
    name = "ahdg-theme";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.dbus
      pkgs.dconf
      pkgs.glib
      pkgs.gnugrep
      pkgs.gnused
      pkgs.kdePackages.kconfig
      pkgs.systemd
    ];
    text = ''
      usage() {
        printf 'Usage: ahdg-theme apply <light|dark>\n' >&2
      }

      if [ "''${1:-}" != "apply" ] || [ -z "''${2:-}" ]; then
        usage
        exit 2
      fi

      mode=$2
      case "$mode" in
        light)
          gtk_theme_name="${modes.light.gtk.themeName}"
          gtk_theme_spec="${modes.light.gtk.themeSpec}"
          gtk_theme_dir="${modes.light.gtk.themeDir}"
          gtk_prefer_dark=0
          gsettings_color_scheme="${modes.light.gsettingsColorScheme}"
          kde_color_scheme="${modes.light.kde.colorSchemeName}"
          kde_color_scheme_file="${modes.light.kde.colorSchemeFile}"
          kde_look_and_feel="${modes.light.kde.lookAndFeelName}"
          kde_widget_style="${modes.light.kde.widgetStyle}"
          session_env='${envText modes.light}'
          ;;
        dark)
          gtk_theme_name="${modes.dark.gtk.themeName}"
          gtk_theme_spec="${modes.dark.gtk.themeSpec}"
          gtk_theme_dir="${modes.dark.gtk.themeDir}"
          gtk_prefer_dark=1
          gsettings_color_scheme="${modes.dark.gsettingsColorScheme}"
          kde_color_scheme="${modes.dark.kde.colorSchemeName}"
          kde_color_scheme_file="${modes.dark.kde.colorSchemeFile}"
          kde_look_and_feel="${modes.dark.kde.lookAndFeelName}"
          kde_widget_style="${modes.dark.kde.widgetStyle}"
          session_env='${envText modes.dark}'
          ;;
        *)
          usage
          exit 2
          ;;
      esac

      config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
      data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"

      install -dm755 \
        "$config_home/ahdg/theme" \
        "$config_home/gtk-3.0" \
        "$config_home/xsettingsd" \
        "$data_home/themes"

      printf '%s' "$session_env" > "${themeEnvFile}"
      printf '%s\n' "$mode" > "$config_home/ahdg/theme/mode"

      cat > "$config_home/gtk-3.0/settings.ini" <<EOF
      [Settings]
      gtk-theme-name=$gtk_theme_name
      gtk-icon-theme-name=${runtime.icon.name}
      gtk-font-name=${runtime.gtk.fontName}
      gtk-cursor-theme-name=${runtime.cursor.name}
      gtk-cursor-theme-size=${toString runtime.cursor.size}
      gtk-toolbar-style=GTK_TOOLBAR_ICONS
      gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
      gtk-button-images=0
      gtk-menu-images=0
      gtk-enable-event-sounds=1
      gtk-enable-input-feedback-sounds=0
      gtk-xft-antialias=1
      gtk-xft-hinting=1
      gtk-xft-hintstyle=${config.ahdg.theme.xftHintStyle}
      gtk-xft-rgba=${config.ahdg.theme.xftSubPixel}
      gtk-application-prefer-dark-theme=$gtk_prefer_dark
      EOF

      cat > "$HOME/.gtkrc-2.0" <<EOF
      gtk-theme-name="$gtk_theme_name"
      gtk-icon-theme-name="${runtime.icon.name}"
      gtk-font-name="${runtime.gtk.fontName}"
      gtk-cursor-theme-name="${runtime.cursor.name}"
      gtk-cursor-theme-size=${toString runtime.cursor.size}
      gtk-toolbar-style=GTK_TOOLBAR_ICONS
      gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
      gtk-button-images=0
      gtk-menu-images=0
      gtk-enable-event-sounds=1
      gtk-enable-input-feedback-sounds=0
      gtk-xft-antialias=1
      gtk-xft-hinting=1
      gtk-xft-hintstyle="${config.ahdg.theme.xftHintStyle}"
      gtk-xft-rgba="${config.ahdg.theme.xftSubPixel}"
      EOF

      cat > "$config_home/xsettingsd/xsettingsd.conf" <<EOF
      Net/ThemeName "$gtk_theme_name"
      Net/IconThemeName "${runtime.icon.name}"
      Gtk/CursorThemeName "${runtime.cursor.name}"
      Net/EnableEventSounds 1
      EnableInputFeedbackSounds 0
      Xft/Antialias 1
      Xft/Hinting 1
      Xft/HintStyle "${config.ahdg.theme.xftHintStyle}"
      Xft/RGBA "${config.ahdg.theme.xftSubPixel}"
      EOF

      sync_kde_color_sections() {
        target=$1
        scheme=$2
        tmp="$target.tmp.$$"

        awk '
          function managed_section(line) {
            return line ~ /^\[(ColorEffects:|Colors:)/
          }

          FNR == NR {
            if ($0 ~ /^\[/) {
              in_managed = managed_section($0)
            }
            if (in_managed) {
              scheme_text = scheme_text $0 ORS
            }
            next
          }

          {
            if ($0 ~ /^\[/) {
              skipping = managed_section($0)
            }
            if (!skipping) {
              print
            }
          }

          END {
            if (scheme_text != "") {
              printf "\n%s", scheme_text
            }
          }
        ' "$scheme" "$target" > "$tmp"
        mv "$tmp" "$target"

        for key in \
          activeBackground \
          activeBlend \
          activeForeground \
          inactiveBackground \
          inactiveBlend \
          inactiveForeground
        do
          value="$(
            awk -F= -v wanted="$key" '
              $0 == "[WM]" { in_wm = 1; next }
              /^\[/ { in_wm = 0 }
              in_wm && $1 == wanted {
                print substr($0, index($0, "=") + 1)
                exit
              }
            ' "$scheme"
          )"
          if [ -n "$value" ]; then
            kwriteconfig6 --file "$target" --group WM --key "$key" "$value"
          fi
        done
      }

      tmp_gtk4="$config_home/gtk-4.0.tmp"
      if [ -e "$tmp_gtk4" ]; then
        chmod -R u+w "$tmp_gtk4" 2>/dev/null || true
      fi
      rm -rf "$tmp_gtk4"
      cp -aT "$gtk_theme_dir/gtk-4.0" "$tmp_gtk4"
      chmod -R u+w "$tmp_gtk4" 2>/dev/null || true
      if [ -e "$config_home/gtk-4.0" ]; then
        chmod -R u+w "$config_home/gtk-4.0" 2>/dev/null || true
      fi
      rm -rf "$config_home/gtk-4.0"
      mv "$tmp_gtk4" "$config_home/gtk-4.0"

      kwriteconfig6 --file "$config_home/kdeglobals" --group General --key ColorScheme "$kde_color_scheme"
      kwriteconfig6 --file "$config_home/kdeglobals" --group KDE --key LookAndFeelPackage "$kde_look_and_feel"
      kwriteconfig6 --file "$config_home/kdeglobals" --group KDE --key widgetStyle "$kde_widget_style"
      kwriteconfig6 --file "$config_home/kdeglobals" --group Icons --key Theme "${runtime.icon.name}"
      sync_kde_color_sections "$config_home/kdeglobals" "$kde_color_scheme_file"

      if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
        plasma-apply-colorscheme "$kde_color_scheme" >/dev/null 2>&1 || true
      fi
      sync_kde_color_sections "$config_home/kdeglobals" "$kde_color_scheme_file"

      if [ -f "$config_home/mango/env.conf" ]; then
        sed -i \
          -e "s/^env=GTK_THEME,.*/env=GTK_THEME,$gtk_theme_spec/" \
          -e "s/^env=QT_QPA_PLATFORM,.*/env=QT_QPA_PLATFORM,wayland/" \
          -e "s/^env=QT_QPA_PLATFORMTHEME,.*/env=QT_QPA_PLATFORMTHEME,kde/" \
          "$config_home/mango/env.conf"
      fi

      export GTK_THEME="$gtk_theme_spec"
      export QT_QPA_PLATFORM=wayland
      export QT_QPA_PLATFORMTHEME=kde
      export KDE_SESSION_VERSION=6
      export KDE_FULL_SESSION=true
      export XCURSOR_THEME="${runtime.cursor.name}"
      export XCURSOR_SIZE="${toString runtime.cursor.size}"
      export GTK_USE_PORTAL=1

      systemctl --user import-environment \
        GTK_THEME QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME KDE_SESSION_VERSION KDE_FULL_SESSION \
        XCURSOR_THEME XCURSOR_SIZE GTK_USE_PORTAL 2>/dev/null || true
      dbus-update-activation-environment --systemd \
        GTK_THEME QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME KDE_SESSION_VERSION KDE_FULL_SESSION \
        XCURSOR_THEME XCURSOR_SIZE GTK_USE_PORTAL 2>/dev/null || true

      systemctl --user try-restart --no-block \
        plasma-dolphin.service \
        plasma-xdg-desktop-portal-kde.service \
        xdg-desktop-portal-wlr.service \
        xdg-desktop-portal.service \
        2>/dev/null || true

      # Keep this after Plasma and portal restarts because they can refresh
      # desktop appearance state independently of GTK settings.
      dconf write /org/gnome/desktop/interface/color-scheme "'$gsettings_color_scheme'" 2>/dev/null || true
      dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme_name'" 2>/dev/null || true
      gsettings set org.gnome.desktop.interface color-scheme "$gsettings_color_scheme" 2>/dev/null || true
      gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme_name" 2>/dev/null || true
    '';
  };
in
lib.mkIf config.ahdg.features.gui {
  home.packages = [ applyTheme ];

  home.activation.initializeThemeRuntimeState = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    install -dm755 "${config.xdg.configHome}/ahdg/theme"

    if [[ ! -e "${themeEnvFile}" ]]; then
      printf '%s' ${lib.escapeShellArg (envText modes.dark)} > "${themeEnvFile}"
    fi

    if [[ ! -e "${config.xdg.configHome}/ahdg/theme/mode" ]]; then
      printf 'dark\n' > "${config.xdg.configHome}/ahdg/theme/mode"
    fi
  '';

  services.darkman = {
    enable = true;
    settings = {
      # Avoid depending on a host geoclue agent; these coordinates are enough
      # for sunrise/sunset scheduling and keep the setup self-contained.
      lat = 22.3;
      lng = 114.2;
      usegeoclue = false;
      dbusserver = true;
      portal = true;
    };
    lightModeScripts.ahdg-theme = "${applyTheme}/bin/ahdg-theme apply light";
    darkModeScripts.ahdg-theme = "${applyTheme}/bin/ahdg-theme apply dark";
  };
}
