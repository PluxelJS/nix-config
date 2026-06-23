{ config, lib, ... }:
let
  ideLib = import ./lib.nix { inherit config lib; };
in
lib.mkIf config.ahdg.features.flatpak {
  home.activation.prepareFlatpakIdeToolHomes = lib.hm.dag.entryAfter [ "prepareFlatpakIdeHostCodexConfig" ] ''
    legacy_tool_home='${ideLib.homeDir}/.local/share/ide-flatpaks/home'
    tool_home_paths=(
${ideLib.renderShellArrayItems ideLib.hostToolHomeDirs}
    )

    merge_dir_contents() {
      local source_dir="$1"
      local target_dir="$2"

      [[ -d "$source_dir" ]] || return 0
      mkdir -p "$target_dir"
      cp -an "$source_dir/." "$target_dir/" 2>/dev/null || true
    }

    for rel_path in "''${tool_home_paths[@]}"; do
      host_path='${ideLib.homeDir}'/"$rel_path"
      mkdir -p "$host_path"
      merge_dir_contents "$legacy_tool_home/$rel_path" "$host_path"
    done

    cleanup_legacy_app_link() {
      local app_dir="$1"
      local rel_path="$2"
      local link_path="$app_dir/$rel_path"
      local target_path="$legacy_tool_home/$rel_path"

      if [[ -L "$link_path" && "$(readlink "$link_path")" == "$target_path" ]]; then
        rm -f "$link_path"
      fi
    }

    while IFS= read -r app_dir; do
      [[ -n "$app_dir" ]] || continue
      for rel_path in "''${tool_home_paths[@]}"; do
        cleanup_legacy_app_link "$app_dir" "$rel_path"
      done
    done < <(find "${ideLib.homeDir}/.var/app" -maxdepth 1 -mindepth 1 -type d \( -name 'com.jetbrains.*' -o -name '${ideLib.codeStudioAppId}' \) 2>/dev/null | sort)
  '';
}
