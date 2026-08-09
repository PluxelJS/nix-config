{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.ahdg.profile == "desktop") {
    # Retire only the old Nix-owned Quadlet during migration. A later local
    # regular file with the same name remains entirely user-managed.
    home.activation.retireNixVerdaccio = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      quadlet="$HOME/.config/containers/systemd/verdaccio.container"
      if [ -L "$quadlet" ]; then
        resolved="$(${lib.getExe' pkgs.coreutils "readlink"} -f "$quadlet" 2>/dev/null || true)"
        case "$resolved" in
          /nix/store/*)
            if command -v systemctl >/dev/null 2>&1; then
              systemctl --user disable --now verdaccio.service >/dev/null 2>&1 || true
              systemctl --user reset-failed verdaccio.service >/dev/null 2>&1 || true
            fi
            ;;
        esac
      fi
    '';

    xdg.configFile."containers/containers.conf".text = ''
      [engine]
      compose_warning_logs = false
    '';
  };
}
