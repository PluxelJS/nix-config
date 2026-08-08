{ ... }:
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = false;

    defaultCommand = "fd --type f --hidden --strip-cwd-prefix --exclude .git";
    changeDirWidget.command = "fd --type d --hidden --strip-cwd-prefix --exclude .git";
    fileWidget.command = "fd --type f --hidden --strip-cwd-prefix --exclude .git";

    defaultOptions = [
      "--height=80%"
      "--layout=reverse"
      "--border"
      "--cycle"
    ];
  };
}
