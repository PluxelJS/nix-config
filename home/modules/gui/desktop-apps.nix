{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  copyqKdeRuntime = pkgs.symlinkJoin {
    name = "copyq-kde-theme-runtime";
    paths = [
      pkgs.darkly
      pkgs.kdePackages.breeze
      pkgs.kdePackages.plasma-integration
    ];
  };
  copyqPolicy = {
    autostart = "false";
    check_clipboard = "true";
    check_selection = "false";
    clipboard_notification_lines = "0";
    expire_tab = "0";
    maxitems = "20000";
    save_on_app_deactivated = "true";
  };
  copyqPolicyCommands = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: value: "upsert_copyq_option ${lib.escapeShellArg name} ${lib.escapeShellArg value}"
    ) copyqPolicy
  );
  copyqRuntimeCommands = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: value: "      timeout 2s ${lib.getExe pkgs.copyq} config ${lib.escapeShellArg name} ${lib.escapeShellArg value} >/dev/null 2>&1 || true"
    ) copyqPolicy
  );

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

  disableDmsClipboard = pkgs.writeShellScript "ahdg-disable-dms-clipboard" ''
    # The backend socket can appear shortly after the shell starts. Repeat the
    # command because DMS persists clipboard tracking state in its own database.
    for _ in $(${pkgs.coreutils}/bin/seq 1 50); do
      if ${lib.getExe pkgs.dms} clipboard config set --disable >/dev/null 2>&1; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 0.2
    done
  '';

  dmsAutostart = pkgs.writeShellScript "ahdg-mango-dms-autostart" ''
    exec ${lib.getExe pkgs.dms} run
  '';
