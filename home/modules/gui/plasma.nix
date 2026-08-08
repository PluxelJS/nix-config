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
  home.activation.prepareManagedPlasmaAssets = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    # The previous generation materializes these store links for Flatpak.
    # Remove only those declared targets before Home Manager links the next one.
    for target in ${lib.escapeShellArgs materializedColorSchemeTargets}; do
      if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        rm -rf "$target"
      fi
    done
  '';

  home.activation.materializePlasmaThemeForFlatpak = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # Some KDE-aware Flatpaks only get config/data shares, not arbitrary store
    # paths. Keep the color scheme materialized in both locations.
    ${guiLib.materializeRuntimePaths { files = materializedColorSchemeTargets; }}
  '';

  xdg.configFile = lib.listToAttrs configColorSchemeFiles;
  xdg.dataFile = lib.listToAttrs dataThemeFiles;
}
