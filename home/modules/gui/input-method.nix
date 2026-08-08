{
  config,
  lib,
  pkgs,
  ...
}:
let
  guiLib = import ./lib.nix { inherit lib; };
  catppuccinFcitx5Dir = "${pkgs.catppuccin-fcitx5}/share/fcitx5/themes";
  plasmaThemeDir = ../../files/fcitx5/themes/plasma;
  fcitxConfigFiles = [
    "config"
    "profile"
    "conf/classicui.conf"
    "conf/clipboard.conf"
    "conf/imselector.conf"
    "conf/notifications.conf"
    "conf/quickphrase.conf"
    "conf/wayland.conf"
    "conf/waylandim.conf"
  ];
  wanxiangRelease = "v15.13.0";
  wanxiangBase = pkgs.fetchurl {
    url = "https://github.com/amzxyz/rime-wanxiang/releases/download/${wanxiangRelease}/rime-wanxiang-base.zip";
    hash = "sha256-qCQupP57D66XPSbEWYhHjhw+d8b9LhtiXMZerQKTGqg=";
  };
  wanxiangGrammar = pkgs.fetchurl {
    url = "https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram";
    hash = "sha256-MW285vytIy2GebvKOdWmggyHCz/pVKW5jkg4remyqDE=";
  };

  rimeStaticPayload =
    pkgs.runCommandLocal "ahdg-rime-static-payload"
      {
        nativeBuildInputs = [ pkgs.unzip ];
      }
      ''
        mkdir -p "$out"

        unzip -q ${wanxiangBase} -d "$out"
        cp ${wanxiangGrammar} "$out/wanxiang-lts-zh-hans.gram"

        cp ${../../files/fcitx5/rime/default.yaml} "$out/default.yaml"
        cp ${../../files/fcitx5/rime/custom_phrase.txt} "$out/custom_phrase.txt"
        cp ${../../files/fcitx5/rime/custom/wanxiang.custom.yaml} "$out/custom/wanxiang.custom.yaml"
        cp ${../../files/fcitx5/rime/custom/wanxiang_english.custom.yaml} "$out/custom/wanxiang_english.custom.yaml"
        cp ${../../files/fcitx5/rime/custom/wanxiang_mixedcode.custom.yaml} "$out/custom/wanxiang_mixedcode.custom.yaml"
        cp ${../../files/fcitx5/rime/custom/wanxiang_reverse.custom.yaml} "$out/custom/wanxiang_reverse.custom.yaml"
      '';
