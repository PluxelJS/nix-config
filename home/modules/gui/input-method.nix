{ config, lib, pkgs, ... }:
let
  catppuccinFcitx5Dir = "${pkgs.catppuccin-fcitx5}/share/fcitx5/themes";
  plasmaThemeDir = ../../files/fcitx5/themes/plasma;

  rimeStaticPayload = pkgs.runCommandLocal "ahdg-rime-static-payload" {
    nativeBuildInputs = [ pkgs.unzip ];
  } ''
    mkdir -p "$out"

    unzip -q ${pkgs.fetchurl {
      url = "https://github.com/amzxyz/rime_wanxiang/releases/download/v15.3.11/rime-wanxiang-base.zip";
      hash = "sha256-sZJY+Q2Le8gOIWR4PHmPK/bF5GtxfywXFk4ZMYgPVrk=";
    }} -d "$out"

    mkdir -p "$out/dicts"
    unzip -qo ${../../assets/fcitx5/base-dicts.zip} -d "$out/dicts"

    cp ${../../assets/fcitx5/wanxiang-lts-zh-hans.gram} "$out/wanxiang-lts-zh-hans.gram"

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
    QT_IM_MODULE = "fcitx";
    QT_IM_MODULES = "wayland;fcitx";
    SDL_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
  };

  home.activation.removeLegacyInputMethodArtifacts = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    legacy_autostart="${config.xdg.configHome}/autostart/org.fcitx.Fcitx5.desktop"

    if [[ -e "$legacy_autostart" || -L "$legacy_autostart" ]]; then
      rm -f "$legacy_autostart"
    fi

    for target in \
      "${config.xdg.configHome}/amzxyz" \
      "${config.xdg.configHome}/fcitx" \
      "${config.xdg.configHome}/fcitx5/config" \
      "${config.xdg.configHome}/fcitx5/profile" \
      "${config.xdg.configHome}/fcitx5/conf" \
      "${config.xdg.configHome}/ibus" \
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
    materialize_file() {
      local target=$1
      local resolved=

      if [[ ! -e "$target" ]]; then
        return
      fi

      resolved="$(readlink -f "$target" || true)"
      if [[ -n "$resolved" && "$resolved" != "$target" && -f "$resolved" ]]; then
        rm -f "$target"
        install -Dm644 "$resolved" "$target"
      fi
    }

    materialize_dir() {
      local target=$1
      local resolved=

      if [[ ! -e "$target" ]]; then
        return
      fi

      resolved="$(readlink -f "$target" || true)"
      if [[ -n "$resolved" && "$resolved" != "$target" && -d "$resolved" ]]; then
        rm -rf "$target"
        mkdir -p "$(dirname "$target")"
        cp -aT "$resolved" "$target"
      fi
    }

    materialize_file "${config.xdg.configHome}/fcitx5/config"
    materialize_file "${config.xdg.configHome}/fcitx5/profile"

    if [[ -d "${config.xdg.configHome}/fcitx5/conf" ]]; then
      for target in "${config.xdg.configHome}"/fcitx5/conf/*.conf; do
        [[ -e "$target" ]] || continue
        materialize_file "$target"
      done
    fi

    materialize_dir "${config.xdg.dataHome}/fcitx5/themes/plasma"
    materialize_dir "${config.xdg.dataHome}/fcitx5/themes/catppuccin-macchiato-lavender"
    materialize_dir "${config.xdg.dataHome}/fcitx5/themes/catppuccin-mocha-lavender"
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

  home.activation.alignKdeInputMethodDesktop = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kwinrc="${config.xdg.configHome}/kwinrc"
    if [[ -f "$kwinrc" ]]; then
      input_method_entry='InputMethod[$e]=/usr/share/applications/org.fcitx.Fcitx5.desktop'
      if grep -q '^\[Wayland\]' "$kwinrc"; then
        if grep -q '^\[Wayland\]' "$kwinrc" && grep -q '^InputMethod\[\$e\]=' "$kwinrc"; then
          sed -i \
            -e '/^\[Wayland\]/,/^\[/{s#^InputMethod\[\$e\]=.*#'"$input_method_entry"'#;}' \
            "$kwinrc"
        else
          printf '\n[Wayland]\n%s\n' "$input_method_entry" >> "$kwinrc"
        fi
      else
        printf '\n[Wayland]\n%s\n' "$input_method_entry" >> "$kwinrc"
      fi
    fi
  '';

  home.activation.transitionInputMethodRuntimeBackToSystem = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
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

  xdg.configFile = {
    "fcitx5/config" = {
      force = true;
      source = ../../files/fcitx5/config;
    };
    "fcitx5/profile" = {
      force = true;
      source = ../../files/fcitx5/profile;
    };
    "fcitx5/conf/classicui.conf" = {
      force = true;
      source = ../../files/fcitx5/conf/classicui.conf;
    };
    "fcitx5/conf/clipboard.conf" = {
      force = true;
      source = ../../files/fcitx5/conf/clipboard.conf;
    };
    "fcitx5/conf/imselector.conf" = {
      force = true;
      source = ../../files/fcitx5/conf/imselector.conf;
    };
    "fcitx5/conf/notifications.conf" = {
      force = true;
      source = ../../files/fcitx5/conf/notifications.conf;
    };
    "fcitx5/conf/quickphrase.conf" = {
      force = true;
      source = ../../files/fcitx5/conf/quickphrase.conf;
    };
    "fcitx5/conf/wayland.conf" = {
      force = true;
      source = ../../files/fcitx5/conf/wayland.conf;
    };
    "fcitx5/conf/waylandim.conf" = {
      force = true;
      source = ../../files/fcitx5/conf/waylandim.conf;
    };
  };

  xdg.dataFile = {
    "fcitx5/themes/plasma" = {
      force = true;
      source = plasmaThemeDir;
    };
    "fcitx5/themes/catppuccin-macchiato-lavender" = {
      force = true;
      source = "${catppuccinFcitx5Dir}/catppuccin-macchiato-lavender";
    };
    "fcitx5/themes/catppuccin-mocha-lavender" = {
      force = true;
      source = "${catppuccinFcitx5Dir}/catppuccin-mocha-lavender";
    };
  };
}
