{ config, lib, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
  profileBinDir = "${homeDir}/.local/state/nix/profiles/profile/bin";
  profileZsh = "${profileBinDir}/zsh";
  shellQuote = lib.escapeShellArg;

  codeStudioAppId = "io.github.trumank.CodeStudio";
  codeStudioHomeDir = "${homeDir}/.var/app/${codeStudioAppId}/home";
  jetbrainsFilesDir = ../../files/jetbrains;
  inputhelp = ../../files/jetbrains/inputhelp.zip;

  sharedReadOnlyFilesystems = [
    "${homeDir}/.config/atuin:ro"
    "${homeDir}/.config/git:ro"
    "${homeDir}/.config/starship:ro"
    "${homeDir}/.config/zsh:ro"
    "${homeDir}/.gitconfig:ro"
    "${homeDir}/.local/state/nix/profiles:ro"
    "/nix/store:ro"
  ];

  sharedWritableFilesystems = [
    "${homeDir}/.claude:create"
    "${homeDir}/.codex/config.toml"
    "${homeDir}/.config/gh:create"
    "${homeDir}/.config/opencode:create"
    "${homeDir}/.continue:create"
    "${homeDir}/.gemini:create"
    "${homeDir}/.hapi:create"
    "${homeDir}/.opencode:create"
    "${homeDir}/code:create"
    "xdg-data/Trash:create"
  ];

  sharedFilesystems = sharedReadOnlyFilesystems ++ sharedWritableFilesystems;
  jetbrainsPersistDirs = [
    ".cache"
    ".codex"
    ".java"
    ".local"
  ];

  # Common PATH for JetBrains flatpak IDEs (CLion, PyCharm, etc.)
  jetbrainsPath =
    lib.concatStringsSep ":" [
      profileBinDir
      "${homeDir}/.local/bin"
      "/app/bin"
      "/usr/bin"
    ];

  # CodeStudio needs extra PATH entries
  codeStudioPath =
    lib.concatStringsSep ":" [
      "${codeStudioHomeDir}/.local/share/mise/shims"
      profileBinDir
      "${homeDir}/.local/bin"
      "${homeDir}/.bun/bin"
      "/app/bin"
      "/usr/bin"
      "${homeDir}/.var/app/${codeStudioAppId}/data/node_modules/bin"
    ];

  jetbrainsEnv = {
    FLATPAK_IDE_ENV = "1";
    GTK_IM_MODULE = "";
    PATH = jetbrainsPath;
    QT_IM_MODULE = "";
    QT_IM_MODULES = "wayland";
    SHELL = profileZsh;
    XMODIFIERS = "";
  };

  codeStudioPersistDirs = [
    ".bun"
    ".codex"
    ".local"
    ".npm"
    ".vscode"
    ".vscode-shared"
  ];

  sharedSecretTalkNames = [
    "org.freedesktop.secrets"
    "org.kde.kwalletd6"
    "org.kde.secretservicecompat"
  ];

  renderFlatpakArgs = args:
    lib.concatStringsSep " \\\n      " (map shellQuote args);

  renderShellArrayItems = args:
    lib.concatStringsSep "\n" (map (arg: "      ${shellQuote arg}") args);

  mkEnvArgs = env:
    lib.mapAttrsToList (name: value: "--env=${name}=${value}") env;

  mkOverrideArgs =
    {
      sockets ? [ ],
      noSockets ? [ ],
      talkNames ? [ ],
      filesystems ? [ ],
      noFilesystems ? [ ],
      persists ? [ ],
      env ? { },
    }:
    (map (value: "--socket=${value}") sockets)
    ++ (map (value: "--nosocket=${value}") noSockets)
    ++ (map (value: "--talk-name=${value}") talkNames)
    ++ (map (value: "--nofilesystem=${value}") noFilesystems)
    ++ (map (value: "--filesystem=${value}") filesystems)
    ++ (map (value: "--persist=${value}") persists)
    ++ mkEnvArgs env;

  mkOverrideCommand = appId: args:
    ''
      flatpak override --user --reset ${shellQuote appId}
      flatpak override --user \
        ${renderFlatpakArgs args} \
        ${shellQuote appId}
    '';

  jetbrainsOverrideArgs = mkOverrideArgs {
    sockets = [ "wayland" ];
    talkNames = sharedSecretTalkNames;
    noSockets = [
      "x11"
      "fallback-x11"
      "ssh-auth"
      "gpg-agent"
    ];
    noFilesystems = [ "host" ];
    filesystems = sharedFilesystems;
    persists = jetbrainsPersistDirs;
    env = jetbrainsEnv;
  };

  codeStudioOverride = mkOverrideCommand codeStudioAppId (mkOverrideArgs {
    noSockets = [
      "x11"
      "fallback-x11"
    ];
    talkNames = sharedSecretTalkNames;
    filesystems = sharedFilesystems;
    persists = codeStudioPersistDirs;
    env = {
      PATH = codeStudioPath;
    };
  });
in
lib.mkIf config.ahdg.features.flatpak {
  home.activation.manageFlatpakIdeOverrides = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if ! command -v flatpak >/dev/null 2>&1; then
      exit 0
    fi

    mkdir -p '${homeDir}/.codex'
    touch '${homeDir}/.codex/config.toml'

    apply_jetbrains_override() {
      local app_id="$1"
      local override_args=(
${renderShellArrayItems jetbrainsOverrideArgs}
      )

      flatpak override --user --reset "$app_id"
      flatpak override --user "''${override_args[@]}" "$app_id"
    }

    while IFS= read -r app_id; do
      [[ -n "$app_id" ]] || continue
      apply_jetbrains_override "$app_id"
    done < <(flatpak list --app --columns=application 2>/dev/null | grep '^com\.jetbrains\.' || true)

    ${codeStudioOverride}
  '';

  home.activation.installJetbrainsVmOptions = lib.hm.dag.entryAfter [ "manageFlatpakIdeOverrides" ] ''
    jetbrains_vmoptions_dir="${jetbrainsFilesDir}/vmoptions"

    append_unique_lines() {
      local snippet="$1"
      local target_file="$2"

      while IFS= read -r line || [[ -n "$line" ]]; do
        grep -Fxq -- "$line" "$target_file" || printf '%s\n' "$line" >> "$target_file"
      done < "$snippet"
    }

    if [[ -d "$jetbrains_vmoptions_dir" ]]; then
      while IFS= read -r target_file; do
        [[ -n "$target_file" ]] || continue
        while IFS= read -r snippet; do
          append_unique_lines "$snippet" "$target_file"
        done < <(find "$jetbrains_vmoptions_dir" -maxdepth 1 -type f -name '*.vmoptions' | sort)
      done < <(find "${homeDir}/.var/app" -path '*/config/JetBrains/*/*64.vmoptions' -type f 2>/dev/null | sort)
    fi
  '';

  home.activation.seedJetbrainsJavaPrefs = lib.hm.dag.entryAfter [ "manageFlatpakIdeOverrides" ] ''
    seed_region_pref() {
      local prefs_file="$1"

      if [[ -f "$prefs_file" ]] && grep -Fq 'key="code"' "$prefs_file"; then
        return
      fi

      mkdir -p "$(dirname "$prefs_file")"
      if [[ -f "$prefs_file" ]]; then
        sed -i '/<\/map>/i\  <entry key="code" value="apac"/>' "$prefs_file"
        return
      fi

      cat > "$prefs_file" <<'EOF'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE map SYSTEM "http://java.sun.com/dtd/preferences.dtd">
<map MAP_XML_VERSION="1.0">
  <entry key="code" value="apac"/>
</map>
EOF
    }

    while IFS= read -r app_dir; do
      [[ -n "$app_dir" ]] || continue
      seed_region_pref "$app_dir/.java/.userPrefs/jetbrains/region/prefs.xml"
    done < <(find "${homeDir}/.var/app" -maxdepth 1 -mindepth 1 -type d -name 'com.jetbrains.*' 2>/dev/null | sort)
  '';

  home.activation.seedJetbrainsIdeDefaults = lib.hm.dag.entryAfter [ "seedJetbrainsJavaPrefs" ] ''
    while IFS= read -r options_dir; do
      [[ -n "$options_dir" ]] || continue

      ${pkgs.python3}/bin/python3 - "$options_dir" "${profileZsh}" <<'PY'
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

options_dir = pathlib.Path(sys.argv[1])
shell_path = sys.argv[2]

font_family = "Maple Mono NF CN"
font_size = "13"
line_spacing = "1.35"
locale = "zh-CN"


def read_tree(path):
    if path.exists():
        try:
            return ET.parse(path)
        except ET.ParseError:
            print(f"skip invalid JetBrains XML: {path}", file=sys.stderr)
            return None

    root = ET.Element("application")
    return ET.ElementTree(root)


def indent(elem, level=0):
    i = "\n" + level * "  "
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = i + "  "
        for child in elem:
            indent(child, level + 1)
        if not child.tail or not child.tail.strip():
            child.tail = i
    if level and (not elem.tail or not elem.tail.strip()):
        elem.tail = i


def write_tree(tree, path):
    indent(tree.getroot())
    path.parent.mkdir(parents=True, exist_ok=True)
    tree.write(path, encoding="unicode", short_empty_elements=True)
    path.write_text(path.read_text() + "\n")


def component(root, name):
    for child in root.findall("component"):
        if child.get("name") == name:
            return child
    child = ET.SubElement(root, "component", {"name": name})
    return child


def option(comp, name, value, replace_values=()):
    for child in comp.findall("option"):
        if child.get("name") == name:
            current = child.get("value")
            if current is None or current in replace_values:
                child.set("value", value)
            return
    ET.SubElement(comp, "option", {"name": name, "value": value})


def entry(parent, key, value, replace_values=()):
    for child in parent.findall("entry"):
        if child.get("key") == key:
            current = child.get("value")
            if current is None or current in replace_values:
                child.set("value", value)
            return
    ET.SubElement(parent, "entry", {"key": key, "value": value})


def seed_font_file(filename, component_name):
    path = options_dir / filename
    tree = read_tree(path)
    if tree is None:
        return
    comp = component(tree.getroot(), component_name)
    option(comp, "VERSION", "1")
    option(comp, "FONT_FAMILY", font_family, replace_values=("", "JetBrains Mono", "Monospaced", "Monospace"))
    option(comp, "FONT_SIZE", font_size, replace_values=("", "12"))
    option(comp, "LINE_SPACING", line_spacing)
    write_tree(tree, path)


def seed_terminal():
    path = options_dir / "terminal.xml"
    default_shells = {"", "/bin/sh", "/usr/bin/sh", "/bin/bash", "/usr/bin/bash"}

    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "<application>\n"
            "  <component name=\"TerminalOptionsProvider\">\n"
            "    <option name=\"terminalEngine\" value=\"CLASSIC\" />\n"
            "    <option name=\"terminalEngineInRemDev\" value=\"CLASSIC\" />\n"
            f"    <option name=\"myShellPath\" value=\"{shell_path}\" />\n"
            "  </component>\n"
            "</application>\n"
        )
        return

    text = path.read_text()

    def replace_existing(match):
        current = match.group(2)
        if current in default_shells:
            return f'{match.group(1)}{shell_path}{match.group(3)}'
        return match.group(0)

    def seed_option_text(text, option_name, value, replace_values):
        option_text = f'    <option name="{option_name}" value="{value}" />'

        def replace_existing(match):
            current = match.group(2)
            if current in replace_values:
                return f'{match.group(1)}{value}{match.group(3)}'
            return match.group(0)

        updated, count = re.subn(
            rf'(<option\s+name="{re.escape(option_name)}"\s+value=")([^"]*)(")',
            replace_existing,
            text,
            count=1,
        )
        if count:
            return updated

        provider = re.search(
            r'(<component\s+name="TerminalOptionsProvider"[^>]*>)(.*?)(\n?\s*</component>)',
            text,
            flags=re.S,
        )
        if provider:
            return (
                text[: provider.start()]
                + provider.group(1)
                + provider.group(2).rstrip()
                + "\n"
                + option_text
                + provider.group(3)
                + text[provider.end() :]
            )

        if "</application>" not in text:
            print(f"skip terminal option seed without application root: {path}", file=sys.stderr)
            return text

        return text.replace(
            "</application>",
            "  <component name=\"TerminalOptionsProvider\">\n"
            f"{option_text}\n"
            "  </component>\n"
            "</application>",
            1,
        )

    updated, count = re.subn(
        r'(<option\s+name="myShellPath"\s+value=")([^"]*)(")',
        replace_existing,
        text,
        count=1,
    )
    if not count:
        updated = seed_option_text(updated, "myShellPath", shell_path, default_shells)

    updated = seed_option_text(updated, "terminalEngine", "CLASSIC", {"", "REWORKED"})
    updated = seed_option_text(updated, "terminalEngineInRemDev", "CLASSIC", {"", "REWORKED"})

    if updated != text:
        path.write_text(updated)


def seed_general():
    path = options_dir / "ide.general.xml"
    tree = read_tree(path)
    if tree is None:
        return
    root = tree.getroot()

    localization = component(root, "LocalizationStateService")
    option(localization, "lastSelectedLocale", locale)
    option(localization, "selectedLocale", locale)

    registry = component(root, "Registry")
    entry(registry, "ide.experimental.ui", "true")

    write_tree(tree, path)


seed_font_file("editor-font.xml", "DefaultFont")
seed_font_file("console-font.xml", "ConsoleFont")
seed_font_file("terminal-font.xml", "TerminalFontOptions")
seed_terminal()
seed_general()
PY
    done < <(find "${homeDir}/.var/app" -path '*/config/JetBrains/*/options' -type d 2>/dev/null | sort)
  '';

  home.activation.installInputhelp = lib.hm.dag.entryAfter [ "installJetbrainsVmOptions" ] ''
    while IFS= read -r app_dir; do
      [[ -n "$app_dir" ]] || continue

      inputhelp_dir="$app_dir/config/JetBrains/inputhelp"
      rm -rf "$inputhelp_dir"
      mkdir -p "$inputhelp_dir"
      unzip -qo '${inputhelp}' -d "$inputhelp_dir"

      while IFS= read -r vmopts; do
        [[ -n "$vmopts" ]] || continue
        sed -i '/^-javaagent:/d' "$vmopts"
        printf '%s\n' "-javaagent:$inputhelp_dir/inputhelp.jar=jetbrains" >> "$vmopts"
      done < <(find "$app_dir/config/JetBrains" -path '*/config/JetBrains/*/*64.vmoptions' -type f 2>/dev/null | sort)
    done < <(find "${homeDir}/.var/app" -maxdepth 1 -mindepth 1 -type d -name 'com.jetbrains.*' 2>/dev/null | sort)
  '';
}
