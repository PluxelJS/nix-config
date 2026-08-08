{
  config,
  lib,
  pkgs,
  ...
}:
let
  guiLib = import ./lib.nix { inherit lib; };
  customFontSourceDir = ../../assets/fonts/custom;
  fontStacks = {
    sansSerif = [
      "Inter"
      "Source Han Sans SC"
      "Noto Color Emoji"
    ];
    serif = [
      "Source Han Serif SC"
      "Noto Color Emoji"
    ];
    monospace = [
      "Maple Mono NF CN"
      "Noto Color Emoji"
    ];
    emoji = [ "Noto Color Emoji" ];
  };
  mkStringElements =
    families: lib.concatMapStringsSep "\n" (family: "        <string>${family}</string>") families;
  mkGenericMapping = genericFamily: preferredFamilies: ''
        <match target="pattern">
          <test name="family" qual="any">
            <string>${genericFamily}</string>
          </test>
          <edit name="family" mode="assign" binding="same">
    ${mkStringElements preferredFamilies}
          </edit>
        </match>
  '';
  fontconfigEntrypointText = ''
    <?xml version='1.0' encoding='UTF-8'?>
    <!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>
    <fontconfig>
      <!-- Flatpak commonly loads only the user fontconfig entrypoint. Keep a
           simple top-level file so sandboxed apps also pick up the HM-managed
           conf.d snippets. -->
      <include ignore_missing="yes" prefix="xdg">fontconfig/conf.d</include>
    </fontconfig>
  '';
  uiFontMappingsText = ''
    <?xml version='1.0' encoding='UTF-8'?>
    <!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>
    <fontconfig>
      <description>Map CSS UI generic families to the desktop font stacks</description>
      <!-- Normalize only CSS UI generic requests. Assigning the matched family
           avoids fontconfig's generic-family classifier overriding ui-* aliases. -->
    ${mkGenericMapping "system-ui" fontStacks.sansSerif}
    ${mkGenericMapping "ui-sans-serif" fontStacks.sansSerif}
    ${mkGenericMapping "ui-serif" fontStacks.serif}
    ${mkGenericMapping "ui-monospace" fontStacks.monospace}
    ${mkGenericMapping "ui-rounded" fontStacks.sansSerif}
    </fontconfig>
  '';
in
lib.mkIf config.ahdg.features.fonts {
  home.activation.prepareManagedFontconfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    managed_fontconfig="${config.xdg.configHome}/fontconfig/fonts.conf"
    managed_fontconfig_dir="${config.xdg.configHome}/fontconfig/conf.d"
    if [[ -f "$managed_fontconfig" ]] && [[ ! -L "$managed_fontconfig" ]]; then
      rm -f "$managed_fontconfig"
    fi

    if [[ -d "$managed_fontconfig_dir" ]]; then
      find "$managed_fontconfig_dir" -maxdepth 1 -type f -name '*-hm-*.conf' -delete
    fi
  '';

  home.activation.syncCustomFontDropDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    custom_font_dir="${config.xdg.dataHome}/fonts/custom"
    custom_font_source="${customFontSourceDir}"

    if [[ -e "$custom_font_dir" ]] && [[ ! -L "$custom_font_dir" ]]; then
      chmod -R u+w "$custom_font_dir" 2>/dev/null || true
      rm -rf "$custom_font_dir"
    fi

    mkdir -p "$(dirname "$custom_font_dir")"
    cp -aT "$custom_font_source" "$custom_font_dir"
  '';

  home.activation.materializeFontconfigForFlatpak = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${guiLib.materializeRuntimePaths {
      files = [ "${config.xdg.configHome}/fontconfig/fonts.conf" ];
    }}

    while IFS= read -r target; do
      [[ -n "$target" ]] || continue
      materialize_file "$target"
    done < <(find "${config.xdg.configHome}/fontconfig/conf.d" -maxdepth 1 -type l -name '*-hm-*.conf' 2>/dev/null | sort)
  '';

  home.activation.refreshFontconfigCaches =
    lib.hm.dag.entryAfter
      [
        "installPackages"
        "materializeFontconfigForFlatpak"
        "syncCustomFontDropDir"
      ]
      ''
        rm -rf "${config.xdg.cacheHome}/fontconfig"

        if [[ -d "${config.home.homeDirectory}/.var/app" ]]; then
          find "${config.home.homeDirectory}/.var/app" \
            -mindepth 2 \
            -maxdepth 3 \
            -path '*/cache/fontconfig' \
            -exec rm -rf {} + 2>/dev/null || true
        fi

        ${pkgs.fontconfig}/bin/fc-cache -r -f >/dev/null 2>&1 || true
      '';

  xdg.configFile."fontconfig/fonts.conf" = {
    force = true;
    text = fontconfigEntrypointText;
  };

  fonts.fontconfig = {
    enable = true;

    antialiasing = true;
    hinting = "slight";
    subpixelRendering = "rgb";

    defaultFonts = fontStacks;

    configFile.ahdg-ui-font-mappings = {
      enable = true;
      priority = 53;
      text = uiFontMappingsText;
    };
  };
}