in
lib.mkIf config.ahdg.features.gui {
  # Keep fcitx runtime ownership on the Arch side. Nix owns the policy layer:
  # config files, themes, Rime payloads, and desktop/session environment.
  home.sessionVariables = {
    INPUT_METHOD = "fcitx";
    GTK_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
    QT_IM_MODULE = "fcitx";
    QT_IM_MODULES = "wayland;fcitx";
    SDL_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
  };

  home.activation.prepareManagedInputMethodAssets = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    # These targets are materialized after linking for Flatpak compatibility.
    # Clear only the paths declared and recreated by this module.
    for target in \
      "${config.xdg.configHome}/fcitx5/config" \
      "${config.xdg.configHome}/fcitx5/profile" \
      "${config.xdg.configHome}/fcitx5/conf" \
      "${config.xdg.dataHome}/fcitx5/themes/plasma" \
      "${config.xdg.dataHome}/fcitx5/themes/catppuccin-macchiato-lavender" \
      "${config.xdg.dataHome}/fcitx5/themes/catppuccin-mocha-lavender"
    do
      if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        chmod -R u+w "$target" 2>/dev/null || true
        rm -rf "$target"
      fi
    done
  '';

  home.activation.materializeInputMethodForFlatpak = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${guiLib.materializeRuntimePaths {
      files = [
        "${config.xdg.configHome}/fcitx5/config"
        "${config.xdg.configHome}/fcitx5/profile"
      ];
    }}

    sync_dir() {
      local source=$1
      local target=$2

      if [[ ! -d "$source" ]]; then
        return
      fi

      if [[ -e "$target" ]]; then
        chmod -R u+w "$target" 2>/dev/null || true
        rm -rf "$target"
      fi

      mkdir -p "$(dirname "$target")"
      cp -aT "$source" "$target"
    }

    if [[ -d "${config.xdg.configHome}/fcitx5/conf" ]]; then
      for target in "${config.xdg.configHome}"/fcitx5/conf/*.conf; do
        [[ -e "$target" ]] || continue
        materialize_file "$target"
      done
    fi

    sync_dir "${plasmaThemeDir}" "${config.xdg.dataHome}/fcitx5/themes/plasma"
    sync_dir "${catppuccinFcitx5Dir}/catppuccin-macchiato-lavender" "${config.xdg.dataHome}/fcitx5/themes/catppuccin-macchiato-lavender"
    sync_dir "${catppuccinFcitx5Dir}/catppuccin-mocha-lavender" "${config.xdg.dataHome}/fcitx5/themes/catppuccin-mocha-lavender"
  '';

  home.activation.syncRimeStaticPayload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    target="${config.xdg.dataHome}/fcitx5/rime"
    source="${rimeStaticPayload}"

    mkdir -p "$target" "$target/custom" "$target/dicts" "$target/lua/data" "$target/lua/wanxiang"

    rm -f \
      "$target/README.md" \
      "$target/base-dicts.zip" \
      "$target/custom_phrase.txt" \
      "$target/default.yaml" \
      "$target/rime-wanxiang-base.zip" \
      "$target/version.txt" \
      "$target/wanxiang.dict.yaml" \
      "$target/wanxiang.schema.yaml" \
      "$target/wanxiang_algebra.yaml" \
      "$target/wanxiang_english.dict.yaml" \
      "$target/wanxiang_english.schema.yaml" \
      "$target/wanxiang_mixedcode.dict.yaml" \
      "$target/wanxiang_mixedcode.schema.yaml" \
      "$target/wanxiang_reverse.dict.yaml" \
      "$target/wanxiang_reverse.schema.yaml" \
      "$target/wanxiang_symbols.yaml" \
      "$target/wanxiang_t9.schema.yaml" \
      "$target/wanxiang-lts-zh-hans.gram" \
      "$target/weasel.yaml"

    if [[ -d "$target/custom" ]]; then
      find "$target/custom" -maxdepth 1 -type f \
        \( -name 'wanxiang*.custom.yaml' -o -name 'patch方法论.md' -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) \
        -delete
    fi

    if [[ -d "$target/dicts" ]]; then
      find "$target/dicts" -maxdepth 1 -type f -name '*.dict.yaml' -delete
    fi

    if [[ -d "$target/lua/data" ]]; then
      find "$target/lua/data" -maxdepth 1 -type f -delete
    fi

    if [[ -d "$target/lua/wanxiang" ]]; then
      find "$target/lua/wanxiang" -maxdepth 1 -type f -delete
    fi

    while IFS= read -r -d $'\0' path; do
      rel="''${path#$source/}"
      dest="$target/$rel"

      case "$rel" in
        README.md|rime-wanxiang-base.zip|base-dicts.zip|version.txt)
          continue
          ;;
        custom/*.png|custom/*.jpg|custom/*.jpeg|custom/*.md)
          continue
          ;;
      esac

      if [[ -d "$path" ]]; then
        mkdir -p "$dest"
      else
        install -Dm644 "$path" "$dest"
      fi
    done < <(find "$source" -mindepth 1 -print0)
  '';

  home.activation.transitionInputMethodRuntimeBackToSystem =
    lib.hm.dag.entryAfter [ "reloadSystemd" ]
      ''
        managed_service_path="${config.xdg.configHome}/systemd/user/fcitx5-daemon.service"
        current_fragment="$(systemctl --user show fcitx5-daemon.service -p FragmentPath --value 2>/dev/null || true)"

        if [[ "$current_fragment" == "$managed_service_path" ]]; then
          systemctl --user stop fcitx5-daemon.service >/dev/null 2>&1 || true
          systemctl --user reset-failed fcitx5-daemon.service >/dev/null 2>&1 || true
        fi

        if [[ -x /usr/bin/fcitx5 ]] && ! busctl --user status org.fcitx.Fcitx5 >/dev/null 2>&1; then
          /usr/bin/fcitx5 -d >/dev/null 2>&1 &
        fi
      '';

  xdg.configFile = lib.listToAttrs (
    map (
      relPath:
      lib.nameValuePair "fcitx5/${relPath}" {
        force = true;
        source = ../../files/fcitx5 + "/${relPath}";
      }
    ) fcitxConfigFiles
  );
}
