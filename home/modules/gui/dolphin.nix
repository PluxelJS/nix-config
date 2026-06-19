{ config, lib, ... }:
let
  themeEnvironmentFile = "${config.xdg.configHome}/ahdg/theme/session.env";
in
lib.mkIf config.ahdg.features.gui {
  # Dolphin has two separate config surfaces:
  # - dolphinrc for stable UI/preferences
  # - kxmlgui user overrides for action shortcuts
  home.activation.initializeDolphinDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    seed_file() {
      local source_path=$1
      local target_path=$2

      if [[ -L "$target_path" ]]; then
        rm -f "$target_path"
      fi

      if [[ ! -e "$target_path" ]]; then
        install -Dm644 "$source_path" "$target_path"
      fi
    }

    seed_file "${../../files/dolphin/dolphinrc}" "${config.xdg.configHome}/dolphinrc"
    seed_file "${../../files/dolphin/dolphinui.rc}" "${config.xdg.dataHome}/kxmlgui5/dolphin/dolphinui.rc"
  '';

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
