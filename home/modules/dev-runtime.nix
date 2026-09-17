{ config, lib, pkgs, ... }:
let
  cfg = config.services.devRuntime;
  initialize = pkgs.writeShellScript "dev-runtime-initialize" ''
    exec ${lib.getExe cfg.package} --state-dir ${lib.escapeShellArg cfg.stateDir} \
      init --engine ${lib.escapeShellArg cfg.engine} \
      ${lib.optionalString (cfg.endpoint != "") "--endpoint ${lib.escapeShellArg cfg.endpoint}"}
  '';
  waitForNetwork = pkgs.writeShellScript "dev-runtime-wait-for-network" ''
    set -eu
    # User units cannot order themselves after the system's network-online.target.
    # Wait for connectivity, not merely NetworkManager's completed startup.
    ${pkgs.networkmanager}/bin/nm-online --quiet --timeout=60
    # NM can report connected with IPv6 alone. Our Podman bridge needs IPv4;
    # without a default route pasta can initialise from an unrelated veth.
    for attempt in {1..30}; do
      if ${pkgs.iproute2}/bin/ip -4 route show default | ${pkgs.gnugrep}/bin/grep -q '^default '; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    echo "dev-runtime: waiting for an IPv4 default route timed out" >&2
    exit 1
  '';
in
{
  config = lib.mkIf config.ahdg.features.devRuntime {
    services.devRuntime = {
      enable = true;
      package = pkgs.dev-runtime;
      engine = "podman";
    };

    systemd.user.services.dev-runtime.Service = {
      # Upstream defines a scalar ExecStartPre, which cannot merge with a list.
      # Preserve its configurable initialization after the network gate.
      ExecStartPre = lib.mkForce [ "${waitForNetwork}" "${initialize}" ];
      TimeoutStartSec = 120;
      # A boot without connectivity must recover when the network comes up.
      Restart = "on-failure";
    };

    home.activation.seedDevRuntime = lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ] ''
      # Seed the upstream workspace once; later service choices belong to the
      # dev-runtime dashboard and must survive Home Manager switches.
      workspace="$HOME/.local/state/dev-runtime"
      if [ ! -e "$workspace/state.db" ]; then
        ${lib.getExe pkgs.dev-runtime} init --engine podman
        ${lib.getExe pkgs.dev-runtime} config export --reveal |
          ${pkgs.python3}/bin/python3 -c '
      import json, sys
      bundle = json.load(sys.stdin)
      for service in bundle["services"]:
          service["enabled"] = service["id"] in ("new-api", "cliproxy")
      json.dump(bundle, sys.stdout)
      ' | ${lib.getExe pkgs.dev-runtime} config save -
      fi
    '';

    home.activation.enableDevRuntime = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      ${pkgs.systemd}/bin/systemctl --user daemon-reload
      ${pkgs.systemd}/bin/systemctl --user enable --now podman.socket
      ${pkgs.systemd}/bin/systemctl --user enable --now dev-runtime.service
    '';
  };
}
