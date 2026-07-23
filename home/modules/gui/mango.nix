{
  config,
  lib,
  pkgs,
  ...
}:
let
  runtime = config.ahdg.theme.runtime;
  mangoTarget = "${config.xdg.configHome}/mango";
  mangoSource = ../../files/mango;
  copyqPreStart = pkgs.writeShellScript "copyq-pre-start" ''
    terminate_copyq() {
      ${pkgs.procps}/bin/pkill "$@" -x copyq 2>/dev/null || true
      ${pkgs.procps}/bin/pkill "$@" -x '\.copyq-wrapped' 2>/dev/null || true
    }

    copyq_is_running() {
      ${pkgs.procps}/bin/pgrep -x copyq >/dev/null 2>&1 \
        || ${pkgs.procps}/bin/pgrep -x '\.copyq-wrapped' >/dev/null 2>&1
    }

    terminate_copyq -TERM
    for _ in {1..20}; do
      copyq_is_running || exit 0
      ${pkgs.coreutils}/bin/sleep 0.1
    done

    terminate_copyq -KILL
  '';
  staticFiles = [
    "appearance.conf"
    "config.conf"
    "dms.conf"
    "env.conf"
    "monitors.conf"
    "rules.conf"
    "rules/10-float-and-geometry.conf"
    "rules/20-tags.conf"
    "rules/90-games.conf"
    "startup.conf"
  ];
  runtimeFiles = [
    "dms/colors.conf"
    "dms/cursor.conf"
    "dms/layout.conf"
  ];
  scriptFiles = [
    "scripts/browser-activate.sh"
    "scripts/clipboard-image-dump.sh"
    "scripts/dump-active-window.sh"
    "scripts/force-kill-focused.sh"
    "scripts/lid-internal-output.sh"
    "scripts/overview-spotlight-toggle.sh"
    "scripts/screenshot.sh"
    "scripts/spawn"
  ];
