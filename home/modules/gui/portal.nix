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
        "*"
      ];
    };
  };

  home.sessionVariables = {
    GTK_USE_PORTAL = "1";
  };
}
