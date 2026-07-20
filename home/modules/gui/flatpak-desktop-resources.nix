{
  # Desktop resources remain host-owned. Stable resources are exposed
  # read-only; MIME application overrides stay writable so sandboxed desktop
  # apps can participate in the same host default-application policy.
  # Fake-home applications mirror these relative paths into their private HOME
  # so toolkits keep using their normal lookup locations.
  home = [
    ".fonts"
    ".gtkrc-2.0"
    ".icons"
    ".themes"
  ];

  configReadOnly = [
    "Kvantum"
    "color-schemes"
    "fcitx5"
    "fontconfig"
    "gtk-2.0"
    "gtk-3.0"
    "gtk-4.0"
    "kcminputrc"
    "kdeglobals"
    "mimeinfo.cache"
  ];

  configWritable = [
    "mimeapps.list"
  ];

  data = [
    "Kvantum"
    "color-schemes"
    "fcitx5"
    "fonts"
    "icons"
    "applications/mimeapps.list"
    "sounds"
    "themes"
  ];
}
