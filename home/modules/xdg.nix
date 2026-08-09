{
  config,
  lib,
  pkgs,
  ...
}:
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

  notepadNextCommand = "NotepadNext";
  notepadNextDesktopId = "NotepadNext.desktop";
  notepadNextCustomMimeType = "text/x-notepadnext-text";
  notepadNextManagedMimeTypes = notepadNextMimeTypes ++ [ notepadNextCustomMimeType ];
  textEditorAssociationDesktopIds = [
    notepadNextDesktopId
    "io.github.trumank.CodeStudio.desktop"
    "vim.desktop"
    "micro.desktop"
    "featherpad.desktop"
  ];

  notepadNextMimeTypes = [
    "inode/x-empty"
    "text/plain"
    "text/x-nix"
    "text/x-ini"
    "application/json"
    "application/json5"
    "application/raml+yaml"
    "application/toml"
    "application/xhtml+xml"
    "application/xml"
    "application/x-yaml"
    "application/x-desktop"
    "application/x-asp"
    "application/x-bat"
    "application/x-csh"
    "application/x-openvpn-profile"
    "application/x-php"
    "application/x-ruby"
    "application/x-shellscript"
    "application/x-powershell"
    "application/yaml"
    "text/yaml"
    "text/x-yaml"
    "application/sql"
    "application/vnd.kde.knotificationrc"
    "application/vnd.kde.kxmlguirc"
    "application/x-kcsrc"
    "application/vnd.coffeescript"
    "text/css"
    "text/html"
    "text/javascript"
    "text/markdown"
    "text/tcl"
    "text/rust"
    "text/x-adasrc"
    "text/x-basic"
    "text/x-c++hdr"
    "text/x-c++src"
    "text/x-chdr"
    "text/x-cmake"
    "text/x-cobol"
    "text/x-csrc"
    "text/x-dsrc"
    "text/x-erlang"
    "text/x-fortran"
    "text/x-go"
    "text/x-haskell"
    "text/x-java"
    "text/x-literate-haskell"
    "text/x-makefile"
    "text/x-ocaml"
    "text/x-pascal"
    "text/x-patch"
    "text/x-python"
    "text/x-python3"
    "text/x-scheme"
    "text/x-scss"
    "text/x-svsrc"
    "text/x-svhdr"
    "text/x-tex"
    "text/x-txt2tags"
    "text/x-vb"
    "text/x-verilog"
    "text/x-vhdl"
    "text/x-hex"
    "text/x-systemd-unit"
    "text/vnd.trolltech.linguist"
    "text/vnd.graphviz"
    "text/x-ms-regedit"
    "text/x-common-lisp"
    "text/x-lua"
    "text/x-objcsrc"
    "text/x-matlab"
    "text/x-opencl-src"
  ];

  mimeAppsFile =
    let
      joinValues = lib.mapAttrs (_: lib.concatStringsSep ";");
    in
    (pkgs.formats.ini { }).generate "mimeapps.list" {
      "Added Associations" = joinValues config.xdg.mimeApps.associations.added;
      "Removed Associations" = joinValues config.xdg.mimeApps.associations.removed;
      "Default Applications" = joinValues config.xdg.mimeApps.defaultApplications;
    };
