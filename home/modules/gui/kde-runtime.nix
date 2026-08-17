{
  config,
  lib,
  pkgs,
  ...
}:
let
  wrap = config.lib.nixGL.wrap;
  plasmaIntegration = pkgs.kdePackages.plasma-integration;
  kdeThemeRuntime = pkgs.symlinkJoin {
    name = "ahdg-kde-theme-runtime";
    paths = [
      plasmaIntegration
      pkgs.darkly
      pkgs.kdePackages.breeze
    ];
  };
  kdeConfigDirs = "${pkgs.kdePackages.plasma-workspace}/etc/xdg:/etc/xdg";
  kdeQtPluginPath = "${kdeThemeRuntime}/lib/qt-6/plugins";
  kdeDataDirs = "${kdeThemeRuntime}/share";
  kdeEnvironment = ''
    export XDG_MENU_PREFIX=plasma-
    export XDG_CONFIG_DIRS=${lib.escapeShellArg kdeConfigDirs}
    export XDG_DATA_DIRS=${lib.escapeShellArg kdeDataDirs}:''${XDG_DATA_DIRS:-${config.home.profileDirectory}/share:/usr/local/share:/usr/share}
    export QT_PLUGIN_PATH=${lib.escapeShellArg kdeQtPluginPath}
    export QT_QPA_PLATFORMTHEME=kde
    export QT_QPA_PLATFORMTHEME_QT6=kde
  '';
  mkNixGLLauncher =
    name: executable:
    wrap (
      pkgs.writeShellScriptBin name ''
        ${kdeEnvironment}
        exec ${executable} "$@"
      ''
    );
  mkKdeLauncher =
    name: executable:
    pkgs.writeShellScriptBin name ''
      ${kdeEnvironment}
      exec ${executable} "$@"
    '';

  # Ark uses Kerfuffle plugins for the UI, but several writable/encrypted
  # formats are implemented by command-line helpers discovered through PATH.
  # Keep those helpers in the same Nix-owned runtime as Ark so opening an
  # archive from Dolphin never falls back to whichever tools CachyOS happens
  # to have installed.
  archiveBackends = [
    pkgs.p7zip
    pkgs.unrar
    pkgs.unar
    pkgs.zip
    pkgs.unzip
  ];

  dolphin = wrap pkgs.kdePackages.dolphin;
  ark = wrap pkgs.kdePackages.ark;
  kate = wrap pkgs.kdePackages.kate;
  kded = wrap pkgs.kdePackages.kded;
  kdeCliTools = wrap pkgs.kdePackages.kde-cli-tools;
  plasmaWorkspace = wrap pkgs.kdePackages.plasma-workspace;
  kwallet = wrap pkgs.kdePackages.kwallet;
  kwalletmanager = wrap pkgs.kdePackages.kwalletmanager;
  dolphinLauncher = mkKdeLauncher "dolphin" (lib.getExe' dolphin "dolphin");
  arkLauncher = pkgs.writeShellScriptBin "ark" ''
    ${kdeEnvironment}
    export PATH=${lib.escapeShellArg (lib.makeBinPath archiveBackends)}:''${PATH:-/usr/local/bin:/usr/bin}
    exec ${lib.getExe' ark "ark"} "$@"
  '';
  kateLauncher = mkKdeLauncher "kate" (lib.getExe' kate "kate");
  kdedLauncher = mkKdeLauncher "kded6" (lib.getExe' kded "kded6");

  mkPinnedDesktopEntry =
    name: source: oldExec: newExec:
    pkgs.runCommand name { } ''
      substitute ${source} "$out" \
        --replace-fail ${lib.escapeShellArg oldExec} ${lib.escapeShellArg newExec}
    '';
  dolphinDesktopEntry =
    mkPinnedDesktopEntry "org.kde.dolphin.desktop"
      "${dolphin}/share/applications/org.kde.dolphin.desktop"
      "Exec=dolphin %u"
      "Exec=${lib.getExe dolphinLauncher} %u";
  arkDesktopEntry =
    mkPinnedDesktopEntry "org.kde.ark.desktop" "${ark}/share/applications/org.kde.ark.desktop"
      "Exec=ark %U"
      "Exec=${lib.getExe arkLauncher} %U";
  kateDesktopEntry =
    mkPinnedDesktopEntry "org.kde.kate.desktop" "${kate}/share/applications/org.kde.kate.desktop"
      "Exec=kate"
      "Exec=${lib.getExe kateLauncher}";
  kdedDbusService =
    mkPinnedDesktopEntry "org.kde.kded6.service"
      "${pkgs.kdePackages.kded}/share/dbus-1/services/org.kde.kded6.service"
      "Exec=${pkgs.kdePackages.kded}/bin/kded6"
      "Exec=${lib.getExe kdedLauncher}";

  portalKde = pkgs.kdePackages.xdg-desktop-portal-kde;
  portalKdeLauncher = mkNixGLLauncher "xdg-desktop-portal-kde" "${portalKde}/libexec/xdg-desktop-portal-kde";
  polkitAgent = pkgs.kdePackages.polkit-kde-agent-1;
  polkitAgentLauncher = mkNixGLLauncher "polkit-kde-authentication-agent-1" "${polkitAgent}/libexec/polkit-kde-authentication-agent-1";
in
{
  options.ahdg.kde.runtime = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    readOnly = true;
    internal = true;
    description = "Resolved Nix-owned KDE user-runtime packages and launchers.";
  };

  config = lib.mkIf config.ahdg.features.gui {
    # Keep the hardware/session ABI boundary on CachyOS, but make every KDE
    # component launched by this Home Manager profile come from one Nixpkgs
    # closure. nixGL only bridges host GL/EGL drivers; it does not lock or
    # generate any KDE UI configuration.
    ahdg.kde.runtime = {
      inherit
        ark
        arkLauncher
        kate
        kateLauncher
        dolphin
        dolphinLauncher
        kded
        kdedLauncher
        kdeCliTools
        kwallet
        plasmaWorkspace
        portalKde
        portalKdeLauncher
        polkitAgentLauncher
        ;
      portal = pkgs.xdg-desktop-portal;
      portalGtk = pkgs.xdg-desktop-portal-gtk;
      portalWlr = pkgs.xdg-desktop-portal-wlr;
    };

    home.packages = [
      dolphin
      (lib.hiPrio dolphinLauncher)
      ark
      (lib.hiPrio arkLauncher)
      kate
      (lib.hiPrio kateLauncher)
      kded
      kdeCliTools
      plasmaWorkspace
      kwalletmanager
      pkgs.darkly
      pkgs.kdePackages.breeze
      plasmaIntegration
      pkgs.kdePackages.kio-extras
      pkgs.kdePackages.kio-fuse
      pkgs.kdePackages.kservice
    ] ++ archiveBackends;

    # The profile copy has precedence even when CachyOS keeps equivalent KDE
    # packages installed for recovery or system-wide integrations.
    xdg.dataFile = {
      "applications/org.kde.dolphin.desktop" = {
        force = true;
        source = dolphinDesktopEntry;
      };
      "applications/org.kde.ark.desktop" = {
        force = true;
        source = arkDesktopEntry;
      };
      "applications/org.kde.kate.desktop" = {
        force = true;
        source = kateDesktopEntry;
      };
      "dbus-1/services/org.kde.kded6.service" = {
        force = true;
        source = kdedDbusService;
      };
    };

    # KService looks for the menu under XDG_CONFIG_HOME before the system
    # directories. Pinning the Nix menu here prevents an Arch/Nix menu-prefix
    # mismatch from making every Dolphin file association appear unusable.
    xdg.configFile."menus/plasma-applications.menu" = {
      force = true;
      source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
    };

    dbus.packages = [
      pkgs.kdePackages.dolphin
      pkgs.kdePackages.kwallet
      pkgs.kdePackages.plasma-workspace
      portalKde
      polkitAgent
    ];

    home.sessionVariables = {
      XDG_MENU_PREFIX = "plasma-";
      XDG_CONFIG_DIRS = kdeConfigDirs;
      QT_QPA_PLATFORMTHEME_QT6 = "kde";
    };
    systemd.user.sessionVariables = {
      XDG_MENU_PREFIX = "plasma-";
      XDG_CONFIG_DIRS = kdeConfigDirs;
      QT_QPA_PLATFORMTHEME_QT6 = "kde";
    };

    home.activation.refreshKdeServiceCache = lib.hm.dag.entryAfter [ "updateMimeDatabase" ] ''
      XDG_MENU_PREFIX=plasma- \
        XDG_CONFIG_DIRS=${lib.escapeShellArg kdeConfigDirs} \
        ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental
    '';

    # The host DBus service may launch /usr/bin/kded6 before the Nix unit.
    # Stop only that exact executable; never terminate a correct Nix process.
    home.activation.retireHostKded = lib.hm.dag.entryBefore [ "reloadSystemd" ] ''
      for pid in $(${pkgs.procps}/bin/pgrep -x kded6 2>/dev/null || true); do
        if [[ "$(${pkgs.coreutils}/bin/readlink -f "/proc/$pid/exe" 2>/dev/null || true)" == /usr/bin/kded6 ]]; then
          kill "$pid" 2>/dev/null || true
        fi
      done
    '';

    home.activation.ensureNixKded = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      ${pkgs.systemd}/bin/systemctl --user start plasma-kded6.service 2>/dev/null || true
    '';

    systemd.user.services.plasma-kded6 = {
      Unit = {
        Description = "KDE Daemon 6 (Nix runtime)";
        After = [ "graphical-session.target" ];
        PartOf = [ "mango-session.target" ];
      };
      Service = {
        Type = "dbus";
        ExecStart = lib.getExe kdedLauncher;
        BusName = "org.kde.kded6";
        Slice = "session.slice";
        TimeoutStopSec = 5;
        Restart = "on-failure";
        Environment = [
          "XDG_MENU_PREFIX=plasma-"
          "XDG_CONFIG_DIRS=${kdeConfigDirs}"
        ];
      };
      Install.WantedBy = [ "mango-session.target" ];
    };

    systemd.user.services.plasma-polkit-agent = {
      Unit = {
        Description = "KDE PolicyKit authentication agent (Nix runtime)";
        After = [ "graphical-session.target" ];
        PartOf = [ "mango-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe polkitAgentLauncher;
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "mango-session.target" ];
    };
  };
}
