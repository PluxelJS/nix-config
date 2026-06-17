{ config, lib, pkgs, ... }:
let
  packages =
    lib.optionals config.ahdg.features.fonts [
      pkgs.inter
      pkgs.source-han-sans
      pkgs.source-han-serif
      pkgs.maple-mono."NF-CN"
      pkgs.twitter-color-emoji
      pkgs.noto-fonts-color-emoji
    ]
    ++ lib.optionals config.ahdg.features.gui [
      pkgs.darkly
      pkgs.bibata-cursors
      pkgs.papirus-icon-theme
      pkgs.notepad-next
      pkgs.copyq
      pkgs.songrec
    ];
in
lib.mkIf (packages != [ ]) {
  # Keep static desktop resources in the Nix profile so font availability does
  # not depend on pacman/AUR leftovers.
  home.packages = packages;
}
