{ ... }:
{
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    forceOverwriteSettings = true;
    daemon.enable = true;
    flags = [ "--disable-ai" ];

    settings = {
      auto_sync = false;
      update_check = false;
      search_mode = "daemon-fuzzy";
      filter_mode = "global";
      filter_mode_shell_up_key_binding = "workspace";
      workspaces = true;
      style = "compact";
      inline_height = 20;
      enter_accept = false;
      ctrl_n_shortcuts = true;
    };
  };
}
