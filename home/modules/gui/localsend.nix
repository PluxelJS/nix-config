{ config, lib, pkgs, ... }:
let
  # LocalSend is a Flutter/GTK application. On the non-NixOS CachyOS host it
  # needs the same host GL bridge as the other Nix-managed GPU applications.
  localsend = config.lib.nixGL.wrap pkgs.localsend;
  localsendCli = pkgs.writeShellScriptBin "localsend" ''
    exec ${lib.getExe localsend} "$@"
  '';
in
lib.mkIf config.ahdg.features.localsend {
  home.packages = [
    localsend
    localsendCli
  ];
}
