{ config, lib, ... }:
let
  cfg = config.ahdg.podman.casdoor;
  serviceName = "casdoor.service";
in
{
  options.ahdg.podman.casdoor = {
    enable = lib.mkEnableOption "Casdoor local development OIDC provider";

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable and start the generated user quadlet service during activation.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/casbin/casdoor:latest";
      description = "Container image used by the Casdoor quadlet.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Host port for the Casdoor web UI and OIDC provider.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host address to bind the Casdoor port to.";
    };

    origin = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:${toString cfg.port}";
      description = "Canonical Casdoor origin used in OIDC discovery URLs.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/ahdg/casdoor";
      description = "Host directory used for Casdoor SQLite data.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.ensureCasdoorRuntime = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      mkdir -p ${lib.escapeShellArg cfg.stateDir}
      chmod 700 ${lib.escapeShellArg cfg.stateDir} 2>/dev/null || true
    '';

    home.activation.ensureCasdoorQuadlet = lib.hm.dag.entryAfter [
      "ensurePodmanSocket"
      "ensureCasdoorRuntime"
      "linkGeneration"
    ] ''
      if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        ${lib.optionalString cfg.autoStart ''
          if command -v podman >/dev/null 2>&1; then
            systemctl --user enable --now ${serviceName} >/dev/null 2>&1 || true
          fi
        ''}
      fi
    '';

    xdg.configFile."containers/systemd/casdoor.container".text = ''
      [Unit]
      Description=Casdoor local development OIDC provider
      Wants=podman.socket
      After=podman.socket

      [Container]
      Image=${cfg.image}
      ContainerName=casdoor
      Pull=missing
      UserNS=keep-id
      PublishPort=${cfg.bindAddress}:${toString cfg.port}:${toString cfg.port}
      Volume=${cfg.stateDir}:/data:Z
      Environment=appname=casdoor
      Environment=httpport=${toString cfg.port}
      Environment=runmode=prod
      Environment=driverName=sqlite
      Environment=dataSourceName=file:/data/casdoor.db?cache=shared
      Environment=dbName=casdoor
      Environment=origin=${cfg.origin}
      Environment=originFrontend=${cfg.origin}
      Environment=staticBaseUrl=
      Environment=showGithubCorner=false
      Environment=enableGzip=true
      Environment=logPostOnly=false

      [Service]
      Restart=on-failure
      RestartSec=30

      [Install]
      WantedBy=default.target
    '';
  };
}
