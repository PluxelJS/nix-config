{ config, lib, ... }:
let
  ghosttyThemeTarget = "${config.xdg.configHome}/ghostty/config-dankcolors";
  ghosttyThemeDefault = ../files/themes/ghostty/config-dankcolors;
in lib.mkIf config.ahdg.features.themeRuntime {
  home.activation.ensureWritableThemeFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Keep DMS-managed theme files writable. If they do not exist yet, seed them
    # from the defaults stored in the Nix config tree.
    if [ -L "${ghosttyThemeTarget}" ] || [ ! -e "${ghosttyThemeTarget}" ]; then
      rm -f "${ghosttyThemeTarget}"
      install -Dm644 "${ghosttyThemeDefault}" "${ghosttyThemeTarget}"
    fi
  '';
}