in
{
  xdg = lib.mkMerge [
    {
      enable = true;
    }
    (lib.mkIf cfg.desktopXdg {
      dataFile."mime/packages/notepadnext-extensions.xml".text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
          <mime-type type="${notepadNextCustomMimeType}">
            <comment>NotepadNext text source</comment>
            <sub-class-of type="text/plain"/>
            <glob pattern="*.nix"/>
            <glob pattern="*.conf"/>
            <glob pattern="*.cfg"/>
            <glob pattern="*.env"/>
            <glob pattern="*.ini"/>
            <glob pattern="*.inf"/>
            <glob pattern="*.properties"/>
            <glob pattern="*.less"/>
            <glob pattern="*.swift"/>
            <glob pattern="*.vue"/>
            <glob pattern="*.jsx"/>
            <glob pattern="*.psm1"/>
            <glob pattern="*.phpt"/>
            <glob pattern="*.phtml"/>
            <glob pattern="*.rbw"/>
            <glob pattern="*.pyw"/>
            <glob pattern="*.wsdl"/>
            <glob pattern="*.xaml"/>
            <glob pattern="*.xsml"/>
            <glob pattern="*.plist"/>
            <glob pattern="*.mxml"/>
            <glob pattern="*.vcproj"/>
            <glob pattern="*.vcxproj"/>
            <glob pattern="*.csproj"/>
            <glob pattern="*.csxproj"/>
            <glob pattern="*.vbproj"/>
            <glob pattern="*.dbproj"/>
            <glob pattern="*.bash"/>
            <glob pattern="*.bash_profile"/>
            <glob pattern="*.bashrc"/>
            <glob pattern="*.zsh"/>
            <glob pattern="*.zshrc"/>
            <glob pattern="*.fish"/>
            <glob pattern="*.sh"/>
            <glob pattern="*.ps1"/>
            <glob pattern="*.psd1"/>
            <glob pattern="*.cmd"/>
            <glob pattern="*.profile"/>
            <glob pattern="Dockerfile"/>
            <glob pattern="Containerfile"/>
            <glob pattern="Justfile"/>
          </mime-type>
        </mime-info>
      '';

      dataFile."applications/${notepadNextDesktopId}".text = ''
        [Desktop Entry]
        Type=Application
        Name=Notepad Next
        GenericName=Text Editor
        Comment=A cross-platform, reimplementation of Notepad++
        Exec=${notepadNextCommand} %F
        Icon=NotepadNext
        Terminal=false
        StartupNotify=true
        Categories=Qt;TextEditor;Utility;
        MimeType=${lib.concatStringsSep ";" notepadNextManagedMimeTypes};
      '';

      # Keep the declarative policy in the lower-priority XDG data location.
      # ~/.config/mimeapps.list is a writable regular file for application and
      # user overrides, while this file remains the reproducible fallback.
      dataFile."applications/mimeapps.list" = {
        force = true;
        source = mimeAppsFile;
      };

      dataFile."applications/protontricks-launch-mangohud.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Protontricks Launcher (MangoHud)
        Exec=${homeDir}/.local/bin/protontricks-launch-mangohud %f
        NoDisplay=true
        Terminal=false
        MimeType=application/x-ms-dos-executable;application/x-msdownload;
      '';

      dataFile."applications/jetbrainsd.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=JetBrains
        Exec=${homeDir}/.local/share/JetBrains/Daemon/bundles/current/jetbrainsd/bin/jetbrainsd handleUri %u
        NoDisplay=true
        Terminal=false
        MimeType=x-scheme-handler/jetbrains;
      '';

      mimeApps = {
        # The Home Manager implementation writes a read-only store symlink to
        # ~/.config/mimeapps.list. Generate the same policy ourselves above so
        # applications can retain a writable, higher-priority override file.
        enable = false;

        associations.added =
          (lib.genAttrs browserAssociationMimeTypes (_: "zen.desktop"))
          // (lib.genAttrs notepadNextManagedMimeTypes (_: textEditorAssociationDesktopIds))
          // {
            "application/pdf" = "wps-office-pdf.desktop";
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document" =
              "wps-office-wps.desktop";
            "application/zip" = [
              "com.teamspeak.TeamSpeak3.desktop"
              "peazip.desktop"
            ];
            "image/jpeg" = "org.gnome.eog.desktop";
            "image/png" = "org.gnome.eog.desktop";
            "text/csv" = "wps-office-et.desktop";
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
          // (lib.genAttrs notepadNextManagedMimeTypes (_: notepadNextDesktopId))
          // {
            "application/gzip" = "peazip.desktop";
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document" =
              "wps-office-wps.desktop";
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
              notepadNextDesktopId
              "io.github.trumank.CodeStudio.desktop"
              "vim.desktop"
              "micro.desktop"
              "featherpad.desktop"
            ];
            "x-scheme-handler/clash" = "mihomo-party.desktop";
            "x-scheme-handler/mihomo" = "mihomo-party.desktop";
            "x-scheme-handler/jetbrains" = "jetbrainsd.desktop";
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

  home.file = lib.mkIf cfg.desktopXdg {
    ".local/bin/protontricks-launch-mangohud" = {
      source = ../files/bin/protontricks-launch-mangohud;
      executable = true;
    };
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
  ];

  home.sessionVariables = {
    PAGER = "less";
    LESSHISTFILE = "${config.xdg.cacheHome}/less/history";
    TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:/nix/var/nix/profiles/default/share/terminfo:/usr/share/terminfo";
  }
  // lib.optionalAttrs cfg.desktopXdg {
    EDITOR = notepadNextCommand;
    VISUAL = notepadNextCommand;
  }
  // lib.optionalAttrs config.ahdg.features.ghostty {
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    TERMINAL = "ghostty";
  };

  home.activation.prepareWritableMimeApps = lib.mkIf cfg.desktopXdg (
    lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      target="${config.xdg.configHome}/mimeapps.list"

      # Migrate the old Home Manager/store link without touching an existing
      # regular file containing user or application choices.
      if [[ -L "$target" ]]; then
        resolved="$(readlink -f "$target" 2>/dev/null || true)"
        if [[ "$resolved" == /nix/store/* ]]; then
          rm -f "$target"
        fi
      fi

      install -dm755 "${config.xdg.configHome}"
      if [[ ! -e "$target" && ! -L "$target" ]]; then
        install -m644 /dev/null "$target"
      elif [[ -f "$target" && ! -L "$target" ]]; then
        chmod u+rw "$target"
      fi
    ''
  );

  home.activation.materializeDesktopMimeApps = lib.mkIf cfg.desktopXdg (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      target="${config.xdg.dataHome}/applications/mimeapps.list"
      if [[ -L "$target" ]]; then
        source="$(readlink -f "$target")"
        rm -f "$target"
        install -m644 "$source" "$target"
      fi
    ''
  );

  home.activation.updateMimeDatabase = lib.hm.dag.entryAfter [ "materializeDesktopMimeApps" ] ''
    if [[ -d "${config.xdg.dataHome}/mime" ]] && command -v update-mime-database >/dev/null 2>&1; then
      update-mime-database "${config.xdg.dataHome}/mime"
    fi
    if [[ -d "${config.xdg.dataHome}/applications" ]] && command -v update-desktop-database >/dev/null 2>&1; then
      update-desktop-database "${config.xdg.dataHome}/applications"
    fi
  '';
}
