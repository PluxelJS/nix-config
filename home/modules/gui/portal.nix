{
  config,
  lib,
  pkgs,
  ...
}:
let
  autoSwitchEnabled = config.ahdg.theme.autoSwitch.enable;
  themeEnvironmentFile = "${config.xdg.configHome}/ahdg/theme/session.env";
  kde = config.ahdg.kde.runtime;
in
lib.mkIf config.ahdg.features.portal {
  xdg.configFile."xdg-desktop-portal/portals.conf".force = true;

  home.activation.syncGraphicalSessionEnvironment = lib.hm.dag.entryBefore [ "reloadSystemd" ] ''
    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
      if [[ -n "''${WAYLAND_DISPLAY:-}" && -S "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$WAYLAND_DISPLAY" ]]; then
        # Never import a stale host/session menu prefix (historically `arch-`)
        # over the Nix KDE runtime selected by this generation.
        export XDG_MENU_PREFIX=plasma-
        export XDG_CONFIG_DIRS=${lib.escapeShellArg "${kde.plasmaWorkspace}/etc/xdg:/etc/xdg"}
        dbus-update-activation-environment --systemd \
          WAYLAND_DISPLAY \
          DISPLAY \
          XDG_RUNTIME_DIR \
          XDG_SESSION_TYPE \
          XDG_CURRENT_DESKTOP \
          DESKTOP_SESSION \
          XDG_MENU_PREFIX \
          XDG_CONFIG_DIRS \
          QT_QPA_PLATFORM \
          QT_QPA_PLATFORMTHEME \
          KDE_SESSION_VERSION \
          KDE_FULL_SESSION \
          NIX_XDG_DESKTOP_PORTAL_DIR
      fi
    fi
  '';

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;

    extraPortals = lib.optional autoSwitchEnabled pkgs.darkman ++ [
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

      # GTK's folder chooser keeps Ctrl+L path entry usable; KDE's portal
      # directory picker currently hides that basic workflow.
      "org.freedesktop.impl.portal.FileChooser" = [
        "gtk"
        "kde"
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

      "org.freedesktop.impl.portal.Settings" = lib.optionals autoSwitchEnabled [ "darkman" ] ++ [
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
        ExecStart = lib.getExe' kde.kwallet "kwalletd6";
        BusName = "org.kde.kwalletd6";
        Slice = "session.slice";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    xdg-desktop-portal = {
      Unit = {
        Description = "Portal service (Nix runtime)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "dbus";
        ExecStart = "${kde.portal}/libexec/xdg-desktop-portal";
        BusName = "org.freedesktop.portal.Desktop";
        Slice = "session.slice";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };

    xdg-document-portal = {
      Unit.Description = "Document portal service (Nix runtime)";
      Service = {
        Type = "dbus";
        ExecStart = "${kde.portal}/libexec/xdg-document-portal";
        BusName = "org.freedesktop.portal.Documents";
        Slice = "session.slice";
        Restart = "on-failure";
      };
    };

    xdg-permission-store = {
      Unit.Description = "Portal permission store (Nix runtime)";
      Service = {
        Type = "dbus";
        ExecStart = "${kde.portal}/libexec/xdg-permission-store";
        BusName = "org.freedesktop.impl.portal.PermissionStore";
        Slice = "session.slice";
        Restart = "on-failure";
      };
    };

    plasma-xdg-desktop-portal-kde = {
      Unit = {
        Description = "Xdg Desktop Portal For KDE";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "dbus";
        ExecStart = lib.getExe kde.portalKdeLauncher;
        BusName = "org.freedesktop.impl.portal.desktop.kde";
        Slice = "session.slice";
        EnvironmentFile = themeEnvironmentFile;
        Environment = [
          "XDG_MENU_PREFIX=plasma-"
          "XDG_CONFIG_DIRS=${kde.plasmaWorkspace}/etc/xdg:/etc/xdg"
        ];
        Restart = "on-failure";
        RestartSec = 1;
      };
    };

    xdg-desktop-portal-gtk = {
      Unit = {
        Description = "GTK portal backend (Nix runtime)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "dbus";
        BusName = "org.freedesktop.impl.portal.desktop.gtk";
        ExecStart = "${kde.portalGtk}/libexec/xdg-desktop-portal-gtk";
        EnvironmentFile = themeEnvironmentFile;
        Restart = "on-failure";
        RestartSec = 1;
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
        ExecStart = "${kde.portalWlr}/libexec/xdg-desktop-portal-wlr";
        EnvironmentFile = themeEnvironmentFile;
        Restart = "on-failure";
      };
    };
  };

}
