{ config, lib, pkgs, ... }:
let
  catppuccinKde = pkgs.catppuccin-kde.override {
    flavour = [ "macchiato" ];
    accents = [ "lavender" ];
    winDecStyles = [ "modern" ];
  };
  colorSchemeName = "CatppuccinMacchiatoLavender";
  lookAndFeelName = "Catppuccin-Macchiato-Lavender";
  auroraeThemeName = "CatppuccinMacchiato-Modern";
in
lib.mkIf config.ahdg.features.gui {
  home.activation.removeLegacyPlasmaThemeArtifacts = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for target in \
      "${config.xdg.configHome}/color-schemes/${colorSchemeName}.colors" \
      "${config.xdg.dataHome}/color-schemes/${colorSchemeName}.colors" \
      "${config.xdg.dataHome}/plasma/look-and-feel/${lookAndFeelName}" \
      "${config.xdg.dataHome}/kpackage/generic/${lookAndFeelName}" \
      "${config.xdg.dataHome}/aurorae/themes/${auroraeThemeName}" \
      "${config.xdg.dataHome}/icons/Papirus-kanagawa" \
      "${config.xdg.dataHome}/icons/Catppuccin-Macchiato-Lavender-Cursors"
    do
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

    # Some KDE-aware Flatpaks only get config/data shares, not arbitrary store
    # paths. Keep the color scheme materialized in both locations.
    materialize_file "${config.xdg.configHome}/color-schemes/${colorSchemeName}.colors"
    materialize_file "${config.xdg.dataHome}/color-schemes/${colorSchemeName}.colors"
  '';

  home.activation.removeUnusedQtctConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for target in \
      "${config.xdg.configHome}/qt5ct" \
      "${config.xdg.configHome}/qt6ct"
    do
      if [[ -e "$target" ]]; then
        rm -rf "$target"
      fi
    done
  '';

  home.activation.alignKdeglobalsThemeStack = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kdeglobals="${config.xdg.configHome}/kdeglobals"
    if [[ -f "$kdeglobals" ]]; then
      sed -i \
        -e '/^\[General\]/,/^\[/{s/^ColorScheme=.*/ColorScheme='"${colorSchemeName}"'/;}' \
        -e '/^\[General\]/,/^\[/{s#^TerminalApplication=.*#TerminalApplication='"${config.home.profileDirectory}"'/bin/ghostty --gtk-single-instance=true#;}' \
        -e '/^\[Icons\]/,/^\[/{s/^Theme=.*/Theme=Papirus/;}' \
        -e '/^\[KDE\]/,/^\[/{s/^LookAndFeelPackage=.*/LookAndFeelPackage='"${lookAndFeelName}"'/;}' \
        -e '/^\[KDE\]/,/^\[/{s/^widgetStyle=.*/widgetStyle=Darkly/;}' \
        "$kdeglobals"
    fi
  '';

  xdg.configFile."color-schemes/${colorSchemeName}.colors" = {
    force = true;
    source = "${catppuccinKde}/share/color-schemes/${colorSchemeName}.colors";
  };

  xdg.dataFile = {
    "color-schemes/${colorSchemeName}.colors" = {
      force = true;
      source = "${catppuccinKde}/share/color-schemes/${colorSchemeName}.colors";
    };
    "plasma/look-and-feel/${lookAndFeelName}" = {
      force = true;
      source = "${catppuccinKde}/share/plasma/look-and-feel/${lookAndFeelName}";
    };
    "aurorae/themes/${auroraeThemeName}" = {
      force = true;
      source = "${catppuccinKde}/share/aurorae/themes/${auroraeThemeName}";
    };
  };
}
