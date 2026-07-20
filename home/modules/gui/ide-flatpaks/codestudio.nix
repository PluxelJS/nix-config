{ config, lib, pkgs, ... }:
let
  ideLib = import ./lib.nix { inherit config lib; };

  codeStudioDocker = pkgs.writeShellApplication {
    name = "docker";
    runtimeInputs = [ pkgs.podman-compose ];
    text = ''
      socket="unix://''${XDG_RUNTIME_DIR:?}/podman/podman.sock"

      export CONTAINER_HOST="$socket"
      export DOCKER_HOST="$socket"

      exec ${pkgs.podman}/bin/podman --remote --url "$socket" "$@"
    '';
  };

  codeStudioPath =
    lib.concatStringsSep ":" ([
      "${codeStudioDocker}/bin"
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
    talkNames = ideLib.sharedSecretTalkNames;
    filesystems = ideLib.sharedFilesystems ++ [
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
