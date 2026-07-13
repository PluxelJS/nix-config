{ config, lib, ... }:
{
  imports = [
    ./acode.nix
    ./verdaccio.nix
  ];

  config = lib.mkIf (config.ahdg.profile == "desktop") {
    home.activation.ensurePodmanSocket = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if command -v systemctl >/dev/null 2>&1 && command -v podman >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        systemctl --user enable --now podman.socket >/dev/null 2>&1 || true
      fi
    '';

    xdg.configFile."containers/containers.conf".text = ''
      [engine]
      compose_warning_logs = false
    '';
  };
}
