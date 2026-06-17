{ config, lib, pkgs, ... }:
let
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

    for target in ${lib.escapeShellArgs writableRuntimeFiles}; do
      if [[ ! -e "$target" ]]; then
        continue
      fi

      resolved="$(readlink -f "$target" || true)"
      if [[ -n "$resolved" && "$resolved" != "$target" && -f "$resolved" ]]; then
        rm -f "$target"
        install -Dm644 "$resolved" "$target"
      fi
    done

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
}
