{ ... }:
{
  # Keep only TUI interaction policy here. Runtime model/provider settings stay
  # in the user's existing ~/.config/opencode/opencode.json.
  # The executable is installed and updated by the shared mise environment.

  xdg.configFile."opencode/tui.json" = {
    force = true;
    source = ../../files/opencode/tui.json;
  };
}
