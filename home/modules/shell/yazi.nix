{
  config,
  lib,
  pkgs,
  ...
}:
let
  yaziCatppuccin = pkgs.desktopSources.yazi-flavors.src;
in
lib.mkIf config.ahdg.features.desktopXdg {
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "yy";

    flavors = {
      catppuccin-macchiato = "${yaziCatppuccin}/catppuccin-macchiato.yazi";
    };

    theme = {
      flavor = {
        dark = "catppuccin-macchiato";
      };
    };
  };
}
