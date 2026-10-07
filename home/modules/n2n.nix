{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.n2n-web;
  app = pkgs.runCommand "n2n-web" { } ''
    mkdir -p $out/share/n2n-web
    cp ${../files/n2n-web/manager.py} $out/share/n2n-web/manager.py
    cp ${../files/n2n-web/index.html} $out/share/n2n-web/index.html
  '';
  unit = pkgs.writeText "n2n-lan.service" ''
    [Unit]
    Description=n2n LAN client managed by the local console
    Wants=network-online.target
    After=network-online.target
    StartLimitIntervalSec=0
    [Service]
    ExecStart=/usr/local/lib/n2n-lan/helper run
    Restart=on-failure
    RestartSec=5
    StateDirectory=n2n-lan
    StateDirectoryMode=0700
    UMask=0077
    NoNewPrivileges=true
    CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_SETUID CAP_SETGID
    ProtectSystem=strict
    ProtectHome=true
    PrivateTmp=true
    ProtectKernelTunables=true
    ProtectKernelModules=true
    ProtectControlGroups=true
    RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK
  '';
  installer = pkgs.writeShellApplication {
    name = "n2n-install-host";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if (( EUID != 0 )); then
        exec /usr/bin/pkexec "$0" "$@"
      fi
      install -d -m755 /usr/local/lib/n2n-lan
      install -m755 ${app}/share/n2n-web/manager.py /usr/local/lib/n2n-lan/helper
      ln -sfn ${pkgs.n2n} /usr/local/lib/n2n-lan/runtime
      # Keep the dynamically linked host client alive across Nix garbage collection.
      install -d -m755 /nix/var/nix/gcroots
      ln -sfn ${pkgs.n2n} /nix/var/nix/gcroots/ahdg-n2n
      install -m644 ${unit} /etc/systemd/system/n2n-lan.service
      /usr/bin/systemctl daemon-reload
      echo 'n2n 主机组件已安装；请在本机 Web 页面点击连接。'
    '';
  };
in
{
  options.services.n2n-web.enable = lib.mkEnableOption "Local n2n Web console for EasyN2N groups";
  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.n2n
      installer
    ];
    systemd.user.services.n2n-web = {
      Unit.Description = "Local n2n LAN Web console";
      Service = {
        ExecStart = "${pkgs.python3}/bin/python3 ${app}/share/n2n-web/manager.py";
        Restart = "on-failure";
        RestartSec = 3;
        UMask = "0077";
      };
      Install.WantedBy = [ "default.target" ];
    };
    xdg.desktopEntries.n2n-web = {
      name = "n2n 联机";
      comment = "连接小黄鸭小组并管理 Linux n2n";
      exec = "${pkgs.xdg-utils}/bin/xdg-open http://127.0.0.1:11212";
      icon = "network-vpn";
      terminal = false;
      categories = [ "Network" ];
    };
  };
}
