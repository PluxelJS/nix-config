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
    rev = "be0b21d0873092a63946cc2678dd700aac945902";
    hash = "sha256-Dy73TfcrcbCXY9lwDszNgAKLiCAHf1KIwC4Q5U6k21E=";
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
