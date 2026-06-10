{ config, lib, ... }:
let
  mangoTarget = "${config.xdg.configHome}/mango";
  mangoSource = ../../files/mango;
  writableRuntimeFiles = [
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
  '';

  xdg.configFile."mango" = {
    force = true;
    recursive = true;
    source = mangoSource;
  };
}
