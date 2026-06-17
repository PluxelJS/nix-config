{ config, lib, pkgs, ... }:
let
  types = lib.types;
  theme = config.ahdg.theme;

  catppuccinGtk = pkgs.catppuccin-gtk.override {
    variant = "macchiato";
    accents = [ "lavender" ];
    size = "standard";
    tweaks = [ ];
  };

  catppuccinKde = pkgs.catppuccin-kde.override {
    flavour = [ "macchiato" ];
    accents = [ "lavender" ];
    winDecStyles = [ "modern" ];
  };

  gtkThemeDir = "${catppuccinGtk}/share/themes/catppuccin-macchiato-lavender-standard";
  gtkThemeSpec = "${theme.catppuccinGtkThemeName}:${theme.catppuccinGtkVariant}";
  gtkFontName = "${theme.gtkFontFamily} ${toString theme.gtkFontSize}";
  kdeFontValue = "${theme.kdeUiFontFamily},${toString theme.kdeUiFontSize},-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
  kdeFixedFontValue = "${theme.kdeFixedFontFamily},${toString theme.kdeFixedFontSize},-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
  sessionVariables =
    {
      GTK_THEME = gtkThemeSpec;
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
in
{
  options.ahdg.theme.runtime = lib.mkOption {
    type = types.attrsOf types.anything;
    internal = true;
    description = "Resolved GUI theme runtime values derived from ahdg.theme.";
  };

  config = lib.mkIf config.ahdg.features.gui {
    ahdg.theme.runtime = {
      gtk = {
        package = catppuccinGtk;
        themeDir = gtkThemeDir;
        themeName = theme.catppuccinGtkThemeName;
        themeSpec = gtkThemeSpec;
        fontName = gtkFontName;
      };

      kde = {
        package = catppuccinKde;
        colorSchemeName = theme.catppuccinKdeColorScheme;
        lookAndFeelName = theme.catppuccinKdeLookAndFeel;
        auroraeThemeName = theme.catppuccinKdeAuroraeTheme;
        widgetStyle = theme.kdeWidgetStyle;
        fontValue = kdeFontValue;
        fixedFontValue = kdeFixedFontValue;
      };

      icon = {
        name = theme.iconThemeName;
        papirusDir = "${pkgs.papirus-icon-theme}/share/icons/Papirus";
        breezeDir = "${pkgs.kdePackages.breeze-icons}/share/icons/breeze";
      };

      cursor = {
        name = theme.cursorThemeName;
        size = theme.cursorSize;
        dir = "${pkgs.bibata-cursors}/share/icons/${theme.cursorThemeName}";
      };

      session = {
        inherit sessionVariables;
      };
    };

    home.sessionVariables = sessionVariables;
  };
}
