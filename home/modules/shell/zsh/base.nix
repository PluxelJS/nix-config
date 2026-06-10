{ config, lib, ... }:
{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    autocd = true;
    defaultKeymap = "emacs";
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases =
      {
        ".." = "cd ..";
        "..." = "cd ../..";
        fix = "f";
        gst = "git status -sb";
        gl = "git log --oneline --decorate --graph -20";
      }
      // lib.optionalAttrs config.ahdg.features.fastfetch {
        ff = "fastfetch";
      };

    history = {
      path = "${config.xdg.stateHome}/zsh/history";
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };
  };
}
