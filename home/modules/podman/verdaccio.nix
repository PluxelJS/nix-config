{ config, lib, ... }:
let
  cfg = config.ahdg.podman.verdaccio;
  serviceName = "verdaccio.service";
in
{
  options.ahdg.podman.verdaccio = {
    enable = lib.mkEnableOption "Verdaccio local npm registry container";

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable and start the generated user quadlet service during activation.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/verdaccio/verdaccio:6";
      description = "Container image used by the Verdaccio quadlet.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4873;
      description = "Host port for the Verdaccio HTTP registry.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.ensureVerdaccioQuadlet = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        ${lib.optionalString cfg.autoStart ''
          if command -v podman >/dev/null 2>&1; then
            systemctl --user enable --now ${serviceName} >/dev/null 2>&1 || true
          fi
        ''}
      fi
    '';

    xdg.configFile."containers/systemd/verdaccio.container".text = ''
      [Unit]
      Description=Verdaccio local npm registry

      [Container]
      Image=${cfg.image}
      ContainerName=verdaccio
      Pull=missing
      PublishPort=127.0.0.1:${toString cfg.port}:4873
      Volume=verdaccio-storage:/verdaccio/storage

      [Service]
      Restart=on-failure
      RestartSec=30

      [Install]
      WantedBy=default.target
    '';
  };
}
