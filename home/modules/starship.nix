{ config, lib, ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = false;
  };

  home.sessionVariables.STARSHIP_CONFIG = lib.mkForce "${config.xdg.configHome}/starship/starship.toml";

  xdg.configFile."starship/starship.toml".source = ../files/starship/starship.toml;
}
