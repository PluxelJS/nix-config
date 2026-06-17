{ config, lib, pkgs, ... }:
let
  theme = config.ahdg.theme;
  runtime = theme.runtime;
  gtkThemeName = runtime.gtk.themeName;
  iconThemeName = runtime.icon.name;
  cursorThemeName = runtime.cursor.name;
  gtkFontName = runtime.gtk.fontName;
  gtk3SettingsText = ''
    [Settings]
    gtk-theme-name=${gtkThemeName}
    gtk-icon-theme-name=${iconThemeName}
    gtk-font-name=${gtkFontName}
    gtk-cursor-theme-name=${cursorThemeName}
    gtk-cursor-theme-size=${toString theme.cursorSize}
    gtk-toolbar-style=GTK_TOOLBAR_ICONS
    gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
    gtk-button-images=0
    gtk-menu-images=0
    gtk-enable-event-sounds=1
    gtk-enable-input-feedback-sounds=0
    gtk-xft-antialias=1
    gtk-xft-hinting=1
    gtk-xft-hintstyle=${theme.xftHintStyle}
    gtk-xft-rgba=${theme.xftSubPixel}
    gtk-application-prefer-dark-theme=1
  '';
  gtk2RcText = ''
    gtk-theme-name="${gtkThemeName}"
    gtk-icon-theme-name="${iconThemeName}"
    gtk-font-name="${gtkFontName}"
    gtk-cursor-theme-name="${cursorThemeName}"
    gtk-cursor-theme-size=${toString theme.cursorSize}
    gtk-toolbar-style=GTK_TOOLBAR_ICONS
    gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
    gtk-button-images=0
    gtk-menu-images=0
    gtk-enable-event-sounds=1
    gtk-enable-input-feedback-sounds=0
    gtk-xft-antialias=1
    gtk-xft-hinting=1
    gtk-xft-hintstyle="${theme.xftHintStyle}"
    gtk-xft-rgba="${theme.xftSubPixel}"
  '';
  xsettingsdText = ''
    Net/ThemeName "${gtkThemeName}"
    Net/IconThemeName "${iconThemeName}"
    Gtk/CursorThemeName "${cursorThemeName}"
    Net/EnableEventSounds 1
    EnableInputFeedbackSounds 0
    Xft/Antialias 1
    Xft/Hinting 1
    Xft/HintStyle "${theme.xftHintStyle}"
    Xft/RGBA "${theme.xftSubPixel}"
  '';
