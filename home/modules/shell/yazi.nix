{
  config,
  lib,
  pkgs,
  ...
}:
let
  yaziCatppuccin = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "flavors";
    rev = "20b47bfd78880c2674899597fd26bc01b21ff48c";
    hash = "sha256-NGnfrQdsnQITKCZ0oh6DCxeCR2ozJoPAZetsi3ghHAI=";
  };
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
