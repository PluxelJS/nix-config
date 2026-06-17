{ pkgs, ... }:
{
  # Keep only TUI interaction policy here. Runtime model/provider settings stay
  # in the user's existing ~/.config/opencode/opencode.json.
  home.packages = [ pkgs.opencode ];

  xdg.configFile."opencode/tui.json" = {
    force = true;
    source = ../../files/opencode/tui.json;
  };
}
