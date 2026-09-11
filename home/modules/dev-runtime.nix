{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.ahdg.features.devRuntime {
    services.devRuntime = {
      enable = true;
      package = pkgs.dev-runtime;
      engine = "podman";
    };

    home.activation.enableDevRuntime = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      ${pkgs.systemd}/bin/systemctl --user daemon-reload
      ${pkgs.systemd}/bin/systemctl --user enable --now podman.socket
      ${pkgs.systemd}/bin/systemctl --user enable --now dev-runtime.service

      # Seed the upstream workspace once; later service choices belong to the
      # dev-runtime dashboard and must survive Home Manager switches.
      workspace="$HOME/.local/state/dev-runtime"
      if [ ! -e "$workspace/state.db" ]; then
        for service in postgres dragonfly vmetrics vlogs; do
          ${lib.getExe pkgs.dev-runtime} services disable "$service" >/dev/null 2>&1 || true
        done
        ${lib.getExe pkgs.dev-runtime} services enable new-api cliproxy >/dev/null 2>&1 || true
      fi
    '';
  };
}
