{ config, lib, pkgs, ... }:
let
  ghEditor = "kate -b";
  ghConfigText = ''
    git_protocol: https
    editor: ${ghEditor}
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

    if [[ -f "$gh_config" ]]; then
      if grep -q '^editor:' "$gh_config"; then
        sed -i ${lib.escapeShellArg "s|^editor:.*|editor: ${ghEditor}|"} "$gh_config"
      else
        printf '\neditor: %s\n' ${lib.escapeShellArg ghEditor} >> "$gh_config"
      fi
    fi

    # gh owns its API login; Git HTTPS authentication uses git-credential-oauth.
    # Set both the default and GitHub's per-host preference for new gh clones.
    GH_CONFIG_DIR="$gh_config_dir" ${pkgs.gh}/bin/gh config set git_protocol https
    GH_CONFIG_DIR="$gh_config_dir" ${pkgs.gh}/bin/gh config set git_protocol https --host github.com
  '';
}
