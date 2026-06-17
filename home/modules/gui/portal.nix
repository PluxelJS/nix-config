{ config, lib, pkgs, ... }:
lib.mkIf config.ahdg.features.portal {
  xdg.configFile."xdg-desktop-portal/portals.conf".force = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;

    extraPortals = [
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

      "org.freedesktop.impl.portal.Settings" = [
        "gtk"
        "kde"
        "*"
      ];
    };
  };

  systemd.user.services = {
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
        Restart = "on-failure";
      };
    };
  };

}
