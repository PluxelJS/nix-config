{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.ahdg.features.devRuntime {
    services.devRuntime = {
      enable = true;
      package = pkgs.dev-runtime;
      engine = "podman";
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
