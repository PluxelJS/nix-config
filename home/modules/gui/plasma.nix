{ config, lib, pkgs, ... }:
let
  theme = config.ahdg.theme;
  runtime = theme.runtime;
  modes = runtime.modes;
  themeModes = [
    modes.dark
    modes.light
  ];
  python3 = "${pkgs.python3}/bin/python3";
  colorSchemeName = runtime.kde.colorSchemeName;
  lookAndFeelName = runtime.kde.lookAndFeelName;
  auroraeThemeName = runtime.kde.auroraeThemeName;
  kdeFontValue = runtime.kde.fontValue;
  kdeFixedFontValue = runtime.kde.fixedFontValue;
  legacyPlasmaArtifacts = [
    "${config.xdg.configHome}/color-schemes/${colorSchemeName}.colors"
    "${config.xdg.dataHome}/color-schemes/${colorSchemeName}.colors"
    "${config.xdg.dataHome}/plasma/look-and-feel/${lookAndFeelName}"
    "${config.xdg.dataHome}/kpackage/generic/${lookAndFeelName}"
    "${config.xdg.dataHome}/aurorae/themes/${auroraeThemeName}"
    "${config.xdg.dataHome}/icons/Papirus-kanagawa"
    "${config.xdg.dataHome}/icons/Catppuccin-Macchiato-Lavender-Cursors"
  ];
  materializedColorSchemeTargets =
    lib.concatMap (
      mode: [
        "${config.xdg.configHome}/color-schemes/${mode.kde.colorSchemeName}.colors"
        "${config.xdg.dataHome}/color-schemes/${mode.kde.colorSchemeName}.colors"
      ]
    ) themeModes;
  mkDataFile =
    name: source:
    lib.nameValuePair name {
      force = true;
      inherit source;
    };
  configColorSchemeFiles = map (
    mode:
    mkDataFile
      "color-schemes/${mode.kde.colorSchemeName}.colors"
      "${mode.kde.package}/share/color-schemes/${mode.kde.colorSchemeName}.colors"
  ) themeModes;
  dataThemeFiles =
    configColorSchemeFiles
    ++ map (
      mode:
      mkDataFile
        "plasma/look-and-feel/${mode.kde.lookAndFeelName}"
        "${mode.kde.package}/share/plasma/look-and-feel/${mode.kde.lookAndFeelName}"
    ) themeModes
    ++ map (
      mode:
      mkDataFile
        "aurorae/themes/${mode.kde.auroraeThemeName}"
        "${mode.kde.package}/share/aurorae/themes/${mode.kde.auroraeThemeName}"
    ) themeModes;
in
lib.mkIf config.ahdg.features.gui {
  home.activation.removeLegacyPlasmaThemeArtifacts = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for target in ${lib.escapeShellArgs legacyPlasmaArtifacts}; do
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
    for target in ${lib.escapeShellArgs materializedColorSchemeTargets}; do
      materialize_file "$target"
    done
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

  home.activation.initializeKdeglobalsThemeDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kdeglobals="${config.xdg.configHome}/kdeglobals"

    if [[ -L "$kdeglobals" ]]; then
      rm -f "$kdeglobals"
    fi

    install -dm755 "$(dirname "$kdeglobals")"

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
text = path.read_text() if path.exists() else ""

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
        continue
    if current is not None:
        sections[current].append(line)

for section, kvs in required.items():
    if section not in sections:
        sections[section] = []
        order.append(section)
    existing_keys = {
        line.split("=", 1)[0]
        for line in sections[section]
        if "=" in line and not line.startswith("#")
    }
    for key, value in kvs.items():
        if key not in existing_keys:
            sections[section].append(f"{key}={value}")

out = []
for index, section in enumerate(order):
    if index:
        out.append("")
    out.append(section)
    out.extend(sections[section])

path.write_text("\n".join(out).rstrip() + "\n")
PY
  '';

  home.activation.initializeKcminputrcThemeDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kcminputrc="${config.xdg.configHome}/kcminputrc"

    if [[ -L "$kcminputrc" ]]; then
      rm -f "$kcminputrc"
    fi

    install -dm755 "$(dirname "$kcminputrc")"

    "${python3}" - "$kcminputrc" \
      "${runtime.cursor.name}" \
      "${toString runtime.cursor.size}" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
cursor_theme = sys.argv[2]
cursor_size = sys.argv[3]
text = path.read_text() if path.exists() else ""

sections = {}
order = []
current = None
for line in text.splitlines():
    if line.startswith("[") and line.endswith("]"):
        current = line
        if current not in sections:
            sections[current] = []
            order.append(current)
        continue
    if current is not None:
        sections[current].append(line)

if "[Mouse]" not in sections:
    sections["[Mouse]"] = []
    order.append("[Mouse]")

existing_keys = {
    line.split("=", 1)[0]
    for line in sections["[Mouse]"]
    if "=" in line and not line.startswith("#")
}

if "cursorTheme" not in existing_keys:
    sections["[Mouse]"].append(f"cursorTheme={cursor_theme}")
if "cursorSize" not in existing_keys:
    sections["[Mouse]"].append(f"cursorSize={cursor_size}")

out = []
for index, section in enumerate(order):
    if index:
        out.append("")
    out.append(section)
    out.extend(sections[section])

path.write_text("\n".join(out).rstrip() + "\n")
PY
  '';

  xdg.configFile = lib.listToAttrs configColorSchemeFiles;
  xdg.dataFile = lib.listToAttrs dataThemeFiles;
}
