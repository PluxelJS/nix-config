{
  # Desktop resources remain host-owned and are exposed read-only to Flatpak.
  # Fake-home applications mirror these relative paths into their private HOME
  # so toolkits keep using their normal lookup locations.
  home = [
    ".fonts"
    ".gtkrc-2.0"
    ".icons"
    ".themes"
  ];

  config = [
    "Kvantum"
    "color-schemes"
    "fcitx5"
    "fontconfig"
    "gtk-2.0"
    "gtk-3.0"
    "gtk-4.0"
    "kcminputrc"
    "kdeglobals"
    "mimeapps.list"
    "mimeinfo.cache"
  ];

  data = [
    "Kvantum"
    "color-schemes"
    "fcitx5"
    "fonts"
    "icons"
    "sounds"
    "themes"
  ];
}
