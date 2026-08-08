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
      default = "docker.io/verdaccio/verdaccio@sha256:5a13d03808135726efde69a5a16fce1e1f724a961d6d647177c22da83c0af5cd";
      description = "Container image used by the Verdaccio quadlet.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4873;
      description = "Host port for the Verdaccio HTTP registry.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host address to bind the Verdaccio HTTP registry port to.";
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
      PublishPort=${cfg.bindAddress}:${toString cfg.port}:4873
      Volume=verdaccio-storage:/verdaccio/storage

      [Service]
      Restart=on-failure
      RestartSec=30

      [Install]
      WantedBy=default.target
    '';
  };
}