in
lib.mkIf config.ahdg.features.gui {
  home.activation.removeLegacyGtkThemeArtifacts = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for target in \
      "${config.home.homeDirectory}/.gtkrc-2.0" \
      "${config.home.homeDirectory}/.gtkrc-2.0.mine" \
      "${config.xdg.configHome}/gtkrc" \
      "${config.xdg.configHome}/gtk-3.0/settings.ini" \
      "${config.xdg.configHome}/gtk-3.0/gtk.css" \
      "${config.xdg.configHome}/gtk-3.0/dank-colors.css" \
      "${config.xdg.configHome}/gtk-4.0" \
      "${config.xdg.configHome}/xsettingsd/xsettingsd.conf" \
      "${config.xdg.dataHome}/themes/Abyssal-Wave" \
      "${config.xdg.dataHome}/themes/Catppuccin-Macchiato" \
      "${config.xdg.dataHome}/themes/Catppuccin-Latte" \
      "${config.xdg.dataHome}/themes/Catppuccin-Mocha" \
      "${config.xdg.dataHome}/themes/Decay-Green" \
      "${config.xdg.dataHome}/themes/Edge-Runner" \
      "${config.xdg.dataHome}/themes/Everforest-Dark" \
      "${config.xdg.dataHome}/themes/Frosted-Glass" \
      "${config.xdg.dataHome}/themes/Graphite-Mono" \
      "${config.xdg.dataHome}/themes/Gruvbox-Retro" \
      "${config.xdg.dataHome}/themes/Material-Sakura" \
      "${config.xdg.dataHome}/themes/Nordic-Blue" \
      "${config.xdg.dataHome}/themes/Rose-Pine" \
      "${config.xdg.dataHome}/themes/Synth-Wave" \
      "${config.xdg.dataHome}/themes/Tokyo-Night" \
      "${config.xdg.dataHome}/themes/Wallbash-Gtk" \
      "${config.xdg.dataHome}/icons/BeautyLine" \
      "${config.xdg.dataHome}/icons/Gruvbox-Plus-Dark" \
      "${config.xdg.dataHome}/icons/Gruvbox-Retro" \
      "${config.xdg.dataHome}/icons/Nordzy" \
      "${config.xdg.dataHome}/icons/Papirus" \
      "${config.xdg.dataHome}/icons/Tela-circle-black" \
      "${config.xdg.dataHome}/icons/Tela-circle-blue" \
      "${config.xdg.dataHome}/icons/Tela-circle-dracula" \
      "${config.xdg.dataHome}/icons/Tela-circle-green" \
      "${config.xdg.dataHome}/icons/Tela-circle-grey" \
      "${config.xdg.dataHome}/icons/Tela-circle-pink" \
      "${config.xdg.dataHome}/icons/Tela-circle-purple" \
      "${config.xdg.dataHome}/icons/Tela-circle-yellow" \
      "${config.xdg.dataHome}/icons/breeze" \
      "${config.xdg.dataHome}/icons/Kanagawa" \
      "${config.xdg.dataHome}/icons/Papirus-kanagawa" \
      "${config.xdg.dataHome}/icons/Catppuccin-Macchiato-Dark-Cursors" \
      "${config.xdg.dataHome}/icons/Wallbash-Icon" \
      "${config.xdg.dataHome}/icons/Bibata-Modern-Ice"
    do
      if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        chmod -R u+w "$target" 2>/dev/null || true
        rm -rf "$target"
      fi
    done
  '';

  home.activation.removeDeprecatedGtkIconArtifacts = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    rm -rf \
      "${config.xdg.dataHome}/icons/Kanagawa"
  '';

  home.activation.materializeGtkThemeForFlatpak = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    materialize_file() {
      local target=$1
      local resolved=

      if [[ ! -e "$target" ]]; then
        return
      fi

      resolved="$(readlink -f "$target" || true)"
      if [[ -n "$resolved" && "$resolved" != "$target" && -f "$resolved" ]]; then
        rm -f "$target"
        install -Dm644 "$resolved" "$target"
      fi
    }

    materialize_dir() {
      local target=$1
      local resolved=

      if [[ ! -e "$target" ]]; then
        return
      fi

      resolved="$(readlink -f "$target" || true)"
      if [[ -n "$resolved" && "$resolved" != "$target" && -d "$resolved" ]]; then
        rm -rf "$target"
        mkdir -p "$(dirname "$target")"
        cp -aT "$resolved" "$target"
      fi
    }

    # Flatpak can see these XDG paths, but store-backed symlinks are not
    # reliable inside the sandbox. Materialize the runtime copies after HM links.
    materialize_file "${config.xdg.configHome}/gtk-3.0/settings.ini"
    materialize_dir "${config.xdg.configHome}/gtk-4.0"
    materialize_dir "${config.xdg.dataHome}/themes/Catppuccin-Macchiato"
    materialize_dir "${config.xdg.dataHome}/icons/Papirus"
    materialize_dir "${config.xdg.dataHome}/icons/breeze"
    materialize_dir "${config.xdg.dataHome}/icons/Bibata-Modern-Ice"
  '';

  home.file.".gtkrc-2.0" = {
    force = true;
    text = gtk2RcText;
  };

  xdg.configFile = {
    "gtk-3.0/settings.ini" = {
      force = true;
      text = gtk3SettingsText;
    };
    "gtk-4.0" = {
      force = true;
      source = "${runtime.gtk.themeDir}/gtk-4.0";
    };
    "xsettingsd/xsettingsd.conf" = {
      force = true;
      text = xsettingsdText;
    };
  };

  xdg.dataFile."themes/Catppuccin-Macchiato" = {
    force = true;
    source = runtime.gtk.themeDir;
  };

  xdg.dataFile."icons/Papirus" = {
    force = true;
    source = runtime.icon.papirusDir;
  };

  xdg.dataFile."icons/breeze" = {
    force = true;
    source = runtime.icon.breezeDir;
  };

  xdg.dataFile."icons/Bibata-Modern-Ice" = {
    force = true;
    source = runtime.cursor.dir;
  };
}
