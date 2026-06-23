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

  jetbrainsEnv = {
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
        local has_rust_profile=0
        local path_entries=(
          "$app_data_dir/mise/shims"
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

        add_rust_profile() {
          has_rust_profile=1
        }

        repair_mise_rust_installs() {
          local rust_installs_dir="$app_data_dir/mise/installs/rust"
          local cargo_dir="${ideLib.homeDir}/.cargo"
          local cargo_bin_dir="$cargo_dir/bin"
          local data_cargo_dir="$app_data_dir/cargo"
          local data_rustup_dir="$app_data_dir/rustup"
          local rustup_dir="${ideLib.homeDir}/.rustup"
          local install_link target toolchain_dir toolchain_name version major minor

          [[ "$has_rust_profile" == "1" ]] || return 0
          mkdir -p "$app_dir"

          if [[ ! -e "$cargo_bin_dir/rustup" && -e "$data_cargo_dir/bin/rustup" ]]; then
            mkdir -p "$cargo_dir"
            cp -a "$data_cargo_dir/." "$cargo_dir/"
          fi

          if [[ -d "$data_rustup_dir" ]]; then
            mkdir -p "$rustup_dir"
            if [[ ! -d "$rustup_dir/toolchains" && -d "$data_rustup_dir/toolchains" ]]; then
              cp -a "$data_rustup_dir/." "$rustup_dir/"
            elif [[ -f "$data_rustup_dir/settings.toml" ]] && ! grep -Fq 'default_toolchain' "$rustup_dir/settings.toml" 2>/dev/null; then
              cp -a "$data_rustup_dir/settings.toml" "$rustup_dir/settings.toml"
            fi
          fi

          [[ -d "$cargo_bin_dir" ]] || return 0
          [[ -e "$cargo_bin_dir/rustup" || -L "$cargo_bin_dir/rustup" ]] || return 0
          mkdir -p "$rust_installs_dir"

          while IFS= read -r install_link; do
            target="$(readlink "$install_link")"
            if [[ "$target" == "${ideLib.homeDir}/.cargo/bin" ]]; then
              rm -f "$install_link"
            fi
          done < <(find "$rust_installs_dir" -maxdepth 1 -type l -print 2>/dev/null | sort)

          ensure_rust_install_link() {
            local name="$1"
            local target_dir="$2"
            local link_path="$rust_installs_dir/$name"

            [[ -n "$name" ]] || return 0
            [[ -d "$target_dir" ]] || return 0
            if [[ -e "$link_path" && ! -L "$link_path" ]]; then
              return 0
            fi
            ln -sfnT "$target_dir" "$link_path"
          }

          while IFS= read -r toolchain_dir; do
            toolchain_name="''${toolchain_dir##*/}"
            version="''${toolchain_name%-x86_64-unknown-linux-gnu}"

            case "$version" in
              [0-9]*.[0-9]*.[0-9]*)
                major="''${version%%.*}"
                minor="''${version#*.}"
                minor="''${minor%%.*}"
                ensure_rust_install_link "$toolchain_name" "$toolchain_dir"
                ensure_rust_install_link "$version" "$toolchain_dir"
                ensure_rust_install_link "$major" "$toolchain_dir"
                ensure_rust_install_link "$major.$minor" "$toolchain_dir"
                ensure_rust_install_link latest "$toolchain_dir"
                ensure_rust_install_link stable "$toolchain_dir"
                ;;
              nightly)
                ensure_rust_install_link nightly "$toolchain_dir"
                ;;
            esac
          done < <(find "$rustup_dir/toolchains" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort -V)
          return 0
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

        case "$app_id" in
          com.jetbrains.CLion* | com.jetbrains.RustRover*)
            add_rust_profile
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
        repair_mise_rust_installs
      }

      while IFS= read -r app_id; do
        [[ -n "$app_id" ]] || continue
        apply_jetbrains_override "$app_id"
      done < <(flatpak list --app --columns=application 2>/dev/null | grep '^com\.jetbrains\.' || true)
    fi
  '';
}
