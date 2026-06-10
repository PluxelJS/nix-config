{ config, lib, ... }:
let
  cfg = config.ahdg.features;
  homeDir = config.home.homeDirectory;

  browserAssociationMimeTypes = [
    "application/x-extension-htm"
    "application/x-extension-html"
    "application/x-extension-shtml"
    "application/x-extension-xht"
    "application/x-extension-xhtml"
    "application/xhtml+xml"
    "text/html"
    "x-scheme-handler/chrome"
  ];

  browserDefaultMimeTypes = browserAssociationMimeTypes ++ [
    "x-scheme-handler/http"
    "x-scheme-handler/https"
  ];

  codiumMimeTypes = [
    "application/json"
    "application/json5"
    "application/raml+yaml"
    "application/yaml"
  ];
in
{
  xdg = lib.mkMerge [
    {
      enable = true;
    }
    (lib.mkIf cfg.desktopXdg {
      mimeApps = {
        enable = true;

        associations.added =
          (lib.genAttrs browserAssociationMimeTypes (_: "zen.desktop"))
          // (lib.genAttrs codiumMimeTypes (_: "codium-wayland.desktop"))
          // {
            "application/pdf" = "wps-office-pdf.desktop";
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "wps-office-wps.desktop";
            "application/zip" = [
              "com.teamspeak.TeamSpeak3.desktop"
              "peazip.desktop"
            ];
            "image/jpeg" = "org.gnome.eog.desktop";
            "image/png" = "org.gnome.eog.desktop";
            "text/csv" = "wps-office-et.desktop";
            "text/plain" = "code-oss.desktop";
            "x-scheme-handler/http" = [
              "zen.desktop"
              "xfce4-web-browser.desktop"
            ];
            "x-scheme-handler/https" = [
              "zen.desktop"
              "xfce4-web-browser.desktop"
            ];
          };

        defaultApplications =
          (lib.genAttrs browserDefaultMimeTypes (_: "zen.desktop"))
          // (lib.genAttrs codiumMimeTypes (_: "codium-wayland.desktop"))
          // {
            "application/gzip" = "peazip.desktop";
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "wps-office-wps.desktop";
            "application/x-7z-compressed" = "peazip.desktop";
            "application/x-bzip-compressed-tar" = "peazip.desktop";
            "application/x-bzip2" = "peazip.desktop";
            "application/x-gzip-compressed-tar" = "peazip.desktop";
            "application/x-lzip" = "peazip.desktop";
            "application/x-ms-dos-executable" = "protontricks-launch-mangohud.desktop";
            "application/x-msdownload" = "protontricks-launch-mangohud.desktop";
            "application/x-rar" = "peazip.desktop";
            "application/x-tar" = [
              "peazip.desktop"
              "org.kde.ark.desktop"
              "lxqt-archiver.desktop"
            ];
            "application/x-xz" = "peazip.desktop";
            "application/x-xz-compressed-tar" = "peazip.desktop";
            "application/zip" = "peazip.desktop";
            "application/zstd" = "peazip.desktop";
            "inode/directory" = [
              "org.kde.dolphin.desktop"
              "pcmanfm-qt.desktop"
            ];
            "text/plain" = [
              "vim.desktop"
              "micro.desktop"
              "featherpad.desktop"
              "codium.desktop"
              "com.visualstudio.code.desktop"
              "code-oss.desktop"
              "codium-wayland.desktop"
            ];
            "x-scheme-handler/clash" = "mihomo-party.desktop";
            "x-scheme-handler/mihomo" = "mihomo-party.desktop";
            "x-scheme-handler/jetbrains" = "jetbrains-toolbox.desktop";
          };
      };

      userDirs = {
        enable = true;
        createDirectories = true;
        setSessionVariables = true;
        desktop = "${homeDir}/桌面";
        documents = "${homeDir}/文档";
        download = "${homeDir}/下载";
        music = "${homeDir}/音乐";
        pictures = "${homeDir}/图片";
        publicShare = "${homeDir}/公共";
        templates = "${homeDir}/模板";
        videos = "${homeDir}/视频";
      };

      configFile = {
        "mimeapps.list".force = true;
        "user-dirs.conf".force = true;
        "user-dirs.dirs".force = true;
        "user-dirs.locale" = {
          force = true;
          text = "zh_CN\n";
        };
      };
    })
    (lib.mkIf config.ahdg.features.ghostty {
      configFile."xdg-terminals.list" = {
        force = true;
        text = ''
          com.mitchellh.ghostty.desktop
          Alacritty.desktop
          kitty.desktop
          foot.desktop
        '';
      };
    })
  ];

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESSHISTFILE = "${config.xdg.cacheHome}/less/history";
    TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:/nix/var/nix/profiles/default/share/terminfo:/usr/share/terminfo";
  }
  // lib.optionalAttrs config.ahdg.features.ghostty {
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    TERMINAL = "ghostty";
  };

  home.activation.removeLegacySessionEnv = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    legacy_env="${config.xdg.configHome}/environment.d/90-dms.conf"
    if [[ -f "$legacy_env" ]] && [[ ! -L "$legacy_env" ]]; then
      rm -f "$legacy_env"
    fi
  '';
}
