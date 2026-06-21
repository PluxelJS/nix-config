{ config, lib, pkgs, ... }:
let
  customFontSourceDir = ../../assets/fonts/custom;
  fontconfigEntrypointText = ''
    <?xml version='1.0' encoding='UTF-8'?>
    <!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
    <fontconfig>
      <!-- Flatpak commonly loads only the user fontconfig entrypoint. Keep a
           simple top-level file so sandboxed apps also pick up the HM-managed
           conf.d snippets. -->
      <include ignore_missing="yes" prefix="xdg">fontconfig/conf.d</include>
    </fontconfig>
  '';
  customFontRulesText = ''
    <?xml version='1.0' encoding='UTF-8'?>
    <!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
    <fontconfig>
      <!-- Keep rendering predictable: no embedded bitmap takeover, no global autohint. -->
      <match target="font">
        <edit mode="assign" name="embeddedbitmap">
          <bool>false</bool>
        </edit>
        <edit mode="assign" name="lcdfilter">
          <const>lcdlight</const>
        </edit>
        <edit mode="assign" name="autohint">
          <bool>false</bool>
        </edit>
      </match>

      <!-- Only help the small-pixel CJK families you actually use. -->
      <match target="font">
        <test compare="less_eq" name="pixelsize">
          <double>18</double>
        </test>
        <test compare="eq" name="family">
          <string>Source Han Sans SC</string>
        </test>
        <edit mode="assign" name="autohint">
          <bool>true</bool>
        </edit>
      </match>

      <match target="font">
        <test compare="less_eq" name="pixelsize">
          <double>18</double>
        </test>
        <test compare="eq" name="family">
          <string>Source Han Serif SC</string>
        </test>
        <edit mode="assign" name="autohint">
          <bool>true</bool>
        </edit>
      </match>

      <match target="font">
        <test compare="less_eq" name="pixelsize">
          <double>18</double>
        </test>
        <test compare="eq" name="family">
          <string>TsangerJinKai01</string>
        </test>
        <edit mode="assign" name="autohint">
          <bool>true</bool>
        </edit>
      </match>

      <!-- Make ui-* generics explicit so toolkits converge on the same stack. -->
      <alias>
        <family>system-ui</family>
        <prefer>
          <family>Inter</family>
          <family>Source Han Sans SC</family>
        </prefer>
      </alias>

      <alias>
        <family>ui-sans-serif</family>
        <prefer>
          <family>Inter</family>
          <family>Source Han Sans SC</family>
        </prefer>
      </alias>

      <alias>
        <family>ui-serif</family>
        <prefer>
          <family>TsangerJinKai01</family>
          <family>Source Han Serif SC</family>
        </prefer>
      </alias>

      <alias>
        <family>ui-monospace</family>
        <prefer>
          <family>Maple Mono NF CN</family>
          <family>Source Han Sans SC</family>
        </prefer>
      </alias>

      <!-- In zh locales, keep Latin and digits anchored to Inter first. -->
      <match target="pattern">
        <test compare="eq" name="family" qual="any">
          <string>system-ui</string>
        </test>
        <edit binding="strong" mode="prepend" name="family">
          <string>Inter</string>
        </edit>
      </match>

      <match target="pattern">
        <test compare="eq" name="family" qual="any">
          <string>sans-serif</string>
        </test>
        <edit binding="strong" mode="prepend" name="family">
          <string>Inter</string>
        </edit>
      </match>

      <match target="pattern">
        <test compare="eq" name="family" qual="any">
          <string>ui-sans-serif</string>
        </test>
        <edit binding="strong" mode="prepend" name="family">
          <string>Inter</string>
        </edit>
      </match>

    </fontconfig>
  '';
in
lib.mkIf config.ahdg.features.fonts {
  home.activation.removeLegacyFontconfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    legacy_fontconfig="${config.xdg.configHome}/fontconfig/fonts.conf"
    legacy_fontconfig_dir="${config.xdg.configHome}/fontconfig/conf.d"
    managed_font_dir="${config.xdg.dataHome}/fonts/nix"
    if [[ -f "$legacy_fontconfig" ]] && [[ ! -L "$legacy_fontconfig" ]]; then
      rm -f "$legacy_fontconfig"
    fi

    if [[ -d "$legacy_fontconfig_dir" ]]; then
      find "$legacy_fontconfig_dir" -maxdepth 1 -type f -name '*.conf' -delete
    fi

    if [[ -e "$managed_font_dir" ]] && [[ ! -L "$managed_font_dir" ]]; then
      chmod -R u+w "$managed_font_dir" 2>/dev/null || true
      rm -rf "$managed_font_dir"
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
    target="${config.xdg.configHome}/fontconfig/fonts.conf"
    resolved="$(readlink -f "$target" || true)"

    if [[ -n "$resolved" && "$resolved" != "$target" && -f "$resolved" ]]; then
      rm -f "$target"
      install -Dm644 "$resolved" "$target"
    fi
  '';

  home.activation.refreshFontconfigCaches = lib.hm.dag.entryAfter [ "materializeFontconfigForFlatpak" ] ''
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

  xdg.dataFile = {
    "fonts/nix/inter" = {
      force = true;
      source = "${pkgs.inter}/share/fonts/truetype";
    };
    "fonts/nix/maple-mono-nf-cn" = {
      force = true;
      source = "${pkgs.maple-mono."NF-CN"}/share/fonts/truetype";
    };
    "fonts/nix/source-han-sans" = {
      force = true;
      source = "${pkgs.source-han-sans}/share/fonts/opentype/source-han-sans";
    };
    "fonts/nix/source-han-serif" = {
      force = true;
      source = "${pkgs.source-han-serif}/share/fonts/opentype/source-han-serif";
    };
    "fonts/nix/twitter-color-emoji" = {
      force = true;
      source = "${pkgs.twitter-color-emoji}/share/fonts/truetype";
    };
    "fonts/nix/noto-color-emoji" = {
      force = true;
      source = "${pkgs.noto-fonts-color-emoji}/share/fonts/noto";
    };
  };

  fonts.fontconfig = {
    enable = true;

    antialiasing = true;
    hinting = "slight";
    subpixelRendering = "rgb";

    defaultFonts = {
      sansSerif = [
        "Inter"
        "Source Han Sans SC"
      ];
      serif = [
        "TsangerJinKai01"
        "Source Han Serif SC"
      ];
      monospace = [
        "Maple Mono NF CN"
        "Source Han Sans SC"
      ];
      emoji = [
        "Twitter Color Emoji"
        "Noto Color Emoji"
      ];
    };

    configFile.ahdg-custom-font-rules = {
      enable = true;
      priority = 90;
      text = customFontRulesText;
    };
  };
}
