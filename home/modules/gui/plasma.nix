{ config, lib, pkgs, ... }:
let
  theme = config.ahdg.theme;
  runtime = theme.runtime;
  modes = runtime.modes;
  python3 = "${pkgs.python3}/bin/python3";
  colorSchemeName = runtime.kde.colorSchemeName;
  lookAndFeelName = runtime.kde.lookAndFeelName;
  auroraeThemeName = runtime.kde.auroraeThemeName;
  kdeFontValue = runtime.kde.fontValue;
  kdeFixedFontValue = runtime.kde.fixedFontValue;
in
lib.mkIf config.ahdg.features.gui {
  home.activation.removeLegacyPlasmaThemeArtifacts = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for target in \
      "${config.xdg.configHome}/color-schemes/${colorSchemeName}.colors" \
      "${config.xdg.dataHome}/color-schemes/${colorSchemeName}.colors" \
      "${config.xdg.dataHome}/plasma/look-and-feel/${lookAndFeelName}" \
      "${config.xdg.dataHome}/kpackage/generic/${lookAndFeelName}" \
      "${config.xdg.dataHome}/aurorae/themes/${auroraeThemeName}" \
      "${config.xdg.dataHome}/icons/Papirus-kanagawa" \
      "${config.xdg.dataHome}/icons/Catppuccin-Macchiato-Lavender-Cursors"
    do
      if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        rm -rf "$target"
      fi
    done
  '';

  home.activation.removeDeprecatedPlasmaThemeArtifacts = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    rm -rf \
      "${config.xdg.dataHome}/kpackage/generic/${lookAndFeelName}"
  '';

  home.activation.materializePlasmaThemeForFlatpak = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
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

    # Some KDE-aware Flatpaks only get config/data shares, not arbitrary store
    # paths. Keep the color scheme materialized in both locations.
    materialize_file "${config.xdg.configHome}/color-schemes/${modes.dark.kde.colorSchemeName}.colors"
    materialize_file "${config.xdg.dataHome}/color-schemes/${modes.dark.kde.colorSchemeName}.colors"
    materialize_file "${config.xdg.configHome}/color-schemes/${modes.light.kde.colorSchemeName}.colors"
    materialize_file "${config.xdg.dataHome}/color-schemes/${modes.light.kde.colorSchemeName}.colors"
  '';

  home.activation.removeUnusedQtctConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for target in \
      "${config.xdg.configHome}/qt5ct" \
      "${config.xdg.configHome}/qt6ct"
    do
      if [[ -e "$target" ]]; then
        rm -rf "$target"
      fi
    done
  '';

  home.activation.alignKdeglobalsThemeStack = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kdeglobals="${config.xdg.configHome}/kdeglobals"
    if [[ -f "$kdeglobals" ]]; then
      if ! rg -q '^\[General\]$' "$kdeglobals"; then
        printf '\n[General]\n' >> "$kdeglobals"
      fi
      if ! rg -q '^\[Icons\]$' "$kdeglobals"; then
        printf '\n[Icons]\n' >> "$kdeglobals"
      fi
      if ! rg -q '^\[KDE\]$' "$kdeglobals"; then
        printf '\n[KDE]\n' >> "$kdeglobals"
      fi
      if ! rg -q '^\[WM\]$' "$kdeglobals"; then
        printf '\n[WM]\n' >> "$kdeglobals"
      fi
      sed -i \
        -e '/^\[General\]/,/^\[/{s/^ColorScheme=.*/ColorScheme='"${colorSchemeName}"'/;}' \
        -e '/^\[General\]/,/^\[/{s#^TerminalApplication=.*#TerminalApplication='"${config.home.profileDirectory}"'/bin/ghostty --gtk-single-instance=true#;}' \
        -e '/^\[General\]/,/^\[/{s/^XftHintStyle=.*/XftHintStyle='"${theme.xftHintStyle}"'/;}' \
        -e '/^\[General\]/,/^\[/{s/^XftSubPixel=.*/XftSubPixel='"${theme.xftSubPixel}"'/;}' \
        -e '/^\[General\]/,/^\[/{s/^font=.*/font='"${kdeFontValue}"'/;}' \
        -e '/^\[General\]/,/^\[/{s/^menuFont=.*/menuFont='"${kdeFontValue}"'/;}' \
        -e '/^\[General\]/,/^\[/{s/^smallestReadableFont=.*/smallestReadableFont='"${kdeFontValue}"'/;}' \
        -e '/^\[General\]/,/^\[/{s/^toolBarFont=.*/toolBarFont='"${kdeFontValue}"'/;}' \
        -e '/^\[General\]/,/^\[/{s/^fixed=.*/fixed='"${kdeFixedFontValue}"'/;}' \
        -e '/^\[Icons\]/,/^\[/{s/^Theme=.*/Theme='"${runtime.icon.name}"'/;}' \
        -e '/^\[KDE\]/,/^\[/{s/^LookAndFeelPackage=.*/LookAndFeelPackage='"${lookAndFeelName}"'/;}' \
        -e '/^\[KDE\]/,/^\[/{s/^widgetStyle=.*/widgetStyle='"${runtime.kde.widgetStyle}"'/;}' \
        -e '/^\[WM\]/,/^\[/{s/^activeFont=.*/activeFont='"${kdeFontValue}"'/;}' \
        "$kdeglobals"

      "${python3}" - "$kdeglobals" \
        "${colorSchemeName}" \
        "${config.home.profileDirectory}/bin/ghostty --gtk-single-instance=true" \
        "${theme.xftHintStyle}" \
        "${theme.xftSubPixel}" \
        "${kdeFontValue}" \
        "${kdeFixedFontValue}" \
        "${runtime.icon.name}" \
        "${lookAndFeelName}" \
        "${runtime.kde.widgetStyle}" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()

required = {
    "[General]": {
        "ColorScheme": sys.argv[2],
        "TerminalApplication": sys.argv[3],
        "XftHintStyle": sys.argv[4],
        "XftSubPixel": sys.argv[5],
        "font": sys.argv[6],
        "menuFont": sys.argv[6],
        "smallestReadableFont": sys.argv[6],
        "toolBarFont": sys.argv[6],
        "fixed": sys.argv[7],
    },
    "[Icons]": {
        "Theme": sys.argv[8],
    },
    "[KDE]": {
        "LookAndFeelPackage": sys.argv[9],
        "widgetStyle": sys.argv[10],
    },
    "[WM]": {
        "activeFont": sys.argv[6],
    },
}

sections = {}
order = []
current = None
for line in text.splitlines():
    if line.startswith("[") and line.endswith("]"):
        current = line
        if current not in sections:
            sections[current] = []
            order.append(current)
    elif current is not None:
        sections[current].append(line)

for section, section_lines in list(sections.items()):
    normalized = []
    seen_nonempty = set()
    previous_blank = False
    for line in section_lines:
        if line == "":
            if previous_blank:
                continue
            normalized.append(line)
            previous_blank = True
            continue
        previous_blank = False
        if line in seen_nonempty:
            continue
        seen_nonempty.add(line)
        normalized.append(line)
    sections[section] = normalized

for section, kvs in required.items():
    if section not in sections:
        sections[section] = []
        order.append(section)
    section_lines = [
        line
        for line in sections[section]
        if "=" not in line or line.startswith("#") or line.split("=", 1)[0] not in kvs
    ]
    for key, value in kvs.items():
        section_lines.append(f"{key}={value}")
    sections[section] = section_lines

out = []
for index, section in enumerate(order):
    if index:
        out.append("")
    out.append(section)
    out.extend(sections[section])

path.write_text("\n".join(out).rstrip() + "\n")
PY

      "${python3}" - "$kdeglobals" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
sections = {}
order = []
current = None

for raw in path.read_text().splitlines():
    line = raw.rstrip()
    if line.startswith("[") and line.endswith("]"):
        current = line
        if current not in sections:
            sections[current] = []
            order.append(current)
        continue
    if current is None:
        continue
    sections[current].append(line)

dedupe_keys = {
    "[General]": {
        "ColorScheme",
        "TerminalApplication",
        "XftHintStyle",
        "XftSubPixel",
        "font",
        "menuFont",
        "smallestReadableFont",
        "toolBarFont",
        "fixed",
    },
    "[Icons]": { "Theme" },
    "[KDE]": { "LookAndFeelPackage", "widgetStyle" },
    "[WM]": { "activeFont" },
}

for section, keys in dedupe_keys.items():
    if section not in sections:
        continue
    cleaned = []
    seen = set()
    for line in reversed(sections[section]):
        if "=" in line and not line.startswith("#"):
            key = line.split("=", 1)[0]
            if key in keys:
                if key in seen:
                    continue
                seen.add(key)
        cleaned.append(line)
    sections[section] = list(reversed(cleaned))

out = []
for section in order:
    if out:
        out.append("")
    out.append(section)
    lines = sections[section]
    previous_blank = False
    for line in lines:
        if line == "":
            if previous_blank:
                continue
            previous_blank = True
            out.append(line)
            continue
        previous_blank = False
        out.append(line)

path.write_text("\n".join(out).rstrip() + "\n")
PY
    fi
  '';

  home.activation.alignKcminputrcThemeStack = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kcminputrc="${config.xdg.configHome}/kcminputrc"
    touch "$kcminputrc"
    if ! rg -q '^\[Mouse\]$' "$kcminputrc"; then
      printf '\n[Mouse]\n' >> "$kcminputrc"
    fi
      "${python3}" - "$kcminputrc" \
      "${runtime.cursor.name}" \
      "${toString runtime.cursor.size}" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
cursor_theme = sys.argv[2]
cursor_size = sys.argv[3]
text = path.read_text()
lines = text.splitlines()

sections = {}
order = []
current = None
for line in lines:
    if line.startswith("[") and line.endswith("]"):
        current = line
        if current not in sections:
            sections[current] = []
            order.append(current)
    elif current is not None:
        sections[current].append(line)

if "[Mouse]" not in sections:
    sections["[Mouse]"] = []
    order.append("[Mouse]")
mouse = [
    line
    for line in sections["[Mouse]"]
    if "=" not in line or line.startswith("#") or line.split("=", 1)[0] not in {"cursorTheme", "cursorSize"}
]
normalized_mouse = []
seen_mouse_lines = set()
previous_blank = False
for line in mouse:
    if line == "":
        if previous_blank:
            continue
        normalized_mouse.append(line)
        previous_blank = True
        continue
    previous_blank = False
    if line in seen_mouse_lines:
        continue
    seen_mouse_lines.add(line)
    normalized_mouse.append(line)
mouse = normalized_mouse

wanted = {
    "cursorTheme": cursor_theme,
    "cursorSize": cursor_size,
}
for key, value in wanted.items():
    mouse.append(f"{key}={value}")
sections["[Mouse]"] = mouse

out = []
for index, section in enumerate(order):
    if index:
        out.append("")
    out.append(section)
    out.extend(sections[section])

path.write_text("\n".join(out).rstrip() + "\n")
PY
  '';

  xdg.configFile = {
    "color-schemes/${modes.dark.kde.colorSchemeName}.colors" = {
      force = true;
      source = "${modes.dark.kde.package}/share/color-schemes/${modes.dark.kde.colorSchemeName}.colors";
    };

    "color-schemes/${modes.light.kde.colorSchemeName}.colors" = {
      force = true;
      source = "${modes.light.kde.package}/share/color-schemes/${modes.light.kde.colorSchemeName}.colors";
    };
  };

  xdg.dataFile = {
    "color-schemes/${modes.dark.kde.colorSchemeName}.colors" = {
      force = true;
      source = "${modes.dark.kde.package}/share/color-schemes/${modes.dark.kde.colorSchemeName}.colors";
    };
    "color-schemes/${modes.light.kde.colorSchemeName}.colors" = {
      force = true;
      source = "${modes.light.kde.package}/share/color-schemes/${modes.light.kde.colorSchemeName}.colors";
    };

    "plasma/look-and-feel/${modes.dark.kde.lookAndFeelName}" = {
      force = true;
      source = "${modes.dark.kde.package}/share/plasma/look-and-feel/${modes.dark.kde.lookAndFeelName}";
    };
    "plasma/look-and-feel/${modes.light.kde.lookAndFeelName}" = {
      force = true;
      source = "${modes.light.kde.package}/share/plasma/look-and-feel/${modes.light.kde.lookAndFeelName}";
    };

    "aurorae/themes/${modes.dark.kde.auroraeThemeName}" = {
      force = true;
      source = "${modes.dark.kde.package}/share/aurorae/themes/${modes.dark.kde.auroraeThemeName}";
    };
    "aurorae/themes/${modes.light.kde.auroraeThemeName}" = {
      force = true;
      source = "${modes.light.kde.package}/share/aurorae/themes/${modes.light.kde.auroraeThemeName}";
    };
  };
}
