{ config, lib, ... }:
let
  ideLib = import ./lib.nix { inherit config lib; };

  codeStudioPath =
    lib.concatStringsSep ":" ([
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
    talkNames = ideLib.sharedSecretTalkNames;
    filesystems = ideLib.sharedFilesystems;
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

  home.activation.manageFlatpakCodeStudioOverride = lib.hm.dag.entryAfter [ "prepareCodeStudioProjectHome" "prepareFlatpakIdeToolHomes" ] ''
    if command -v flatpak >/dev/null 2>&1; then
      ${codeStudioOverride}
    fi
  '';
}
