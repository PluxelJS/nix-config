{ config, lib, ... }:
{
  config = lib.mkIf (config.ahdg.profile == "desktop") {
    xdg.configFile."containers/containers.conf".text = ''
      [engine]
      compose_warning_logs = false
    '';
  };
}
