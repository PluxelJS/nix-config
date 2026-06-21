{ config, lib, ... }:
let
  homeDir = config.home.homeDirectory;
  profileBinDir = "${homeDir}/.local/state/nix/profiles/profile/bin";
  shellQuote = lib.escapeShellArg;

  codeStudioAppId = "io.github.trumank.CodeStudio";
  codeStudioHomeDir = "${homeDir}/.var/app/${codeStudioAppId}/home";
  jetbrainsFilesDir = ../../files/jetbrains;
  inputhelp = ../../files/jetbrains/inputhelp.zip;

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
    "${homeDir}/.codex/config.toml"
    "${homeDir}/.config/gh:create"
    "${homeDir}/.config/opencode:create"
    "${homeDir}/.continue:create"
    "${homeDir}/.gemini:create"
    "${homeDir}/.hapi:create"
    "${homeDir}/.opencode:create"
    "${homeDir}/code:create"
    "xdg-data/Trash:create"
  ];

  sharedFilesystems = sharedReadOnlyFilesystems ++ sharedWritableFilesystems;
  jetbrainsPersistDirs = [
    ".cache"
    ".codex"
    ".java"
    ".local"
  ];

  # Common PATH for JetBrains flatpak IDEs (CLion, PyCharm, etc.)
  jetbrainsPath =
    lib.concatStringsSep ":" [
      profileBinDir
      "${homeDir}/.local/bin"
      "/app/bin"
      "/usr/bin"
    ];

  # CodeStudio needs extra PATH entries
  codeStudioPath =
    lib.concatStringsSep ":" [
      "${codeStudioHomeDir}/.local/share/mise/shims"
      profileBinDir
      "${homeDir}/.local/bin"
      "${homeDir}/.bun/bin"
      "/app/bin"
      "/usr/bin"
      "${homeDir}/.var/app/${codeStudioAppId}/data/node_modules/bin"
    ];

  jetbrainsEnv = {
    FLATPAK_IDE_ENV = "1";
    GTK_IM_MODULE = "";
    PATH = jetbrainsPath;
    QT_IM_MODULE = "";
    QT_IM_MODULES = "wayland";
    XMODIFIERS = "";
  };

  codeStudioPersistDirs = [
    ".bun"
    ".codex"
    ".local"
    ".npm"
    ".vscode"
    ".vscode-shared"
  ];

  sharedSecretTalkNames = [
    "org.freedesktop.secrets"
    "org.kde.kwalletd6"
    "org.kde.secretservicecompat"
  ];

  renderFlatpakArgs = args:
    lib.concatStringsSep " \\\n      " (map shellQuote args);

  renderShellArrayItems = args:
    lib.concatStringsSep "\n" (map (arg: "      ${shellQuote arg}") args);

  mkEnvArgs = env:
    lib.mapAttrsToList (name: value: "--env=${name}=${value}") env;

  mkOverrideArgs =
    {
      sockets ? [ ],
      noSockets ? [ ],
      talkNames ? [ ],
      filesystems ? [ ],
      noFilesystems ? [ ],
      persists ? [ ],
      env ? { },
    }:
    (map (value: "--socket=${value}") sockets)
    ++ (map (value: "--nosocket=${value}") noSockets)
    ++ (map (value: "--talk-name=${value}") talkNames)
    ++ (map (value: "--nofilesystem=${value}") noFilesystems)
    ++ (map (value: "--filesystem=${value}") filesystems)
    ++ (map (value: "--persist=${value}") persists)
    ++ mkEnvArgs env;

  mkOverrideCommand = appId: args:
    ''
      flatpak override --user --reset ${shellQuote appId}
      flatpak override --user \
        ${renderFlatpakArgs args} \
        ${shellQuote appId}
    '';

  jetbrainsOverrideArgs = mkOverrideArgs {
    sockets = [ "wayland" ];
    talkNames = sharedSecretTalkNames;
    noSockets = [
      "x11"
      "fallback-x11"
      "ssh-auth"
      "gpg-agent"
    ];
    noFilesystems = [ "host" ];
    filesystems = sharedFilesystems;
    persists = jetbrainsPersistDirs;
    env = jetbrainsEnv;
  };

  codeStudioOverride = mkOverrideCommand codeStudioAppId (mkOverrideArgs {
    noSockets = [
      "x11"
      "fallback-x11"
    ];
    talkNames = sharedSecretTalkNames;
    filesystems = sharedFilesystems;
    persists = codeStudioPersistDirs;
    env = {
      PATH = codeStudioPath;
    };
  });
