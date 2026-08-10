{ config, lib, pkgs, ... }:
let
  types = lib.types;
  theme = config.ahdg.theme;
  defaultMode = "dark";

  gtkFontName = "${theme.gtkFontFamily} ${toString theme.gtkFontSize}";
  kdeFontValue = "${theme.kdeUiFontFamily},${toString theme.kdeUiFontSize},-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
  kdeFixedFontValue = "${theme.kdeFixedFontFamily},${toString theme.kdeFixedFontSize},-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
  baseSessionVariables =
    {
      QT_QPA_PLATFORM = "wayland";
      QT_QPA_PLATFORMTHEME = "kde";
      KDE_SESSION_VERSION = "6";
      KDE_FULL_SESSION = "true";
      XCURSOR_THEME = theme.cursorThemeName;
      XCURSOR_SIZE = toString theme.cursorSize;
    }
    // lib.optionalAttrs config.ahdg.features.portal {
      GTK_USE_PORTAL = "1";
    };

  mkCatppuccinGtk =
    variant:
    pkgs.catppuccin-gtk.override {
      inherit variant;
      accents = [ "lavender" ];
      size = "standard";
      tweaks = [ ];
    };

  mkCatppuccinKde =
    flavour:
    pkgs.catppuccin-kde.override {
      flavour = [ flavour ];
      accents = [ "lavender" ];
      winDecStyles = [ "modern" ];
    };

  mkMode =
    {
      name,
      gtkName,
      gtkVariant,
      gtkDirName,
      kdeFlavour,
      kdeColorScheme,
      kdeLookAndFeel,
      kdeAurorae,
      kdeWidgetStyle,
      gsettingsColorScheme,
    }:
    let
      gtkPackage = mkCatppuccinGtk gtkVariant;
      kdePackage = mkCatppuccinKde kdeFlavour;
      gtkThemeSpec = "${gtkName}:${if name == "dark" then "dark" else "light"}";
    in
    {
      inherit name gsettingsColorScheme;

      gtk = {
        package = gtkPackage;
        themeDir = "${gtkPackage}/share/themes/${gtkDirName}";
        themeName = gtkName;
        themeSpec = gtkThemeSpec;
        fontName = gtkFontName;
        preferDark = name == "dark";
      };

      kde = {
        package = kdePackage;
        colorSchemeName = kdeColorScheme;
        colorSchemeFile = "${kdePackage}/share/color-schemes/${kdeColorScheme}.colors";
        lookAndFeelName = kdeLookAndFeel;
        auroraeThemeName = kdeAurorae;
        widgetStyle = kdeWidgetStyle;
        fontValue = kdeFontValue;
        fixedFontValue = kdeFixedFontValue;
      };

      sessionVariables = { GTK_THEME = gtkThemeSpec; } // baseSessionVariables;
    };

  modes = {
    light = mkMode {
      name = "light";
      gtkName = "Catppuccin-Latte";
      gtkVariant = "latte";
      gtkDirName = "catppuccin-latte-lavender-standard";
      kdeFlavour = "latte";
      kdeColorScheme = "CatppuccinLatteLavender";
      kdeLookAndFeel = "Catppuccin-Latte-Lavender";
      kdeAurorae = "CatppuccinLatte-Modern";
      kdeWidgetStyle = "Breeze";
      gsettingsColorScheme = "prefer-light";
    };

    dark = mkMode {
      name = "dark";
      gtkName = theme.catppuccinGtkThemeName;
      gtkVariant = "macchiato";
      gtkDirName = "catppuccin-macchiato-lavender-standard";
      kdeFlavour = "macchiato";
      kdeColorScheme = theme.catppuccinKdeColorScheme;
      kdeLookAndFeel = theme.catppuccinKdeLookAndFeel;
      kdeAurorae = theme.catppuccinKdeAuroraeTheme;
      kdeWidgetStyle = theme.kdeWidgetStyle;
      gsettingsColorScheme = "prefer-dark";
    };
  };

  activeMode = modes.${defaultMode};
in
{
  options.ahdg.theme.runtime = lib.mkOption {
    type = types.attrsOf types.anything;
    internal = true;
    description = "Resolved GUI theme runtime values derived from ahdg.theme.";
  };

  config = lib.mkIf config.ahdg.features.gui {
    # Let Home Manager publish the Xcursor package, default inheritance file,
    # legacy ~/.icons links, Xresources values, and XCURSOR_PATH as one unit.
    # Toolkit- and compositor-specific settings below consume the same values.
    home.pointerCursor = {
      enable = true;
      package = pkgs.bibata-cursors;
      name = theme.cursorThemeName;
      size = theme.cursorSize;
      dotIcons.enable = true;
      x11.enable = true;
    };

    ahdg.theme.runtime = {
      modes = modes;
      defaultMode = defaultMode;
      gtk = activeMode.gtk;
      kde = activeMode.kde;

      icon = {
        name = theme.iconThemeName;
        papirusDir = "${pkgs.papirus-icon-theme}/share/icons/${theme.iconThemeName}";
        breezeDir = "${pkgs.kdePackages.breeze-icons}/share/icons/breeze";
      };

      cursor = {
        name = theme.cursorThemeName;
        size = theme.cursorSize;
        dir = "${pkgs.bibata-cursors}/share/icons/${theme.cursorThemeName}";
      };

      session = {
        sessionVariables = activeMode.sessionVariables;
        baseSessionVariables = baseSessionVariables;
      };
    };

    home.sessionVariables = baseSessionVariables;
  };
}
