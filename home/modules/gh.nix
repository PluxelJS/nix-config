{ config, lib, pkgs, ... }:
let
  ghConfigText = ''
    git_protocol: ssh
    editor: NotepadNext
    prompt: enabled
  '';
in
{
  home.packages = [
    pkgs.gh
  ];

  home.activation.initializeGhConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    gh_config_dir="${config.xdg.configHome}/gh"
    gh_config="$gh_config_dir/config.yml"

    install -dm700 "$gh_config_dir"
    if [[ -L "$gh_config" || ! -e "$gh_config" ]]; then
      rm -f "$gh_config"
      install -m600 /dev/null "$gh_config"
      printf '%s' ${lib.escapeShellArg ghConfigText} > "$gh_config"
    elif [[ -f "$gh_config" ]]; then
      chmod 600 "$gh_config" 2>/dev/null || true
    fi
  '';

  programs.git.settings.credential = {
    "https://github.com" = {
      helper = "!gh auth git-credential";
    };
    "https://gist.github.com" = {
      helper = "!gh auth git-credential";
    };
  };
}
