{
  config,
  lib,
  pkgs,
  ...
}:
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

  dmsAutostart = pkgs.writeShellScript "ahdg-mango-dms-autostart" ''
    # The backend socket can appear shortly after the shell starts. Apply the
    # clipboard retention policy once it is ready; DMS persists the setting in
    # its own database, and repeating this on login keeps it declarative.
    (
      for _ in $(${pkgs.coreutils}/bin/seq 1 50); do
        if ${lib.getExe pkgs.dms} clipboard config set \
          --enable \
          --max-history 20000 \
          --auto-clear-days 0 \
          --no-clear-at-startup >/dev/null 2>&1; then
          exit 0
        fi
        ${pkgs.coreutils}/bin/sleep 0.2
      done
    ) &

    exec ${lib.getExe pkgs.dms} run
  '';
in
lib.mkIf config.ahdg.features.gui {
  # Plasma consumes XDG autostart entries itself. Minimal compositors such as
  # Mango use dex as the session-side reader, so ordinary GUI applications keep
  # sharing the same declarative files. DMS is a session service instead: its
  # clipboard IPC must survive Home Manager switches and be restartable.
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
      name = "CopyQ (autostart disabled)";
      comment = "Installed as a fallback; DMS owns clipboard history";
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

  home.activation.ensureDmsService = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    if ${pkgs.systemd}/bin/systemctl --user --quiet is-active mango-session.target; then
      ${pkgs.systemd}/bin/systemctl --user start ahdg-mango-dms.service 2>/dev/null || true
    fi
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
}