in
lib.mkIf config.ahdg.features.gui {
  home.activation.prepareMangoConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [[ -L "${mangoTarget}" || -f "${mangoTarget}" ]]; then
      rm -f "${mangoTarget}"
    fi

    mango_session_target="${config.xdg.configHome}/systemd/user/mango-session.target"
    if [[ -e "$mango_session_target" && ! -L "$mango_session_target" ]]; then
      rm -f "$mango_session_target"
    fi
  '';

  home.activation.installMangoConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    install -dm755 "${mangoTarget}"
    rm -f "${mangoTarget}"/config.conf.backup*
    rm -f "${mangoTarget}/dms/outputs.conf"
    rm -rf "${mangoTarget}/dms/profiles"

    ${lib.concatMapStringsSep "\n" (path: ''
      install -Dm644 "${mangoSource}/${path}" "${mangoTarget}/${path}"
    '') staticFiles}

    ${lib.concatMapStringsSep "\n" (path: ''
      install -Dm755 "${mangoSource}/${path}" "${mangoTarget}/${path}"
    '') scriptFiles}

    seed_runtime_file() {
      local path=$1
      local target="${mangoTarget}/$path"
      local resolved=

      if [[ -L "$target" ]]; then
        resolved="$(readlink -f "$target" || true)"
        rm -f "$target"
        if [[ -n "$resolved" && -f "$resolved" ]]; then
          install -Dm644 "$resolved" "$target"
          return
        fi
      fi

      if [[ ! -e "$target" ]]; then
        install -Dm644 "${mangoSource}/$path" "$target"
      fi
    }

    for path in ${lib.escapeShellArgs runtimeFiles}; do
      seed_runtime_file "$path"
    done

    upsert_runtime_kv() {
      local target=$1
      local key=$2
      local value=$3

      if grep -q "^$key=" "$target"; then
        sed -i "s/^$key=.*/$key=$value/" "$target"
      else
        printf '%s=%s\n' "$key" "$value" >> "$target"
      fi
    }

    upsert_runtime_kv "${mangoTarget}/dms/cursor.conf" cursor_theme "${runtime.cursor.name}"
    upsert_runtime_kv "${mangoTarget}/dms/cursor.conf" cursor_size "${toString runtime.cursor.size}"

    sed -i \
      -e 's/^env=GTK_THEME,.*/env=GTK_THEME,${runtime.gtk.themeSpec}/' \
      -e 's/^env=XCURSOR_THEME,.*/env=XCURSOR_THEME,${runtime.cursor.name}/' \
      -e 's/^env=XCURSOR_SIZE,.*/env=XCURSOR_SIZE,${toString runtime.cursor.size}/' \
      "${mangoTarget}/env.conf"
  '';

  home.activation.configureCopyqTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    copyq_config="${config.xdg.configHome}/copyq/copyq.conf"
    install -dm755 "$(dirname "$copyq_config")"
    if [[ ! -e "$copyq_config" ]]; then
      printf '[Options]\nstyle=@ByteArray(Fusion)\n' > "$copyq_config"
    elif grep -q '^style=' "$copyq_config"; then
      sed -i 's/^style=.*/style=@ByteArray(Fusion)/' "$copyq_config"
    else
      printf 'style=@ByteArray(Fusion)\n' >> "$copyq_config"
    fi

    if command -v copyq >/dev/null 2>&1; then
      timeout 2s copyq config style Fusion >/dev/null 2>&1 || true
    fi
  '';

  home.activation.ensureOpenRazerRuntime = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if command -v systemctl >/dev/null 2>&1 && command -v openrazer-daemon >/dev/null 2>&1; then
      systemctl --user daemon-reload >/dev/null 2>&1 || true
      systemctl --user enable --now openrazer-daemon.service >/dev/null 2>&1 || true
    fi
  '';

  home.activation.removeMigratedMangoAutostart =
    lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ]
      ''
        autostart_dir="${config.xdg.configHome}/autostart"
        for entry in \
          abdownloader.desktop \
          cachyos-hello.desktop \
          jetbrains-toolbox.desktop \
          mihomo-party.desktop \
          razer.desktop \
          后台启动浏览器.desktop
        do
          rm -f "$autostart_dir/$entry"
        done
      '';

  xdg.configFile."systemd/user/mango-session.target" = {
    force = true;
    text = ''
      [Unit]
      Description=MangoWC compositor session
      After=graphical-session.target
      BindsTo=graphical-session.target
      Wants=graphical-session.target xdg-desktop-autostart.target
    '';
  };

  systemd.user.services.copyq = {
    Unit = {
      Description = "CopyQ clipboard manager";
      Documentation = [ "https://copyq.readthedocs.io/" ];
      After = [ "graphical-session.target" ];
      PartOf = [ "mango-session.target" ];
    };

    Service = {
      # Retire a pre-migration compositor-launched server and its detached
      # Wayland providers before systemd takes ownership of the process group.
      ExecStartPre = copyqPreStart;
      ExecStart = "${lib.getExe pkgs.copyq} --start-server";
      Type = "forking";
      Restart = "on-failure";
      RestartSec = 2;
      KillMode = "control-group";
      TimeoutStopSec = 5;
      Environment = [
        "QT_QPA_PLATFORMTHEME=kde"
        "KDE_SESSION_VERSION=6"
        "KDE_FULL_SESSION=true"
        # Bound a single MIME payload so a malformed or huge clipboard item
        # cannot exhaust the monitor process. CopyQ 16 uses the same default;
        # keeping it explicit documents and preserves the desktop policy.
        "COPYQ_CLIPBOARD_MIME_SIZE_LIMIT=.*:100M"
      ];
    };

    Install.WantedBy = [ "mango-session.target" ];
  };

  home.file.".local/bin/abdm-open" = {
    source = ../../files/bin/abdm-open;
    executable = true;
  };

  home.file.".local/bin/abdm-launch" = {
    source = ../../files/bin/abdm-launch;
    executable = true;
  };

  home.file.".local/bin/abdm-tray" = {
    source = ../../files/bin/abdm-tray;
    executable = true;
  };
}
