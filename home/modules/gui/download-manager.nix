{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The native host starts the GUI beside its real binary. Keep the rendering
  # bridge inside that entry point, including launches from the browser.
  graphicsLauncher = config.lib.nixGL.wrap (
    pkgs.writeShellScriptBin "mdm-graphics" ''
      exec "$@"
    ''
  );
  mdm = pkgs.misterdownloadmanager.override {
    guiLauncher = if config.ahdg.features.graphics then lib.getExe graphicsLauncher else null;
  };
  helpers = {
    yt-dlp = pkgs.yt-dlp;
    ffmpeg = pkgs.ffmpeg;
    gallery-dl = pkgs.gallery-dl;
  };
  helperPrograms = pkgs.writeText "mdm-programs.json" (
    builtins.toJSON (
      lib.mapAttrs (name: package: {
        inherit (package) version;
        exe = "${config.home.profileDirectory}/bin/${name}";
      }) helpers
    )
  );
in
lib.mkIf config.ahdg.features.gui {
  home.packages = [ mdm ] ++ builtins.attrValues helpers;

  # Use the application's own basename and startup argument. Plasma and Mango's
  # dex runner share this entry; no second vendor entry or tray script is needed.
  xdg.configFile."autostart/misterdownloadmanager.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Mister Download Manager
    Exec=${config.home.profileDirectory}/bin/misterdownloadmanager /startup
    TryExec=${config.home.profileDirectory}/bin/misterdownloadmanager
    Icon=misterdownloadmanager
    Terminal=false
    StartupNotify=false
    X-GNOME-Autostart-enabled=true
  '';

  xdg.mimeApps = lib.mkIf config.ahdg.features.desktopXdg {
    associations.added = {
      "x-scheme-handler/magnet" = "misterdownloadmanager.desktop";
      "application/x-bittorrent" = "misterdownloadmanager.desktop";
    };
    defaultApplications = {
      "x-scheme-handler/magnet" = "misterdownloadmanager.desktop";
      "application/x-bittorrent" = "misterdownloadmanager.desktop";
    };
  };

  # MDM intentionally owns writable host manifests and refreshes them at start.
  # Register during every switch too, so installed Firefox/Zen and Chromium
  # browsers never retain a collected store path after a package upgrade.
  home.activation.registerMdmBrowserHost = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${mdm}/bin/misterdownloadmanager-nmhost --register
  '';

  # Choose the Nix-managed media tools on first use, using stable profile paths.
  # Further choices in MDM's Video helpers window remain ordinary writable state.
  home.activation.seedMdmHelpers = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    mdm_programs="${config.xdg.dataHome}/misterdownloadmanager/tools/programs.json"
    if [[ ! -e "$mdm_programs" ]]; then
      install -Dm600 ${helperPrograms} "$mdm_programs"
    fi
  '';
}
