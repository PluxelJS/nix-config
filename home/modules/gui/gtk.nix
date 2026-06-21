{ config, lib, pkgs, ... }:
let
  theme = config.ahdg.theme;
  runtime = theme.runtime;
  modes = runtime.modes;
  themeModes = [
    modes.dark
    modes.light
  ];
  gtkThemeName = runtime.gtk.themeName;
  iconThemeName = runtime.icon.name;
  cursorThemeName = runtime.cursor.name;
  gtkFontName = runtime.gtk.fontName;
  legacyGtkArtifacts = [
    "${config.home.homeDirectory}/.gtkrc-2.0.mine"
    "${config.xdg.configHome}/gtkrc"
    "${config.xdg.configHome}/gtk-3.0/gtk.css"
    "${config.xdg.configHome}/gtk-3.0/dank-colors.css"
    "${config.xdg.dataHome}/themes/Abyssal-Wave"
    "${config.xdg.dataHome}/themes/Catppuccin-Macchiato"
    "${config.xdg.dataHome}/themes/Catppuccin-Latte"
    "${config.xdg.dataHome}/themes/Catppuccin-Mocha"
    "${config.xdg.dataHome}/themes/Decay-Green"
    "${config.xdg.dataHome}/themes/Edge-Runner"
    "${config.xdg.dataHome}/themes/Everforest-Dark"
    "${config.xdg.dataHome}/themes/Frosted-Glass"
    "${config.xdg.dataHome}/themes/Graphite-Mono"
    "${config.xdg.dataHome}/themes/Gruvbox-Retro"
    "${config.xdg.dataHome}/themes/Material-Sakura"
    "${config.xdg.dataHome}/themes/Nordic-Blue"
    "${config.xdg.dataHome}/themes/Rose-Pine"
    "${config.xdg.dataHome}/themes/Synth-Wave"
    "${config.xdg.dataHome}/themes/Tokyo-Night"
    "${config.xdg.dataHome}/themes/Wallbash-Gtk"
    "${config.xdg.dataHome}/icons/BeautyLine"
    "${config.xdg.dataHome}/icons/Gruvbox-Plus-Dark"
    "${config.xdg.dataHome}/icons/Gruvbox-Retro"
    "${config.xdg.dataHome}/icons/Nordzy"
    "${config.xdg.dataHome}/icons/Papirus"
    "${config.xdg.dataHome}/icons/Tela-circle-black"
    "${config.xdg.dataHome}/icons/Tela-circle-blue"
    "${config.xdg.dataHome}/icons/Tela-circle-dracula"
    "${config.xdg.dataHome}/icons/Tela-circle-green"
    "${config.xdg.dataHome}/icons/Tela-circle-grey"
    "${config.xdg.dataHome}/icons/Tela-circle-pink"
    "${config.xdg.dataHome}/icons/Tela-circle-purple"
    "${config.xdg.dataHome}/icons/Tela-circle-yellow"
    "${config.xdg.dataHome}/icons/breeze"
    "${config.xdg.dataHome}/icons/Kanagawa"
    "${config.xdg.dataHome}/icons/Papirus-kanagawa"
    "${config.xdg.dataHome}/icons/Catppuccin-Macchiato-Dark-Cursors"
    "${config.xdg.dataHome}/icons/Wallbash-Icon"
    "${config.xdg.dataHome}/icons/Bibata-Modern-Ice"
  ];
  legacyGtkHomeArtifacts = [
    "${config.home.homeDirectory}/.themes/Catppuccin-Latte"
    "${config.home.homeDirectory}/.themes/Catppuccin-Mocha"
    "${config.home.homeDirectory}/.themes/Rose-Pine"
    "${config.home.homeDirectory}/.themes/Wallbash-Gtk"
  ];
  mkDataDirLink =
    name: source:
    lib.nameValuePair name {
      force = true;
      inherit source;
    };
  managedGtkAssets =
    map (mode: mkDataDirLink "themes/${mode.gtk.themeName}" mode.gtk.themeDir) themeModes
    ++ [
      (mkDataDirLink "icons/Papirus" runtime.icon.papirusDir)
      (mkDataDirLink "icons/breeze" runtime.icon.breezeDir)
      (mkDataDirLink "icons/Bibata-Modern-Ice" runtime.cursor.dir)
    ];
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
    gtk-application-prefer-dark-theme=${if runtime.gtk.preferDark then "1" else "0"}
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
    for target in ${lib.escapeShellArgs legacyGtkArtifacts}; do
      if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        chmod -R u+w "$target" 2>/dev/null || true
        rm -rf "$target"
      fi
    done

    for target in ${lib.escapeShellArgs legacyGtkHomeArtifacts}; do
      if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        chmod -R u+w "$target" 2>/dev/null || true
        rm -rf "$target"
      fi
    done
  '';

  home.activation.initializeGtkThemeDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    seed_text_file() {
      local target_path=$1
      local content=$2

      if [[ -L "$target_path" ]]; then
        rm -f "$target_path"
      fi

      if [[ ! -e "$target_path" ]]; then
        install -dm755 "$(dirname "$target_path")"
        printf '%s' "$content" > "$target_path"
      fi
    }

    seed_dir_copy() {
      local source_path=$1
      local target_path=$2

      if [[ -L "$target_path" ]]; then
        rm -rf "$target_path"
      fi

      if [[ ! -e "$target_path" ]]; then
        install -dm755 "$(dirname "$target_path")"
        cp -aT "$source_path" "$target_path"
        chmod -R u+w "$target_path" 2>/dev/null || true
      fi
    }

    seed_text_file "${config.home.homeDirectory}/.gtkrc-2.0" ${lib.escapeShellArg gtk2RcText}
    seed_text_file "${config.xdg.configHome}/gtk-3.0/settings.ini" ${lib.escapeShellArg gtk3SettingsText}
    seed_text_file "${config.xdg.configHome}/xsettingsd/xsettingsd.conf" ${lib.escapeShellArg xsettingsdText}
    seed_dir_copy "${runtime.gtk.themeDir}/gtk-4.0" "${config.xdg.configHome}/gtk-4.0"
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
    materialize_file "${config.home.homeDirectory}/.gtkrc-2.0"
    materialize_file "${config.xdg.configHome}/gtk-3.0/settings.ini"
    materialize_file "${config.xdg.configHome}/xsettingsd/xsettingsd.conf"
    materialize_dir "${config.xdg.configHome}/gtk-4.0"
    materialize_dir "${config.xdg.dataHome}/themes/${modes.dark.gtk.themeName}"
    materialize_dir "${config.xdg.dataHome}/themes/${modes.light.gtk.themeName}"
    materialize_dir "${config.xdg.dataHome}/icons/Papirus"
    materialize_dir "${config.xdg.dataHome}/icons/breeze"
    materialize_dir "${config.xdg.dataHome}/icons/Bibata-Modern-Ice"
  '';

  xdg.dataFile = lib.listToAttrs managedGtkAssets;
}
