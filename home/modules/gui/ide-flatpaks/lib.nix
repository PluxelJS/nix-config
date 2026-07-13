{ config, lib }:
let
  homeDir = config.home.homeDirectory;
  profileBinDir = "${homeDir}/.local/state/nix/profiles/profile/bin";
  profileZsh = "${profileBinDir}/zsh";
  flatpakCodexHome = "${homeDir}/.local/share/codex";
  shellQuote = lib.escapeShellArg;

  codeStudioAppId = "io.github.trumank.CodeStudio";
  codeStudioHomeDir = "${homeDir}/.var/app/${codeStudioAppId}/home";

  hostToolHomeDirs = [
    ".bun"
    ".bundle"
    ".cargo"
    ".ccache"
    ".cmake"
    ".composer"
    ".conan"
    ".conan2"
    ".dotnet"
    ".gem"
    ".gradle"
    ".ipython"
    ".ivy2"
    ".jupyter"
    ".m2"
    ".node-gyp"
    ".npm"
    ".pnpm-store"
    ".pyenv"
    ".rbenv"
    ".rustup"
    ".sbt"
    ".sdkman"
    ".virtualenvs"
    ".vcpkg"
    ".yarn"
    "go"
  ];

  hostToolHomeFilesystems = map (path: "${homeDir}/${path}:create") hostToolHomeDirs;

  sharedReadOnlyFilesystems = [
    "${homeDir}/.config/atuin:ro"
    "${homeDir}/.config/git:ro"
    "${homeDir}/.config/starship:ro"
    "${homeDir}/.config/zsh:ro"
    "${homeDir}/.gitconfig:ro"
    "${homeDir}/.local/state/nix/profiles:ro"
    "/nix/store:ro"
  ];

  sharedWritableFilesystems = [
    "${homeDir}/.claude:create"
    "${homeDir}/.codex:create"
    "${homeDir}/.config/gh:create"
    "${homeDir}/.config/opencode:create"
    "${homeDir}/.continue:create"
    "${homeDir}/.gemini:create"
    "${homeDir}/.hapi:create"
    "${homeDir}/.opencode:create"
    "${homeDir}/code:create"
    "xdg-data/Trash:create"
  ];

  sharedFilesystems = sharedReadOnlyFilesystems ++ sharedWritableFilesystems ++ hostToolHomeFilesystems;

  renderFlatpakArgs = args:
    lib.concatStringsSep " \\\n      " (map shellQuote args);

  renderShellArrayItems = args:
    lib.concatStringsSep "\n" (map (arg: "      ${shellQuote arg}") args);

  mkEnvArgs = env:
    lib.mapAttrsToList (name: value: "--env=${name}=${value}") env;

  assertNoHostToolPersists = persists:
    let
      overlaps = lib.intersectLists hostToolHomeDirs persists;
    in
    assert lib.assertMsg (overlaps == [ ])
      "IDE Flatpak host tool homes must be mounted with --filesystem=:create, not --persist: ${lib.concatStringsSep ", " overlaps}";
    persists;
in
rec {
  inherit
    codeStudioAppId
    codeStudioHomeDir
    flatpakCodexHome
    hostToolHomeDirs
    homeDir
    profileBinDir
    profileZsh
    renderFlatpakArgs
    renderShellArrayItems
    sharedFilesystems
    shellQuote
    ;

  jetbrainsFilesDir = ../../../files/jetbrains;
  inputhelp = ../../../files/jetbrains/inputhelp.zip;

  hostToolHomePathEntries = [
    "${homeDir}/.bun/bin"
    "${homeDir}/.cargo/bin"
    "${homeDir}/.composer/vendor/bin"
    "${homeDir}/.dotnet/tools"
    "${homeDir}/.gem/bin"
    "${homeDir}/go/bin"
    "${homeDir}/.pyenv/shims"
    "${homeDir}/.pyenv/bin"
    "${homeDir}/.rbenv/shims"
    "${homeDir}/.rbenv/bin"
    "${homeDir}/.sdkman/candidates/java/current/bin"
    "${homeDir}/.sdkman/bin"
    "${homeDir}/.yarn/bin"
  ];

  sharedSecretTalkNames = [
    "org.freedesktop.secrets"
    "org.kde.kwalletd6"
    "org.kde.secretservicecompat"
  ];

  mkOverrideArgs =
    {
      sockets ? [ ],
      noSockets ? [ ],
      devices ? [ ],
      talkNames ? [ ],
      filesystems ? [ ],
      noFilesystems ? [ ],
      persists ? [ ],
      env ? { },
    }:
    (map (value: "--socket=${value}") sockets)
    ++ (map (value: "--nosocket=${value}") noSockets)
    ++ (map (value: "--device=${value}") devices)
    ++ (map (value: "--talk-name=${value}") talkNames)
    ++ (map (value: "--nofilesystem=${value}") noFilesystems)
    ++ (map (value: "--filesystem=${value}") filesystems)
    ++ (map (value: "--persist=${value}") (assertNoHostToolPersists persists))
    ++ mkEnvArgs env;

  mkOverrideCommand = appId: args:
    ''
      flatpak override --user --reset ${shellQuote appId}
      flatpak override --user \
        ${renderFlatpakArgs args} \
        ${shellQuote appId}
    '';
}
