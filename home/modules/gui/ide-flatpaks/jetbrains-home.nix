{ config, lib, ... }:
let
  ideLib = import ./lib.nix { inherit config lib; };
in
lib.mkIf config.ahdg.features.flatpak {
  home.activation.prepareFlatpakIdeHostCodexConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    mkdir -p '${ideLib.homeDir}/.codex'
    touch '${ideLib.homeDir}/.codex/config.toml'
  '';

  home.activation.prepareFlatpakIdeCodexHomes = lib.hm.dag.entryAfter [
    "manageFlatpakCodeStudioOverride"
    "manageFlatpakJetbrainsOverrides"
  ] ''
    host_codex_config='${ideLib.homeDir}/.codex/config.toml'

    prepare_codex_home() {
      local app_dir="$1"
      local old_codex_dir="$app_dir/.codex"
      local new_codex_dir="$app_dir/.local/share/codex"

      mkdir -p "$new_codex_dir"

      if [[ -d "$old_codex_dir" ]]; then
        shopt -s dotglob nullglob
        for old_path in "$old_codex_dir"/*; do
          local name="''${old_path##*/}"
          [[ "$name" == "config.toml" ]] && continue
          if [[ ! -e "$new_codex_dir/$name" && ! -L "$new_codex_dir/$name" ]]; then
            mv "$old_path" "$new_codex_dir/"
          fi
        done
        shopt -u dotglob nullglob

        if [[ -e "$old_codex_dir/config.toml" ]] || [[ -L "$old_codex_dir/config.toml" ]]; then
          if [[ ! -s "$old_codex_dir/config.toml" ]] || cmp -s "$old_codex_dir/config.toml" "$host_codex_config"; then
            rm -f "$old_codex_dir/config.toml"
          elif [[ ! -e "$old_codex_dir/config.toml.app-private.bak" ]]; then
            mv "$old_codex_dir/config.toml" "$old_codex_dir/config.toml.app-private.bak"
          fi
        fi

        rmdir "$old_codex_dir" 2>/dev/null || true
      fi

      if [[ -e "$new_codex_dir/config.toml" ]] || [[ -L "$new_codex_dir/config.toml" ]]; then
        if [[ -L "$new_codex_dir/config.toml" ]]; then
          rm -f "$new_codex_dir/config.toml"
        elif [[ ! -s "$new_codex_dir/config.toml" ]] || cmp -s "$new_codex_dir/config.toml" "$host_codex_config"; then
          rm -f "$new_codex_dir/config.toml"
        elif [[ ! -e "$new_codex_dir/config.toml.app-private.bak" ]]; then
          mv "$new_codex_dir/config.toml" "$new_codex_dir/config.toml.app-private.bak"
        fi
      fi

      ln -s "$host_codex_config" "$new_codex_dir/config.toml"
    }

    while IFS= read -r app_dir; do
      [[ -n "$app_dir" ]] || continue
      prepare_codex_home "$app_dir"
    done < <(find "${ideLib.homeDir}/.var/app" -maxdepth 1 -mindepth 1 -type d \( -name 'com.jetbrains.*' -o -name '${ideLib.codeStudioAppId}' \) 2>/dev/null | sort)
  '';

  home.activation.createJetbrainsHostHomeViews = lib.hm.dag.entryAfter [ "prepareFlatpakIdeCodexHomes" ] ''
    create_home_view() {
      local app_dir="$1"
      local view_dir="$app_dir/home"

      mkdir -p "$view_dir/.local"

      link_view_path() {
        local link_path="$1"
        local target="$2"

        if [[ -L "$link_path" ]]; then
          if [[ "$(readlink "$link_path")" == "$target" ]]; then
            return
          fi
          rm -f "$link_path"
        elif [[ -e "$link_path" ]]; then
          return
        fi

        ln -s "$target" "$link_path"
      }

      link_view_path "$view_dir/.config" "../config"
      link_view_path "$view_dir/.cache" "../cache"
      link_view_path "$view_dir/.java" "../.java"
      link_view_path "$view_dir/.codex" "../.local/share/codex"
      link_view_path "$view_dir/.local/share" "../../data"
      link_view_path "$view_dir/.local/state" "../../.local/state"
    }

    while IFS= read -r app_dir; do
      [[ -n "$app_dir" ]] || continue
      create_home_view "$app_dir"
    done < <(find "${ideLib.homeDir}/.var/app" -maxdepth 1 -mindepth 1 -type d -name 'com.jetbrains.*' 2>/dev/null | sort)
  '';
}
