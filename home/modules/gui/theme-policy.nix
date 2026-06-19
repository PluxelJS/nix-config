{ lib, ... }:
let
  types = lib.types;
in
{
  options.ahdg.theme = {
    catppuccinGtkThemeName = lib.mkOption {
      type = types.str;
      default = "Catppuccin-Macchiato";
      description = "Canonical GTK theme name exposed to toolkit config.";
    };

    catppuccinGtkVariant = lib.mkOption {
      type = types.str;
      default = "dark";
      description = "GTK theme variant exported to session environments.";
    };

    catppuccinKdeColorScheme = lib.mkOption {
      type = types.str;
      default = "CatppuccinMacchiatoLavender";
      description = "Canonical Plasma color scheme name.";
    };

    catppuccinKdeLookAndFeel = lib.mkOption {
      type = types.str;
      default = "Catppuccin-Macchiato-Lavender";
      description = "Canonical Plasma look-and-feel package name.";
    };

    catppuccinKdeAuroraeTheme = lib.mkOption {
      type = types.str;
      default = "CatppuccinMacchiato-Modern";
      description = "Canonical Aurorae window-decoration theme name.";
    };

    kdeWidgetStyle = lib.mkOption {
      type = types.str;
      default = "Darkly";
      description = "Canonical Qt widget style name.";
    };

    iconThemeName = lib.mkOption {
      type = types.str;
      default = "Papirus";
      description = "Single icon theme shared across toolkits.";
    };

    cursorThemeName = lib.mkOption {
      type = types.str;
      default = "Bibata-Modern-Ice";
      description = "Single cursor theme shared across toolkits and session env.";
    };

    cursorSize = lib.mkOption {
      type = types.int;
      default = 24;
      description = "Single cursor size shared across toolkits and session env.";
    };

    gtkFontFamily = lib.mkOption {
      type = types.str;
      default = "Inter";
      description = "GTK-facing UI font family.";
    };

    gtkFontSize = lib.mkOption {
      type = types.int;
      default = 13;
      description = "GTK UI font size in points.";
    };

    kdeUiFontFamily = lib.mkOption {
      type = types.str;
      default = "Inter";
      description = "KDE UI font family.";
    };

    kdeUiFontSize = lib.mkOption {
      type = types.int;
      default = 12;
      description = "KDE UI font size in points.";
    };

    kdeFixedFontFamily = lib.mkOption {
      type = types.str;
      default = "Monospace";
      description = "KDE fixed-width font family alias.";
    };

    kdeFixedFontSize = lib.mkOption {
      type = types.int;
      default = 13;
      description = "KDE fixed-width font size in points.";
    };

    xftHintStyle = lib.mkOption {
      type = types.str;
      default = "hintslight";
      description = "Font hinting policy mirrored into toolkit-specific settings.";
    };

    xftSubPixel = lib.mkOption {
      type = types.str;
      default = "rgb";
      description = "Subpixel rendering policy mirrored into toolkit-specific settings.";
    };
  };
}
