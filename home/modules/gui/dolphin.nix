{ config, lib, ... }:
let
  themeEnvironmentFile = "${config.xdg.configHome}/ahdg/theme/session.env";
  dolphinLauncher = config.ahdg.kde.runtime.dolphinLauncher;
in
lib.mkIf config.ahdg.features.gui {
  systemd.user.services.plasma-dolphin = {
    Unit = {
      Description = "Dolphin file manager";
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${lib.getExe dolphinLauncher} --daemon";
      BusName = "org.freedesktop.FileManager1";
      Slice = "background.slice";
      EnvironmentFile = themeEnvironmentFile;
      Environment = [
        "XDG_MENU_PREFIX=plasma-"
        "XDG_CONFIG_DIRS=${config.ahdg.kde.runtime.plasmaWorkspace}/etc/xdg:/etc/xdg"
      ];
    };
  };
}
