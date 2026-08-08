{ config, lib, ... }:
let
  guiLib = import ./lib.nix { inherit lib; };
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
  flatpakMaterializedFiles = [
    "${config.home.homeDirectory}/.gtkrc-2.0"
    "${config.xdg.configHome}/gtk-3.0/settings.ini"
    "${config.xdg.configHome}/xsettingsd/xsettingsd.conf"
  ];
  managedGtkAssetTargets = [
    "${config.xdg.dataHome}/themes/${modes.dark.gtk.themeName}"
    "${config.xdg.dataHome}/themes/${modes.light.gtk.themeName}"
    "${config.xdg.dataHome}/icons/Papirus"
    "${config.xdg.dataHome}/icons/breeze"
    "${config.xdg.dataHome}/icons/Bibata-Modern-Ice"
  ];
  flatpakMaterializedDirs = [ "${config.xdg.configHome}/gtk-4.0" ] ++ managedGtkAssetTargets;
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
  home.activation.prepareManagedGtkAssets = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    # The previous generation materializes these store links for Flatpak.
    # Remove only those declared targets before Home Manager links the next one.
    for target in ${lib.escapeShellArgs managedGtkAssetTargets}; do
      if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
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

  home.activation.materializeGtkThemeForFlatpak = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # Flatpak can see these XDG paths, but store-backed symlinks are not
    # reliable inside the sandbox. Materialize the runtime copies after HM links.
    ${guiLib.materializeRuntimePaths {
      files = flatpakMaterializedFiles;
      dirs = flatpakMaterializedDirs;
    }}
  '';

  xdg.dataFile = lib.listToAttrs managedGtkAssets;
}
