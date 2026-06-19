{ config, lib, pkgs, ... }:
let
  autoSwitchEnabled = config.ahdg.theme.autoSwitch.enable;
  themeEnvironmentFile = "${config.xdg.configHome}/ahdg/theme/session.env";
in
lib.mkIf config.ahdg.features.portal {
  xdg.configFile."xdg-desktop-portal/portals.conf".force = true;
  dbus.packages = [ pkgs.kdePackages.kwallet ];

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;

    extraPortals =
      lib.optional autoSwitchEnabled pkgs.darkman
      ++ [
        pkgs.kdePackages.kwallet
        pkgs.kdePackages.xdg-desktop-portal-kde
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-wlr
      ];

    config.common = {
      default = [
        "kde"
        "gtk"
        "*"
      ];

      "org.freedesktop.impl.portal.FileChooser" = [
        "kde"
        "gtk"
        "*"
      ];

      "org.freedesktop.impl.portal.ScreenCast" = [
        "wlr"
        "*"
      ];

      "org.freedesktop.impl.portal.RemoteDesktop" = [
        "wlr"
        "*"
      ];

      "org.freedesktop.impl.portal.Screenshot" = [
        "wlr"
        "gtk"
        "*"
      ];

      "org.freedesktop.impl.portal.Settings" =
        lib.optionals autoSwitchEnabled [ "darkman" ]
        ++ [
          "gtk"
          "kde"
          "*"
        ];

      "org.freedesktop.impl.portal.Secret" = [
        "kwallet"
        "*"
      ];
    };
  };

  systemd.user.services = {
    kwalletd6 = {
      Unit = {
        Description = "KDE Wallet Daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "dbus";
        ExecStart = "${pkgs.kdePackages.kwallet}/bin/kwalletd6";
        BusName = "org.kde.kwalletd6";
        Slice = "session.slice";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    plasma-xdg-desktop-portal-kde = {
      Unit = {
        Description = "Xdg Desktop Portal For KDE";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "dbus";
        ExecStart = "${pkgs.kdePackages.xdg-desktop-portal-kde}/libexec/xdg-desktop-portal-kde";
        BusName = "org.freedesktop.impl.portal.desktop.kde";
        Slice = "session.slice";
        EnvironmentFile = themeEnvironmentFile;
        Restart = "no";
      };
    };

    xdg-desktop-portal-wlr = {
      Unit = {
        Description = "Portal service (wlroots implementation)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        ConditionEnvironment = [ "WAYLAND_DISPLAY" ];
      };
      Service = {
        Type = "dbus";
        BusName = "org.freedesktop.impl.portal.desktop.wlr";
        ExecStart = "${pkgs.xdg-desktop-portal-wlr}/libexec/xdg-desktop-portal-wlr";
        EnvironmentFile = themeEnvironmentFile;
        Restart = "on-failure";
      };
    };
  };

}
