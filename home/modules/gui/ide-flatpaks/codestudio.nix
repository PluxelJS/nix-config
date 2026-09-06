{ config, lib, pkgs, ... }:
let
  ideLib = import ./lib.nix { inherit config lib; };

  codeStudioDocker = pkgs.writeShellApplication {
    name = "docker";
    # `podman compose` delegates to podman-compose, which in turn invokes
    # `podman` through PATH.  Keep both sides of that hand-off store-backed
    # so the Flatpak never needs Podman Desktop or a host /usr/bin/podman.
    runtimeInputs = [
      pkgs.podman
      pkgs.podman-compose
    ];
    text = ''
      socket="unix://''${XDG_RUNTIME_DIR:?}/podman/podman.sock"

      export CONTAINER_HOST="$socket"
      export DOCKER_HOST="$socket"

      exec ${pkgs.podman}/bin/podman --remote --url "$socket" "$@"
    '';
  };

  # Electron asks gio to remove files.  Inside Flatpak that routes through the
  # Trash portal, which declines paths from Code Studio's host-backed project
  # mount.  Use the host implementation only for `gio trash`; other gio
  # subcommands retain their sandbox-native behavior.
  codeStudioGio = pkgs.writeShellApplication {
    name = "gio";
    text = ''
      if [[ "''${1:-}" == "trash" ]]; then
        exec /usr/bin/flatpak-spawn --host /usr/bin/gio "$@"
      fi

      exec /usr/bin/gio "$@"
    '';
  };

  # Wine is a host application rather than a Flatpak device permission.  Keep
  # its prefix app-private, while running Wine on the host so its complete
  # loader and library set are available to Code Studio terminals and tasks.
  codeStudioWine = pkgs.writeShellApplication {
    name = "wine";
    text = ''
      wine_prefix="''${WINEPREFIX:-$HOME/.wine}"

      exec /usr/bin/flatpak-spawn --host \
        --env="WINEPREFIX=$wine_prefix" \
        /usr/bin/wine "$@"
    '';
  };

  codeStudioPath =
    lib.concatStringsSep ":" ([
      "${codeStudioDocker}/bin"
      "${codeStudioGio}/bin"
      "${codeStudioWine}/bin"
      "${ideLib.codeStudioHomeDir}/.local/share/mise/shims"
    ] ++ ideLib.hostToolHomePathEntries ++ [
      ideLib.profileBinDir
      "${ideLib.homeDir}/.local/bin"
      "/app/bin"
      "/usr/bin"
      "${ideLib.homeDir}/.var/app/${ideLib.codeStudioAppId}/data/node_modules/bin"
    ]);

  codeStudioPersistDirs = [
    ".local"
    ".vscode"
    ".vscode-shared"
  ];

  codeStudioOverride = ideLib.mkOverrideCommand ideLib.codeStudioAppId (ideLib.mkOverrideArgs {
    noSockets = [
      "x11"
      "fallback-x11"
    ];
    noFilesystems = [ "host" ];
    devices = [ "kvm" ];
    # Needed by flatpak-spawn for the host gio/Wine bridges above.
    talkNames = ideLib.sharedSecretTalkNames ++ [ "org.freedesktop.Flatpak" ];
    filesystems = ideLib.sharedFilesystems ++ [
      "xdg-download:create"
      "xdg-run/podman/podman.sock"
    ];
    persists = codeStudioPersistDirs;
    env = {
      CODEX_HOME = ideLib.flatpakCodexHome;
      CARGO_TARGET_DIR = "${ideLib.homeDir}/.var/app/${ideLib.codeStudioAppId}/cache/cargo-target";
      PATH = codeStudioPath;
    };
  });
in
lib.mkIf config.ahdg.features.flatpak {
  home.activation.prepareCodeStudioProjectHome = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    mkdir -p '${ideLib.homeDir}/code'
  '';

  home.activation.prepareCodeStudioDesktopBridge = lib.hm.dag.entryAfter [
    "materializeFontconfigForFlatpak"
    "materializeGtkThemeForFlatpak"
    "materializeInputMethodForFlatpak"
    "materializePlasmaThemeForFlatpak"
    "prepareCodeStudioProjectHome"
    "syncRimeStaticPayload"
  ] ''
    ${ideLib.mkFakeHomeDesktopBridge ideLib.codeStudioHomeDir}

    rm -rf '${ideLib.homeDir}/.var/app/${ideLib.codeStudioAppId}/cache/fontconfig'
  '';

  home.activation.manageFlatpakCodeStudioOverride = lib.hm.dag.entryAfter [
    "prepareCodeStudioDesktopBridge"
    "prepareFlatpakIdeToolHomes"
  ] ''
    if command -v flatpak >/dev/null 2>&1; then
      ${codeStudioOverride}
    fi
  '';
}
