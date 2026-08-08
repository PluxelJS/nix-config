{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Macchiato";
      style = "plain";
      paging = "never";
    };
  };

  # Home Manager owns generic Git behavior under XDG_CONFIG_HOME. Author
  # identity stays in the writable, machine-local ~/.gitconfig so a shared
  # checkout never assigns the repository owner's identity to another user.
  home.activation.ensureLocalGitConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    target="${config.home.homeDirectory}/.gitconfig"
    managed_config="${config.xdg.configHome}/git/config"

    if [[ ! -e "$target" && ! -L "$target" ]]; then
      install -m600 /dev/null "$target"
    fi

    if [[ -f "$target" && ! -L "$target" ]]; then
      chmod u+rw "$target"
      if ! ${pkgs.git}/bin/git config --file "$target" --get-all include.path \
        | ${pkgs.gnugrep}/bin/grep -Fqx "$managed_config"; then
        ${pkgs.git}/bin/git config --file "$target" --add include.path "$managed_config"
      fi
    fi
  '';

  home.packages = [
    pkgs.git
  ];

  programs.git = {
    enable = true;
    signing.format = "openpgp";

    settings = {
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
