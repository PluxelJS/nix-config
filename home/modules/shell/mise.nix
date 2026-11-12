{ config, lib, pkgs, ... }:
let
  python = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  miseEnv = {
    MISE_CONFIG_DIR = "${config.xdg.configHome}/mise";
    MISE_DATA_DIR = "${config.xdg.dataHome}/mise";
    MISE_CACHE_DIR = "${config.xdg.cacheHome}/mise";
    MISE_STATE_DIR = "${config.xdg.stateHome}/mise";
  };
  misePath = ''
    typeset -U path
    path=("${config.home.homeDirectory}/.local/bin" "$MISE_DATA_DIR/shims" $path)
    export PATH
  '';
in {
  home.sessionVariables = miseEnv;
  home.sessionPath = lib.mkBefore [
    "${config.home.homeDirectory}/.local/bin"
    "${miseEnv.MISE_DATA_DIR}/shims"
  ];

  # Non-interactive zsh and IDE probes also need shims, before activate runs.
  programs.zsh.envExtra = ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value:
      "export ${name}=${lib.escapeShellArg value}") miseEnv)}
    ${misePath}
  '';
  # /etc/zprofile can prepend Nix/host paths after .zshenv, including in IDE
  # login probes that inherited the already-sourced HM session-vars marker.
  programs.zsh.profileExtra = misePath;

  # Provision before replacing the profile that used to supply Node/OpenCode.
  # Direct HM switches and setup use the same path. Builds never download tools.
  home.activation.prepareMise = lib.hm.dag.entryBetween [ "linkGeneration" "installPackages" ] [ "writeBoundary" ] ''
    run env ${lib.concatStringsSep " " (lib.mapAttrsToList (name: value:
      "${name}=${lib.escapeShellArg value}") miseEnv)} \
      PATH=${lib.makeBinPath [ pkgs.curl pkgs.coreutils pkgs.gnutar pkgs.gzip pkgs.xz pkgs.bash pkgs.git ]}:"$PATH" \
      ${python}/bin/python3 ${../../../tools/mise-bootstrap.py} ${../../files/mise/config.toml}
  '';
}
