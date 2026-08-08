{ config, lib, ... }:
let
  ideLib = import ./lib.nix { inherit config lib; };
in
lib.mkIf config.ahdg.features.flatpak {
  home.activation.prepareFlatpakIdeToolHomes =
    lib.hm.dag.entryAfter [ "prepareFlatpakIdeHostCodexConfig" ]
      ''
            tool_home_paths=(
        ${ideLib.renderShellArrayItems ideLib.hostToolHomeDirs}
            )

            for rel_path in "''${tool_home_paths[@]}"; do
              mkdir -p '${ideLib.homeDir}'/"$rel_path"
            done
      '';
}
