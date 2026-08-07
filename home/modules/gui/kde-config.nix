{
  config,
  lib,
  pkgs,
  ...
}:
let
  kdeConfig =
    (pkgs.writeShellApplication {
      name = "ahdg-kde-config";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        usage() {
          cat >&2 <<'EOF'
        Usage:
          ahdg-kde-config seed
          ahdg-kde-config reset <dolphin|ark|appearance|all>

        seed only creates missing files and materializes old Nix-store links.
        reset is explicit, backs up existing files, and restores repo defaults.
        EOF
        }

        command="''${1:-}"
        scope="''${2:-all}"
        case "$command" in
          seed)
            scope=all
            ;;
          reset)
            case "$scope" in
              dolphin|ark|appearance|all) ;;
              *) usage; exit 2 ;;
            esac
            ;;
          *)
            usage
            exit 2
            ;;
        esac

        config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
        data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
        state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
        backup_root="$state_home/ahdg/kde-config-backups/$(date -u +%Y%m%dT%H%M%SZ)"
        reset_count=0

        backup_file() {
          target=$1
          label=$2
          if [ -e "$target" ] || [ -L "$target" ]; then
            install -dm755 "$backup_root/$(dirname "$label")"
            cp -a "$target" "$backup_root/$label"
            reset_count=$((reset_count + 1))
          fi
        }

        seed_file() {
          source=$1
          target=$2

          if [ -L "$target" ]; then
            resolved="$(readlink -f "$target" 2>/dev/null || true)"
            case "$resolved" in
              /nix/store/*)
                rm -f "$target"
                if [ -f "$resolved" ]; then
                  install -Dm644 "$resolved" "$target"
                  return
                fi
                ;;
            esac
          fi

          if [ ! -e "$target" ] && [ ! -L "$target" ]; then
            install -Dm644 "$source" "$target"
          fi
        }

        reset_file() {
          source=$1
          target=$2
          label=$3
          backup_file "$target" "$label"
          rm -f "$target"
          install -Dm644 "$source" "$target"
        }

        manage_file() {
          source=$1
          target=$2
          label=$3
          if [ "$command" = reset ]; then
            reset_file "$source" "$target" "$label"
          else
            seed_file "$source" "$target"
          fi
        }

        if [ "$scope" = dolphin ] || [ "$scope" = all ]; then
          manage_file ${lib.escapeShellArg (toString ../../files/dolphin/dolphinrc)} "$config_home/dolphinrc" config/dolphinrc
          manage_file ${lib.escapeShellArg (toString ../../files/dolphin/dolphinui.rc)} "$data_home/kxmlgui5/dolphin/dolphinui.rc" data/kxmlgui5/dolphin/dolphinui.rc
        fi

        if [ "$scope" = appearance ] || [ "$scope" = all ]; then
          manage_file ${lib.escapeShellArg (toString ../../files/kde/kdeglobals)} "$config_home/kdeglobals" config/kdeglobals
          manage_file ${lib.escapeShellArg (toString ../../files/kde/kcminputrc)} "$config_home/kcminputrc" config/kcminputrc
        fi

        if [ "$scope" = ark ] || [ "$scope" = all ]; then
          manage_file ${lib.escapeShellArg (toString ../../files/kde/arkrc)} "$config_home/arkrc" config/arkrc
        fi

        if [ "$command" = reset ] && [ "$reset_count" -gt 0 ]; then
          printf 'Previous KDE config backed up under %s\n' "$backup_root"
        fi
      '';
    }).overrideAttrs
      (_: {
        # This host-specific helper is tiny and references local seed files.
        # Building it locally avoids pointless remote-builder negotiation.
        preferLocalBuild = true;
      });
in
lib.mkIf config.ahdg.features.gui {
  # KDE configuration is intentionally mutable. Home Manager owns the default
  # seeds and the runtime binaries, never the live UI files. Existing regular
  # files are not edited during switch; reset must be requested explicitly.
  home.packages = [ kdeConfig ];

  home.activation.seedMutableKdeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.getExe kdeConfig} seed
  '';
}
