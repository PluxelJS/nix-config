{ config, lib, pkgs, ... }:
lib.mkIf config.ahdg.features.ghostty {
  # On non-NixOS systems Ghostty needs host GL/EGL libraries. Wrap it through
  # Home Manager's nixGL integration so both CLI launches and desktop entries
  # use the same working package.
  home.packages = [ (config.lib.nixGL.wrap pkgs.ghostty) ];

  xdg.configFile = {
    "ghostty/config".source = ../files/ghostty/config;
  };
}
