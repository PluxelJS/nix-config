{ config, lib, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
  mkAutostart =
    {
      name,
      exec,
      tryExec ? null,
      onlyShowIn ? [ ],
      comment ? null,
      hidden ? false,
    }:
    ''
      [Desktop Entry]
      Type=Application
      Name=${name}
      ${lib.optionalString (comment != null) "Comment=${comment}"}
      Exec=${exec}
      ${lib.optionalString (tryExec != null) "TryExec=${tryExec}"}
      ${lib.optionalString (onlyShowIn != [ ]) "OnlyShowIn=${lib.concatStringsSep ";" onlyShowIn};"}
      ${lib.optionalString hidden "Hidden=true"}
      Terminal=false
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
    '';

in
lib.mkIf config.ahdg.features.gui {
  # Shared XDG application policy: Plasma reads it natively; Mango uses dex.
  # Desktop infrastructure (DMS, CopyQ, portals) remains in session services.
  home.packages = [ pkgs.dex ];

  home.file.".local/bin/ahdg-mango-session-start" = {
    executable = true;
    text = ''
      #!${pkgs.runtimeShell}
      set -eu
      export PATH="${config.home.homeDirectory}/.local/bin:${config.home.homeDirectory}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
      # Import the compositor environment and recover session services before apps.
      "${config.xdg.configHome}/mango/scripts/session-start.sh"
      exec ${pkgs.systemd}/bin/systemd-cat --identifier=mango-autostart \
        ${lib.getExe pkgs.dex} --autostart --environment X-Mango
    '';
  };

  xdg.configFile = {
    # Electron-generated login entries can omit app.asar. Keep the packaged
    # launcher as the sole entry, also shadowing the renamed application's ID.
    "autostart/mihomo-party.desktop" = {
      force = true;
      text = mkAutostart { name = "Mihomo vendor autostart disabled"; exec = "/usr/bin/clash-party"; hidden = true; };
    };
    "autostart/clash-party.desktop" = {
      force = true;
      text = mkAutostart { name = "Clash Party vendor autostart disabled"; exec = "/usr/bin/clash-party"; hidden = true; };
    };

    "autostart/ahdg-copyq.desktop".text = mkAutostart {
      name = "CopyQ (systemd managed)";
      comment = "Started by copyq.service; this entry prevents ad hoc autostart";
      exec = lib.getExe pkgs.copyq;
      tryExec = lib.getExe pkgs.copyq;
      hidden = true;
    };

    "autostart/ahdg-abdm-tray.desktop".text = mkAutostart {
      name = "AB Download Manager Tray";
      exec = "${homeDir}/.local/bin/abdm-tray";
      tryExec = "${homeDir}/.local/bin/abdm-tray";
    };

    # Shadow AB Download Manager's own basename so desktop autostart readers
    # launch only the wrapper above. Two simultaneous JVM launches otherwise
    # race for the same single-instance socket and leave a failed user unit.
    "autostart/com.abdownloadmanager.desktop" = {
      force = true;
      text = ''
        [Desktop Entry]
        Type=Application
        Name=AB Download Manager (vendor autostart disabled)
        Hidden=true
      '';
    };

    # Cachy-Update is the single update notifier for both sessions.
    "autostart/com.shellyorg.shelly-notifications.desktop" = {
      force = true;
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Shelly Notifications (disabled; Cachy-Update is active)
        Hidden=true
      '';
    };

    "autostart/ahdg-mihomo-party.desktop".text = mkAutostart {
      name = "Mihomo Party";
      exec = "/usr/bin/clash-party";
      tryExec = "/usr/bin/clash-party";
    };

    "autostart/ahdg-zen-browser-warmup.desktop".text = mkAutostart {
      name = "Zen Browser Warmup";
      exec = "zen-browser --silent";
      tryExec = "zen-browser";
    };

  };

}
