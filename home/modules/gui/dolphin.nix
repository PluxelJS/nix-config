{ config, lib, ... }:
let
  themeEnvironmentFile = "${config.xdg.configHome}/ahdg/theme/session.env";
in
lib.mkIf config.ahdg.features.gui {
  # Dolphin has two separate config surfaces:
  # - dolphinrc for stable UI/preferences
  # - kxmlgui user overrides for action shortcuts
  xdg.configFile."dolphinrc" = {
    force = true;
    source = ../../files/dolphin/dolphinrc;
  };

  xdg.dataFile."kxmlgui5/dolphin/dolphinui.rc" = {
    force = true;
    source = ../../files/dolphin/dolphinui.rc;
  };

  systemd.user.services.plasma-dolphin = {
    Unit = {
      Description = "Dolphin file manager";
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "/usr/bin/dolphin --daemon";
      BusName = "org.freedesktop.FileManager1";
      Slice = "background.slice";
      EnvironmentFile = themeEnvironmentFile;
    };
  };
}
