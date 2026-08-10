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
    }:
    ''
      [Desktop Entry]
      Type=Application
      Name=${name}
      ${lib.optionalString (comment != null) "Comment=${comment}"}
      Exec=${exec}
      ${lib.optionalString (tryExec != null) "TryExec=${tryExec}"}
      ${lib.optionalString (onlyShowIn != [ ]) "OnlyShowIn=${lib.concatStringsSep ";" onlyShowIn};"}
      Terminal=false
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
    '';

  copyqAutostart = pkgs.writeShellScript "ahdg-copyq-autostart" ''
    export QT_QPA_PLATFORMTHEME=kde
    export KDE_SESSION_VERSION=6
    export KDE_FULL_SESSION=true
    export COPYQ_CLIPBOARD_MIME_SIZE_LIMIT='.*:100M'
    exec ${lib.getExe pkgs.copyq} --start-server
  '';
in
lib.mkIf config.ahdg.features.gui {
  # Plasma consumes XDG autostart entries itself. Minimal compositors such as
  # Mango use dex as the session-side reader, so both desktops consume the same
  # declarative files without coupling ordinary GUI applications to systemd.
  home.packages = [
    pkgs.dex

    # Keep the archive application reproducible instead of depending on a
    # renamed or retired AUR binary package.
    pkgs.peazip
    # The upstream binary AUR package has disappeared more than once; nixpkgs
    # provides the same command and desktop ID used by the MIME policy.
    pkgs.notepad-next

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
      name = "CopyQ";
      comment = "Clipboard manager";
      exec = copyqAutostart;
      tryExec = lib.getExe pkgs.copyq;
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

    "autostart/ahdg-mango-dms.desktop".text = mkAutostart {
      name = "Dank Material Shell";
      exec = "dms run";
      tryExec = "dms";
      onlyShowIn = [ "X-Mango" ];
    };
  };

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
