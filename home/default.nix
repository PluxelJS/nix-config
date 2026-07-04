{ lib, ... }:
{
  home.username = lib.mkDefault "ahdg";
  home.homeDirectory = lib.mkDefault "/home/ahdg";

  # Change this only after reading the Home Manager release notes.
  home.stateVersion = "24.11";

  imports = [
    ./modules/profile.nix
    ./modules/gui
    ./modules/xdg.nix
    ./modules/gh.nix
    ./modules/git.nix
    ./modules/shell
    ./modules/podman
    ./modules/themes.nix
    ./modules/starship.nix
    ./modules/ghostty.nix
    ./modules/fastfetch.nix
  ];

  programs.home-manager.enable = true;
}
