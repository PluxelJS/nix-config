{ config, lib, ... }:
let
  desktopResources = import ./flatpak-desktop-resources.nix;
  desktopFilesystems =
    (map (path: "~/${path}:ro") desktopResources.home)
    ++ (map (path: "xdg-config/${path}:ro") desktopResources.configReadOnly)
    ++ (map (path: "xdg-config/${path}") desktopResources.configWritable)
    ++ (map (path: "xdg-data/${path}:ro") desktopResources.data);
  globalFilesystems = desktopFilesystems ++ [
    "~/.nix-profile:ro"
    "~/.local/state/nix/profiles:ro"
    "/nix/store:ro"
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
