{ config, lib, ... }:
let
  globalOverrideText = ''
    # Nix owns the global Flatpak integration policy only.
    # App-specific overrides under ~/.local/share/flatpak/overrides/<app-id>
    # remain manual so per-app exceptions keep working.

    [Context]
    sockets=wayland
    filesystems=xdg-config/fontconfig:ro;xdg-config/fcitx5:ro;xdg-config/gtk-3.0:ro;xdg-config/gtk-4.0:ro;xdg-config/color-schemes:ro;xdg-config/kdeglobals:ro;xdg-config/mimeapps.list:ro;xdg-config/mimeinfo.cache:ro;xdg-data/fcitx5:ro;xdg-data/fonts:ro;xdg-data/icons:ro;xdg-data/themes:ro

    [Environment]
    DESKTOP_SESSION=hyprland
    GTK_USE_PORTAL=1
    GTK_IM_MODULE=fcitx
    GLFW_IM_MODULE=ibus
    INPUT_METHOD=fcitx
    KDE_SESSION_VERSION=5
    QT_IM_MODULE=fcitx
    QT_IM_MODULES=wayland;fcitx
    QT_QPA_PLATFORM=
    QT_QPA_PLATFORMTHEME=kde
    SDL_IM_MODULE=fcitx
    XMODIFIERS=@im=fcitx
    XDG_CURRENT_DESKTOP=Hyprland:KDE
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