in
lib.mkIf config.ahdg.features.flatpak {
  home.activation.manageFlatpakIdeOverrides = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if ! command -v flatpak >/dev/null 2>&1; then
      exit 0
    fi

    mkdir -p '${homeDir}/.codex'
    touch '${homeDir}/.codex/config.toml'

    apply_jetbrains_override() {
      local app_id="$1"
      local override_args=(
${renderShellArrayItems jetbrainsOverrideArgs}
      )

      flatpak override --user --reset "$app_id"
      flatpak override --user "''${override_args[@]}" "$app_id"
    }

    while IFS= read -r app_id; do
      [[ -n "$app_id" ]] || continue
      apply_jetbrains_override "$app_id"
    done < <(flatpak list --app --columns=application 2>/dev/null | grep '^com\.jetbrains\.' || true)

    ${codeStudioOverride}
  '';

  home.activation.installJetbrainsVmOptions = lib.hm.dag.entryAfter [ "manageFlatpakIdeOverrides" ] ''
    jetbrains_vmoptions_dir="${jetbrainsFilesDir}/vmoptions"

    append_unique_lines() {
      local snippet="$1"
      local target_file="$2"

      while IFS= read -r line || [[ -n "$line" ]]; do
        grep -Fxq -- "$line" "$target_file" || printf '%s\n' "$line" >> "$target_file"
      done < "$snippet"
    }

    if [[ -d "$jetbrains_vmoptions_dir" ]]; then
      while IFS= read -r target_file; do
        [[ -n "$target_file" ]] || continue
        while IFS= read -r snippet; do
          append_unique_lines "$snippet" "$target_file"
        done < <(find "$jetbrains_vmoptions_dir" -maxdepth 1 -type f -name '*.vmoptions' | sort)
      done < <(find "${homeDir}/.var/app" -path '*/config/JetBrains/*/*64.vmoptions' -type f 2>/dev/null | sort)
    fi
  '';

  home.activation.seedJetbrainsJavaPrefs = lib.hm.dag.entryAfter [ "manageFlatpakIdeOverrides" ] ''
    seed_region_pref() {
      local prefs_file="$1"

      if [[ -f "$prefs_file" ]] && grep -Fq 'key="code"' "$prefs_file"; then
        return
      fi

      mkdir -p "$(dirname "$prefs_file")"
      if [[ -f "$prefs_file" ]]; then
        sed -i '/<\/map>/i\  <entry key="code" value="apac"/>' "$prefs_file"
        return
      fi

      cat > "$prefs_file" <<'EOF'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE map SYSTEM "http://java.sun.com/dtd/preferences.dtd">
<map MAP_XML_VERSION="1.0">
  <entry key="code" value="apac"/>
</map>
EOF
    }

    while IFS= read -r app_dir; do
      [[ -n "$app_dir" ]] || continue
      seed_region_pref "$app_dir/.java/.userPrefs/jetbrains/region/prefs.xml"
    done < <(find "${homeDir}/.var/app" -maxdepth 1 -mindepth 1 -type d -name 'com.jetbrains.*' 2>/dev/null | sort)
  '';

  home.activation.installInputhelp = lib.hm.dag.entryAfter [ "installJetbrainsVmOptions" ] ''
    while IFS= read -r app_dir; do
      [[ -n "$app_dir" ]] || continue

      inputhelp_dir="$app_dir/config/JetBrains/inputhelp"
      rm -rf "$inputhelp_dir"
      mkdir -p "$inputhelp_dir"
      unzip -qo '${inputhelp}' -d "$inputhelp_dir"

      while IFS= read -r vmopts; do
        [[ -n "$vmopts" ]] || continue
        sed -i '/^-javaagent:/d' "$vmopts"
        printf '%s\n' "-javaagent:$inputhelp_dir/inputhelp.jar=jetbrains" >> "$vmopts"
      done < <(find "$app_dir/config/JetBrains" -path '*/config/JetBrains/*/*64.vmoptions' -type f 2>/dev/null | sort)
    done < <(find "${homeDir}/.var/app" -maxdepth 1 -mindepth 1 -type d -name 'com.jetbrains.*' 2>/dev/null | sort)
  '';
}
