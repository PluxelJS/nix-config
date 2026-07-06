{ config, lib, ... }:
let
  globalFilesystems = [
    "~/.fonts:ro"
    "~/.gtkrc-2.0:ro"
    "~/.icons:ro"
    "~/.nix-profile:ro"
    "~/.themes:ro"
    "~/.local/state/nix/profiles:ro"
    "/nix/store:ro"
    "xdg-config/Kvantum:ro"
    "xdg-config/color-schemes:ro"
    "xdg-config/fcitx5:ro"
    "xdg-config/fontconfig:ro"
    "xdg-config/gtk-2.0:ro"
    "xdg-config/gtk-3.0:ro"
    "xdg-config/gtk-4.0:ro"
    "xdg-config/kcminputrc:ro"
    "xdg-config/kdeglobals:ro"
    "xdg-config/mimeapps.list:ro"
    "xdg-config/mimeinfo.cache:ro"
    "xdg-data/Kvantum:ro"
    "xdg-data/color-schemes:ro"
    "xdg-data/fcitx5:ro"
    "xdg-data/fonts:ro"
    "xdg-data/icons:ro"
    "xdg-data/sounds:ro"
    "xdg-data/themes:ro"
  ];

  globalOverrideText = ''
    # Nix owns only Flatpak-specific filesystem integration here.
    # Session environment belongs in MangoWC/Home Manager and is inherited by Flatpak.
    # App-specific overrides under ~/.local/share/flatpak/overrides/<app-id>
    # are activation-managed regular files so per-app policy stays writable.
    #
    # Home Manager's fontconfig snippets point at ~/.nix-profile and /nix/store.
    # Expose those globally so sandboxed apps can actually resolve Nix-managed
    # fonts like Source Han via the host fontconfig policy.

    [Context]
    filesystems=${lib.concatStringsSep ";" globalFilesystems};
  '';
in
lib.mkIf config.ahdg.features.flatpak {
  home.activation.removeLegacyFlatpakGlobalOverride = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    target="${config.xdg.dataHome}/flatpak/overrides/global"
    if [[ -f "$target" ]] && [[ ! -L "$target" ]]; then
      rm -f "$target"
    fi
  '';

  xdg.dataFile."flatpak/overrides/global" = {
    force = true;
    text = globalOverrideText;
  };
}
