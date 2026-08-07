{
  config,
  lib,
  pkgs,
  ...
}:
let
  guiLib = import ./lib.nix { inherit lib; };
  theme = config.ahdg.theme;
  runtime = theme.runtime;
  modes = runtime.modes;
  themeModes = [
    modes.dark
    modes.light
  ];
  colorSchemeName = runtime.kde.colorSchemeName;
  lookAndFeelName = runtime.kde.lookAndFeelName;
  auroraeThemeName = runtime.kde.auroraeThemeName;
  legacyPlasmaArtifacts = [
    "${config.xdg.configHome}/color-schemes/${colorSchemeName}.colors"
    "${config.xdg.dataHome}/color-schemes/${colorSchemeName}.colors"
    "${config.xdg.dataHome}/plasma/look-and-feel/${lookAndFeelName}"
    "${config.xdg.dataHome}/kpackage/generic/${lookAndFeelName}"
    "${config.xdg.dataHome}/aurorae/themes/${auroraeThemeName}"
    "${config.xdg.dataHome}/icons/Papirus-kanagawa"
    "${config.xdg.dataHome}/icons/Catppuccin-Macchiato-Lavender-Cursors"
  ];
  materializedColorSchemeTargets = lib.concatMap (mode: [
    "${config.xdg.configHome}/color-schemes/${mode.kde.colorSchemeName}.colors"
    "${config.xdg.dataHome}/color-schemes/${mode.kde.colorSchemeName}.colors"
  ]) themeModes;
  mkDataFile =
    name: source:
    lib.nameValuePair name {
      force = true;
      inherit source;
    };
  configColorSchemeFiles = map (
    mode:
    mkDataFile "color-schemes/${mode.kde.colorSchemeName}.colors" "${mode.kde.package}/share/color-schemes/${mode.kde.colorSchemeName}.colors"
  ) themeModes;
  dataThemeFiles =
    configColorSchemeFiles
    ++ map (
      mode:
      mkDataFile "plasma/look-and-feel/${mode.kde.lookAndFeelName}" "${mode.kde.package}/share/plasma/look-and-feel/${mode.kde.lookAndFeelName}"
    ) themeModes
    ++ map (
      mode:
      mkDataFile "aurorae/themes/${mode.kde.auroraeThemeName}" "${mode.kde.package}/share/aurorae/themes/${mode.kde.auroraeThemeName}"
    ) themeModes;
in
lib.mkIf config.ahdg.features.gui {
  home.activation.removeLegacyPlasmaThemeArtifacts = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for target in ${lib.escapeShellArgs legacyPlasmaArtifacts}; do
      if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        rm -rf "$target"
      fi
    done
  '';

  home.activation.removeDeprecatedPlasmaThemeArtifacts = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    rm -rf \
      "${config.xdg.dataHome}/kpackage/generic/${lookAndFeelName}"
  '';

  home.activation.materializePlasmaThemeForFlatpak = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # Some KDE-aware Flatpaks only get config/data shares, not arbitrary store
    # paths. Keep the color scheme materialized in both locations.
    ${guiLib.materializeRuntimePaths { files = materializedColorSchemeTargets; }}
  '';

  xdg.configFile = lib.listToAttrs configColorSchemeFiles;
  xdg.dataFile = lib.listToAttrs dataThemeFiles;
}
