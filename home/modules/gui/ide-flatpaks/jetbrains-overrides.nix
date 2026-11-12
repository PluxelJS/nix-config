{ config, lib, ... }:
let
  ideLib = import ./lib.nix { inherit config lib; };

  jetbrainsBasePersistDirs = [
    ".cache"
    ".java"
    ".local"
  ];

  # Common PATH entries for JetBrains flatpak IDEs. App-specific entries are
  # added during activation because they depend on the Flatpak application id.
  jetbrainsBasePathEntries = [
    ideLib.profileBinDir
    "${ideLib.homeDir}/.local/bin"
    "/app/bin"
    "/usr/bin"
  ];

  jetbrainsEnv = ideLib.miseEnv // ideLib.gitEnv // {
    CARGO_HOME = "${ideLib.homeDir}/.cargo";
    RUSTUP_HOME = "${ideLib.homeDir}/.rustup";
    CODEX_HOME = ideLib.flatpakCodexHome;
    FLATPAK_IDE_ENV = "1";
    GTK_IM_MODULE = "";
    QT_IM_MODULE = "";
    QT_IM_MODULES = "wayland";
    SHELL = ideLib.profileZsh;
    XMODIFIERS = "";
  };

  jetbrainsBaseOverrideArgs = ideLib.mkOverrideArgs {
    sockets = [ "wayland" ];
    talkNames = ideLib.sharedSecretTalkNames;
    noSockets = [
      "x11"
      "fallback-x11"
      "ssh-auth"
      "gpg-agent"
    ];
    noFilesystems = [ "host" ];
    filesystems = ideLib.sharedFilesystems;
    persists = jetbrainsBasePersistDirs;
    env = jetbrainsEnv;
  };
in
lib.mkIf config.ahdg.features.flatpak {
  home.activation.manageFlatpakJetbrainsOverrides = lib.hm.dag.entryAfter [ "prepareFlatpakIdeToolHomes" ] ''
    if command -v flatpak >/dev/null 2>&1; then
      apply_jetbrains_override() {
        local app_id="$1"
        local app_dir='${ideLib.homeDir}/.var/app/'"$app_id"
        local app_cache_dir="$app_dir/cache"
        local app_data_dir="$app_dir/data"
        local override_args=(
${ideLib.renderShellArrayItems jetbrainsBaseOverrideArgs}
        )
        local base_path_entries=(
${ideLib.renderShellArrayItems jetbrainsBasePathEntries}
        )
        local path_entries=(
${ideLib.renderShellArrayItems ideLib.misePathEntries}
${ideLib.renderShellArrayItems ideLib.hostToolHomePathEntries}
          "$app_data_dir/node_modules/bin"
          "$app_data_dir/pnpm"
        )

        append_unique() {
          local array_name="$1"
          shift
          local -n target_array="$array_name"
          local item existing

          for item in "$@"; do
            for existing in "''${target_array[@]}"; do
              [[ "$existing" == "$item" ]] && continue 2
            done
            target_array+=("$item")
          done
        }

        add_python_profile() {
          append_unique path_entries "$app_data_dir/uv/bin"
        }

        case "$app_id" in
          com.jetbrains.DataSpell*)
            add_python_profile
            ;;
          com.jetbrains.PyCharm-Professional*)
            add_python_profile
            ;;
          com.jetbrains.PyCharm*)
            add_python_profile
            ;;
        esac

        append_unique path_entries "''${base_path_entries[@]}"

        local path_value
        path_value="$(IFS=:; printf '%s' "''${path_entries[*]}")"
        mkdir -p "$app_cache_dir/cargo-target"
        override_args+=("--env=CARGO_TARGET_DIR=$app_cache_dir/cargo-target")
        override_args+=("--env=PATH=$path_value")

        flatpak override --user --reset "$app_id"
        flatpak override --user "''${override_args[@]}" "$app_id"
      }

      while IFS= read -r app_id; do
        [[ -n "$app_id" ]] || continue
        apply_jetbrains_override "$app_id"
      done < <(flatpak list --app --columns=application 2>/dev/null | grep '^com\.jetbrains\.' || true)
    fi
  '';
}
