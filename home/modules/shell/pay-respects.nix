{ ... }:
{
  programs.pay-respects = {
    enable = true;
    enableZshIntegration = true;

    # Keep the default `f` alias, but declare it explicitly so the choice is
    # visible in the config instead of being hidden in upstream defaults.
    options = [
      "--alias"
      "f"
    ];
  };

  xdg.configFile."pay-respects/config.toml".source = ../../files/pay-respects/config.toml;
}