in
lib.mkIf config.ahdg.features.gui {
  # Plasma consumes XDG autostart entries itself. Minimal compositors such as
  # Mango use dex as the session-side reader, so ordinary GUI applications keep
  # sharing the same declarative files. CopyQ and DMS are session services
  # instead: they must survive Home Manager switches and be restartable.
  home.packages = [
    pkgs.dex

    # Both applications use GPU-backed native rendering. On CachyOS they need
    # the same host GL bridge as Ghostty and LocalSend.
    (config.lib.nixGL.wrap pkgs.meatshell)
  ];

  programs.zed-editor = {
    enable = true;
    package = config.lib.nixGL.wrap pkgs.zed-editor;
  };

  xdg.configFile = {
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

    # Cachy-Update is the single update notifier. Shelly 3 can still discover
    # and launch its 2.x notification helper from stale per-user state, which
    # then reports missing legacy settings such as TitleBarDirection at login.
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
      exec = "mihomo-party";
      tryExec = "mihomo-party";
    };

    "autostart/ahdg-zen-browser-warmup.desktop".text = mkAutostart {
      name = "Zen Browser Warmup";
      exec = "zen-browser --silent";
      tryExec = "zen-browser";
    };

  };

  systemd.user.services.ahdg-mango-dms = {
    Unit = {
      Description = "Dank Material Shell";
      After = [ "graphical-session.target" ];
      PartOf = [ "mango-session.target" ];
    };
    Service = {
      ExecStart = dmsAutostart;
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "session.slice";
    };
    Install.WantedBy = [ "mango-session.target" ];
  };

  systemd.user.services.ahdg-disable-dms-clipboard = {
    Unit = {
      Description = "Disable DMS clipboard tracking";
      Requires = [ "ahdg-mango-dms.service" ];
      After = [ "ahdg-mango-dms.service" ];
      PartOf = [ "mango-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = disableDmsClipboard;
      RemainAfterExit = true;
    };
    Install.WantedBy = [ "mango-session.target" ];
  };

  services.copyq = {
    enable = true;
    package = pkgs.copyq;
    systemdTarget = "mango-session.target";
    forceXWayland = false;
  };

  systemd.user.services.copyq.Service = {
    Environment = [
      "QT_QPA_PLATFORM=wayland"
      "QT_QPA_PLATFORMTHEME=kde"
      "QT_QPA_PLATFORMTHEME_QT6=kde"
      "QT_PLUGIN_PATH=${copyqKdeRuntime}/lib/qt-6/plugins"
    ];
    Restart = lib.mkForce "always";
    RestartSec = 2;
  };

  home.activation.ensureDmsService = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    if ${pkgs.systemd}/bin/systemctl --user --quiet is-active mango-session.target; then
      ${pkgs.systemd}/bin/systemctl --user start ahdg-mango-dms.service 2>/dev/null || true
    fi
  '';

  home.activation.disableDmsClipboard = lib.hm.dag.entryAfter [ "ensureDmsService" ] ''
    if ${pkgs.systemd}/bin/systemctl --user --quiet is-active mango-session.target; then
      ${pkgs.systemd}/bin/systemctl --user restart ahdg-disable-dms-clipboard.service 2>/dev/null || true
    fi
  '';

  home.activation.hideDmsClipboardWidget = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    dms_settings="${config.xdg.configHome}/DankMaterialShell/settings.json"
    if [[ -f "$dms_settings" ]]; then
      tmp="$(mktemp)"
      if ${pkgs.jq}/bin/jq '.showClipboard = false' "$dms_settings" > "$tmp"; then
        chmod --reference="$dms_settings" "$tmp"
        mv "$tmp" "$dms_settings"
      else
        rm -f "$tmp"
      fi
    fi
  '';

  home.activation.ensureCopyqService = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    if ${pkgs.systemd}/bin/systemctl --user --quiet is-active mango-session.target; then
      ${pkgs.systemd}/bin/systemctl --user start copyq.service 2>/dev/null || true
    fi
  '';

  home.activation.configureCopyqPolicy = lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "linkGeneration" ] ''
    # Stop the server before editing its QSettings file, otherwise it can
    # write the stale Fusion override back while the generation is switching.
    ${pkgs.systemd}/bin/systemctl --user stop copyq.service 2>/dev/null || true

    copyq_config="${config.xdg.configHome}/copyq/copyq.conf"
    install -dm755 "$(dirname "$copyq_config")"
    if [[ ! -e "$copyq_config" ]]; then
      printf '[Options]\n' > "$copyq_config"
    fi

    upsert_copyq_option() {
      local key=$1
      local value=$2
      local tmp

      tmp="$(mktemp)"
      awk -v key="$key" -v value="$value" '
        /^\[Options\]$/ {
          seen_options = 1
          in_options = 1
          print
          next
        }

        /^\[/ {
          if (in_options && !done) {
            print key "=" value
            done = 1
          }
          in_options = 0
        }

        in_options && index($0, key "=") == 1 {
          if (!done) {
            print key "=" value
            done = 1
          }
          next
        }

        { print }

        END {
          if (!seen_options) {
            print "[Options]"
          }
          if (!done) {
            print key "=" value
          }
        }
      ' "$copyq_config" > "$tmp"
      mv "$tmp" "$copyq_config"
    }

    remove_copyq_option() {
      local key=$1
      local tmp

      tmp="$(mktemp)"
      awk -v key="$key" '
        /^\[Options\]$/ { in_options = 1; print; next }
        /^\[/ { in_options = 0 }
        in_options && index($0, key "=") == 1 { next }
        { print }
      ' "$copyq_config" > "$tmp"
      mv "$tmp" "$copyq_config"
    }

    # CopyQ previously forced Fusion, which bypassed kdeglobals and made the
    # window light. With no app-specific style it follows KDE/Darkly normally.
    remove_copyq_option style

    ${copyqPolicyCommands}
  '';

  home.activation.applyCopyqRuntimePolicy = lib.hm.dag.entryAfter [ "ensureCopyqService" ] ''
    if ${pkgs.systemd}/bin/systemctl --user --quiet is-active copyq.service; then
${copyqRuntimeCommands}
    fi
  '';
}
