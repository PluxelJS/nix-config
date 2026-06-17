{ config, lib, pkgs, ... }:
let
  yaziCatppuccin = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "flavors";
    rev = "0f9204bc948c8313963f5c9d571a82edc201f8aa";
    hash = "sha256-qWNArjWuxWL+rOjLzyIniW5hJgWiAWTCgXmMXJpaWZE=";
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
