{ config, lib }:
let
  homeDir = config.home.homeDirectory;
  xdgConfigHome = config.xdg.configHome;
  xdgDataHome = config.xdg.dataHome;
  profileBinDir = "${homeDir}/.local/state/nix/profiles/profile/bin";
  profileZsh = "${profileBinDir}/zsh";
  flatpakCodexHome = "${homeDir}/.local/share/codex";
  shellQuote = lib.escapeShellArg;

  codeStudioAppId = "io.github.trumank.CodeStudio";
  codeStudioHomeDir = "${homeDir}/.var/app/${codeStudioAppId}/home";

  desktopResources = import ../flatpak-desktop-resources.nix;
  desktopBridgeEntries = fakeHomeDir:
    (map (path: {
      source = "${homeDir}/${path}";
      target = "${fakeHomeDir}/${path}";
    }) desktopResources.home)
    ++ (map (path: {
      source = "${xdgConfigHome}/${path}";
      target = "${fakeHomeDir}/.config/${path}";
    }) desktopResources.config)
    ++ (map (path: {
      source = "${xdgDataHome}/${path}";
      target = "${fakeHomeDir}/.local/share/${path}";
    }) desktopResources.data);

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

  mkFakeHomeDesktopBridge = fakeHomeDir:
    let
      entries = desktopBridgeEntries fakeHomeDir;
      sources = map (entry: entry.source) entries;
      targets = map (entry: entry.target) entries;
    in
    ''
      desktop_bridge_sources=(
${renderShellArrayItems sources}
      )
      desktop_bridge_targets=(
${renderShellArrayItems targets}
      )

      link_desktop_resource() {
        local source_path="$1"
        local target_path="$2"
        local backup_path="$target_path.app-private.bak"

        mkdir -p "$(dirname "$target_path")"

        if [[ -L "$target_path" ]]; then
          if [[ "$(readlink "$target_path")" == "$source_path" ]]; then
            return 0
          fi
          rm -f "$target_path"
        elif [[ -e "$target_path" ]]; then
          if [[ -e "$backup_path" ]] || [[ -L "$backup_path" ]]; then
            echo "cannot bridge $target_path: both the private path and $backup_path exist" >&2
            return 1
          fi
          mv "$target_path" "$backup_path"
        fi

        ln -sT "$source_path" "$target_path"
      }

      for index in "''${!desktop_bridge_sources[@]}"; do
        link_desktop_resource \
          "''${desktop_bridge_sources[$index]}" \
          "''${desktop_bridge_targets[$index]}"
      done
    '';

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
