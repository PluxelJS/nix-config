{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.ahdg.features.gui {
  home.packages = [
    # Both applications use GPU-backed native rendering. On CachyOS they need
    # the same host GL bridge as Ghostty and LocalSend.
    (config.lib.nixGL.wrap pkgs.meatshell)
  ];

  programs.zed-editor = {
    enable = true;
    package = config.lib.nixGL.wrap pkgs.zed-editor;
  };
}
