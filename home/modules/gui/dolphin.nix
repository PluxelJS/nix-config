{ config, lib, ... }:
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
}
