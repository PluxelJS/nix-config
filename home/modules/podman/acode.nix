{ config, lib, ... }:
let
  cfg = config.ahdg.podman.acode;
  serviceName = "acode.service";
in
{
  options.ahdg.podman.acode = {
    enable = lib.mkEnableOption "ACode local compose stack";

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable and start the generated user systemd service during activation.";
    };

    projectDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/ahdg/code/_ACode";
      description = "Directory containing the ACode docker-compose.yaml file.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.ensureAcodeService = lib.hm.dag.entryAfter [ "ensurePodmanSocket" "linkGeneration" ] ''
      if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        ${lib.optionalString cfg.autoStart ''
          if command -v podman >/dev/null 2>&1; then
            systemctl --user enable --now ${serviceName} >/dev/null 2>&1 || true
          fi
        ''}
      fi
    '';

    xdg.configFile."systemd/user/acode.service".text = ''
      [Unit]
      Description=ACode local compose stack
      Wants=podman.socket
      After=podman.socket
      ConditionPathExists=${cfg.projectDir}/docker-compose.yaml

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      WorkingDirectory=${cfg.projectDir}
      Environment=DOCKER_HOST=unix://%t/podman/podman.sock
      ExecStartPre=/usr/bin/env sh -c 'test -S "$XDG_RUNTIME_DIR/podman/podman.sock" || systemctl --user restart podman.socket'
      ExecStart=/usr/bin/env podman compose up -d
      ExecStop=/usr/bin/env podman compose down
      TimeoutStartSec=0
      TimeoutStopSec=60

      [Install]
      WantedBy=default.target
    '';
  };
}
