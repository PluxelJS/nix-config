{ config, lib, pkgs, ... }:
lib.mkIf config.ahdg.features.fastfetch {
  home.packages = [ pkgs.fastfetch ];

  xdg.configFile = {
    "fastfetch/config.jsonc".source = ../files/fastfetch/config.jsonc;
    "fastfetch/png" = {
      source = ../files/fastfetch/png;
      recursive = true;
    };
    "fastfetch/assets" = {
      source = ../files/fastfetch/assets;
      recursive = true;
    };
  };
}
