{ config, lib, pkgs, ... }:
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

  home.activation.removeLegacyGitConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    legacy_gitconfig="${config.home.homeDirectory}/.gitconfig"
    if [[ -f "$legacy_gitconfig" ]] && [[ ! -L "$legacy_gitconfig" ]]; then
      rm -f "$legacy_gitconfig"
    fi
  '';

  # Keep XDG as the canonical Git config location, but expose ~/.gitconfig as a
  # compatibility entrypoint for tools that still expect the legacy path.
  home.file.".gitconfig".text = ''
    [user]
    	name = ahdg6
    	email = ${githubNoReplyEmail}

    [include]
    	path = ${config.xdg.configHome}/git/config
  '';

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
