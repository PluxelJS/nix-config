{ config, pkgs, ... }:
let
  githubNoReplyEmail = "36436808+ahdg6@users.noreply.github.com";
in
{
  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Macchiato";
      style = "plain";
      paging = "never";
    };
  };

  # Keep XDG as the canonical Git config location, but expose ~/.gitconfig as a
  # compatibility entrypoint for tools and Flatpak IDEs that expect this path.
  home.file.".gitconfig" = {
    force = true;
    text = ''
      [user]
        name = ahdg6
        email = ${githubNoReplyEmail}

      [include]
        path = ${config.xdg.configHome}/git/config
    '';
  };

  home.packages = [
    pkgs.git
  ];

  programs.git = {
    enable = true;
    signing.format = "openpgp";

    settings = {
      user = {
        name = "ahdg6";
        email = githubNoReplyEmail;
      };

      init.defaultBranch = "main";
      pull.rebase = false;
      push.autoSetupRemote = true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "Catppuccin Macchiato";
      navigate = true;
      side-by-side = true;
    };
  };
}
