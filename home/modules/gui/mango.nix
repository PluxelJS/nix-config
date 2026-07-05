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

  xdg.configFile."mango" = {
    force = true;
    recursive = true;
    source = mangoSource;
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
