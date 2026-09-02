{ config, lib, pkgs, ... }:
let
  devRuntime = pkgs.callPackage ../../pkgs/dev-runtime.nix { };
in
{
  config = lib.mkMerge [
    (lib.mkIf config.ahdg.features.devRuntime {
      home.packages = [
        devRuntime
        pkgs.podman-compose
        config.services.proxyLlm.package
      ];

      systemd.user.services.dev-runtime = {
        Unit = {
          Description = "Local development Podman runtime";
          Wants = [ "podman.socket" ];
          After = [ "podman.socket" ];
          X-SwitchMethod = "keep-old";
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = "${lib.getExe devRuntime} init";
          ExecStart = "${lib.getExe devRuntime} up";
          ExecStop = "${lib.getExe devRuntime} down";
          TimeoutStartSec = 900;
          TimeoutStopSec = 120;
        };
        Install.WantedBy = [ ];
      };

      home.activation.enableDevRuntime = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
        if command -v systemctl >/dev/null 2>&1; then
          systemctl --user daemon-reload
          systemctl --user enable --now podman.socket
          systemctl --user add-wants default.target dev-runtime.service
          if ! systemctl --user is-active --quiet dev-runtime.service; then
            systemctl --user start --no-block dev-runtime.service
          fi
        else
          echo "dev-runtime requires a systemd user session." >&2
          exit 1
        fi
      '';
    })

    (lib.mkIf (!config.ahdg.features.devRuntime) {
      home.activation.retireDevRuntime = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        unit="$HOME/.config/systemd/user/dev-runtime.service"
        if [ -L "$unit" ]; then
          resolved="$(${lib.getExe' pkgs.coreutils "readlink"} -f "$unit" 2>/dev/null || true)"
          case "$resolved" in
            /nix/store/*)
              if command -v systemctl >/dev/null 2>&1; then
                systemctl --user disable --now dev-runtime.service >/dev/null 2>&1 || true
                systemctl --user reset-failed dev-runtime.service >/dev/null 2>&1 || true
              fi
              ;;
          esac
        fi
      '';
    })
  ];
}
