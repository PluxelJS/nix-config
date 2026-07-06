{ config, lib, ... }:
let
  guiLib = import ./lib.nix { inherit lib; };
  runtime = config.ahdg.theme.runtime;
  mangoTarget = "${config.xdg.configHome}/mango";
  mangoSource = ../../files/mango;
  writableRuntimeFiles = [
    "${mangoTarget}/env.conf"
    "${mangoTarget}/dms/colors.conf"
    "${mangoTarget}/dms/cursor.conf"
    "${mangoTarget}/dms/layout.conf"
    "${mangoTarget}/dms/outputs.conf"
  ];
in
lib.mkIf config.ahdg.features.gui {
  home.activation.removeLegacyMangoConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [[ -e "${mangoTarget}" ]] && [[ ! -L "${mangoTarget}" ]]; then
      chmod -R u+w "${mangoTarget}" 2>/dev/null || true
      rm -rf "${mangoTarget}"
    fi

    mango_session_target="${config.xdg.configHome}/systemd/user/mango-session.target"
    if [[ -e "$mango_session_target" && ! -L "$mango_session_target" ]]; then
      rm -f "$mango_session_target"
    fi
  '';

  home.activation.materializeWritableMangoRuntime = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    rm -f "${mangoTarget}"/config.conf.backup*

    ${guiLib.materializeRuntimePaths { files = writableRuntimeFiles; }}

    if [[ -f "${mangoTarget}/env.conf" ]]; then
      sed -i \
        -e 's/^env=GTK_THEME,.*/env=GTK_THEME,${runtime.gtk.themeSpec}/' \
        -e 's/^env=XCURSOR_THEME,.*/env=XCURSOR_THEME,${runtime.cursor.name}/' \
        -e 's/^env=XCURSOR_SIZE,.*/env=XCURSOR_SIZE,${toString runtime.cursor.size}/' \
        "${mangoTarget}/env.conf"
    fi

    if [[ -f "${mangoTarget}/dms/cursor.conf" ]]; then
      sed -i \
        -e 's/^cursor_size=.*/cursor_size=${toString runtime.cursor.size}/' \
        -e 's/^cursor_theme=.*/cursor_theme=${runtime.cursor.name}/' \
        "${mangoTarget}/dms/cursor.conf"
    fi
  '';

  home.activation.removeMigratedMangoAutostart = lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ] ''
    autostart_dir="${config.xdg.configHome}/autostart"
    for entry in \
      abdownloader.desktop \
      jetbrains-toolbox.desktop \
      mihomo-party.desktop \
      razer.desktop \
      后台启动浏览器.desktop
    do
      rm -f "$autostart_dir/$entry"
    done
  '';

  xdg.configFile."mango" = {
    force = true;
    recursive = true;
    source = mangoSource;
  };

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
