# Operations

This document is the operator-facing reference for switching, cleanup,
validation, and runtime-state expectations.

## Normal Workflow

For both the first install and later idempotent reconciliation, use the root
entrypoint:

```bash
~/.config/nix/setup
```

Useful companion operations are `setup --check`, `setup --flatpaks`, and
`setup --verify`. The setup path installs or checks Nix, `paru`, host runtime
dependencies, and then runs the matching Home Manager switch. See
[docs/cachyos-bootstrap.md](cachyos-bootstrap.md) for the full flow.

## Direct Switch Commands

Routine Home Manager switches:

```bash
home-manager switch --flake ~/.config/nix#current --impure
home-manager switch --flake ~/.config/nix#current-shell --impure
home-manager switch --flake ~/.config/nix#current-container --impure
```

If `home-manager` is not installed globally:

```bash
nix run --impure ~/.config/nix#home-manager -- switch --flake ~/.config/nix#current -b pre-nix --impure
```

Build activation package only:

```bash
nix build ~/.config/nix#homeConfigurations.current.activationPackage --impure
```

## Proxy LLM Service

The desktop profile imports the official, lock-pinned Proxy-LLM-API Home
Manager module. Its package in the Nix store owns compose files and lifecycle
helpers; no `~/code/_ACode` checkout is needed after an optional one-time
migration. Startup is queued asynchronously so a slow image pull cannot block
Home Manager activation.

```bash
systemctl --user status proxy-llm.service
systemctl --user restart proxy-llm.service
journalctl --user-unit=proxy-llm.service --follow
proxy-llm status
proxy-llm secrets
```

Machine-local files live under `~/.local/state/proxy-llm/`: `.env`,
CLIProxyAPI config, OAuth credentials, logs, plugins, and generated sing-box
config. PostgreSQL, Dragonfly, and sing-box data use stable Podman named volumes
unless `.env` explicitly selects legacy bind directories. Back up both the
state directory and required named volumes while the service is stopped.

The upstream helper enables sing-box only when `.env` explicitly sets
`SINGBOX_NODE_URL` or `SINGBOX_CONFIG_PATH`. With neither value configured,
CLIProxyAPI connects directly and no sing-box container or proxy environment is
added. Use `proxy-llm` for initialization, status, updates, logs, login, and
proxy testing. For upstream development without changing `flake.lock`, build or
switch with `--override-input proxy-llm "git+file://$HOME/code/_ACode"`.

When upgrading a workstation that still runs from the old checkout, perform
the guarded one-time cutover before switching Home Manager:

```bash
PROXY_LLM_STATE_DIR="$HOME/.local/state/proxy-llm" \
  nix run ~/.config/nix#proxy-llm -- cutover "$HOME/code/_ACode"
```

The new packaged helper health-checks the running old stack before stopping
it, preserves its Compose project identity and rootless UID/GID data, and
automatically restores the old service on any failure.

Check or repair only the Arch-side runtime base:

```bash
~/.config/nix/bootstrap/cachyos.sh deps
~/.config/nix/bootstrap/cachyos.sh deps --apply
~/.config/nix/bootstrap/cachyos.sh deps --apply --minimal
```

Check or repair the LocalSend UFW application profile and TCP/UDP 53317 rules:

```bash
~/.config/nix/bootstrap/cachyos.sh firewall
~/.config/nix/bootstrap/cachyos.sh firewall --apply
```

## Performance Incident Recording

The desktop bootstrap installs the host `atop` package and enables its system
recorder. It captures whole-system and per-process CPU, memory, swap, disk, and
network accounting every 10 seconds. Daily raw logs live under
`/var/log/atop/`, and logs older than seven daily generations are removed by
the package's rotation timer. Ten-second `/proc` sampling has negligible CPU
cost on this workstation while remaining fine-grained enough to catch the
onset of memory reclaim or zram thrashing.

Check or repair only this policy:

```bash
~/.config/nix/bootstrap/cachyos.sh atop
~/.config/nix/bootstrap/cachyos.sh atop --apply
```

After a reboot, open the previous incident day's raw log and restrict playback
to the relevant window:

```bash
sudo atop -r /var/log/atop/atop_20260820 -b 15:30 -e 15:45
```

Useful playback keys are `t`/`T` for the next/previous sample, `c` for full
commands, `m` for memory, `d` for disk, `n` for network, and `q` to quit. For a
suspected memory-pressure incident, first compare process memory and swap in
the `m` view; high zram activity can consume CPU even when the leaking process
is not itself at 100% CPU.

Install or catch up slower Flatpak app installs after the desktop base is up:

```bash
~/.config/nix/bootstrap/cachyos.sh flatpaks --apply
```

Review GUI-edited config before importing it back into the Nix source tree:

```bash
~/.config/nix/bootstrap/cachyos.sh pull-gui-config
~/.config/nix/bootstrap/cachyos.sh pull-gui-config --apply
```

KDE defaults are seed-only. Restore them only through the explicit, backed-up
reset command:

```bash
ahdg-kde-config reset dolphin
ahdg-kde-config reset ark
ahdg-kde-config reset appearance
ahdg-kde-config reset all
```

Backups are written under `~/.local/state/ahdg/kde-config-backups/`. Ordinary
`home-manager switch` runs only `ahdg-kde-config seed`; it creates missing
files and migrates old Nix-store links to writable files, but never edits an
existing regular KDE config.

## Canonical Edit Paths

Canonical source files live here:

- `~/.config/nix/home/files/ghostty/config`
- `~/.config/nix/home/files/themes/ghostty/config-dankcolors`
  This is only the seed. The live runtime file stays writable at
  `~/.config/ghostty/config-dankcolors`.
- `~/.config/nix/home/files/fastfetch/config.jsonc`
- `~/.config/nix/home/files/starship/starship.toml`
- `~/.config/nix/home/files/zsh/interactive.zsh`
- `~/.config/nix/home/files/zsh/startup.zsh`
- `~/.config/nix/home/files/bin/abdm-launch`
- `~/.config/nix/home/files/bin/abdm-open`
- `~/.config/nix/home/files/bin/abdm-tray`
- `~/.config/nix/home/files/bin/protontricks-launch-mangohud`
- `~/.config/nix/home/assets/fonts/custom/`
- `~/.config/nix/home/files/fcitx5/config`
- `~/.config/nix/home/files/fcitx5/profile`
- `~/.config/nix/home/files/fcitx5/conf/`
- `~/.config/nix/home/files/fcitx5/rime/default.yaml`
- `~/.config/nix/home/files/fcitx5/rime/custom_phrase.txt`
- `~/.config/nix/home/files/fcitx5/rime/custom/`
- `~/.config/nix/home/files/dolphin/dolphinrc`
- `~/.config/nix/home/files/dolphin/dolphinui.rc`
- `~/.config/nix/home/files/kde/kdeglobals`
- `~/.config/nix/home/files/kde/kcminputrc`
- `~/.config/nix/home/files/kde/arkrc`
- `~/.config/nix/home/modules/gui/kde-runtime.nix`
- `~/.config/nix/home/modules/gui/kde-config.nix`
- `~/.config/nix/home/modules/gui/fontconfig.nix`
- `~/.config/nix/home/modules/gui/gtk.nix`
- `~/.config/nix/home/modules/gui/flatpak.nix`
- `~/.config/nix/home/modules/gui/desktop-apps.nix`
- `~/.config/nix/home/modules/gui/localsend.nix`
- `~/.config/nix/home/modules/podman/`
- `~/.config/nix/home/modules/xdg.nix`
- `~/.config/nix/home/modules/profile.nix`
- `~/.config/nix/docs/shortcut-policy.md`
- `~/.config/nix/docs/shell-shortcuts.md`
- `~/.config/nix/docs/gh-auth.md`
- `~/.config/nix/bootstrap/ufw/localsend`

Most files under `~/.config/<tool>/...` and `~/.local/share/...` are runtime
outputs. KDE GUI preferences are an intentional exception: their live writable
files are authoritative while applications edit them. Use `pull-gui-config`
to review and deliberately capture those choices as future-machine seeds.
KDE INI imports are normalized and omit generated hashes, Dolphin
version/timestamps, duplicate keys, excess blank lines, and Ark directory
history; Dolphin's XML toolbar/menu layout is imported as the user saved it.

Stable policy-style desktop config is generated directly in Nix modules for:

- fontconfig entrypoints, default stacks, and CSS generic-family mappings
- GTK 2/3 defaults and `xsettingsd`
- Flatpak global override
- `xdg-terminals.list`

## Flatpak Materialization Rule

Flatpak global overrides expose selected host XDG paths to sandboxed apps. A
path being exposed is not enough by itself: desktop libraries inside Flatpak can
silently miss store-backed symlinks even when `/nix/store` is also mounted.

For any path that a sandboxed toolkit or desktop library scans directly, keep
the runtime copy as a regular file or directory after `home-manager switch`.
This includes:

- fontconfig entrypoints and snippets under `~/.config/fontconfig/`
- GTK settings and GTK 4 theme files
- fcitx config, themes, and static Rime payloads
- icon, cursor, GTK theme, and Plasma color-scheme assets used by Flatpaks

Store symlinks are still acceptable for explicit toolchain/config mounts where
the app is expected to read exact paths and `/nix/store` is deliberately exposed,
for example IDE terminal access to shell config and Nix profile binaries. Fonts
from nixpkgs are discovered once through the Home Manager profile; Flatpak can
resolve them because both that profile and `/nix/store` are exposed read-only.

When adding a new path to `home/modules/gui/flatpak.nix`, decide whether it is a
scanned runtime asset or an explicit config/toolchain path. Scanned assets need
an activation materialization step and a verification check.

## Managed Runtime Paths

These runtime paths are owned by Home Manager or by activation steps driven
from this flake:

- `~/.config/ahdg/`
- `~/.config/atuin/config.toml`
- `~/.config/autostart/ahdg-*.desktop`
- `~/.config/fastfetch/`
- `~/.config/fcitx5/`
- `~/.config/fontconfig/`
- `~/.config/ghostty/config`
- `~/.config/git/config`
- `~/.config/gtk-3.0/settings.ini`
- `~/.config/gtk-4.0/`
- `~/.config/systemd/user/proxy-llm.service`
- `~/.config/starship/starship.toml`
- `~/.config/user-dirs.dirs`
- `~/.config/user-dirs.locale`
- `~/.config/xdg-desktop-portal/portals.conf`
- `~/.config/xdg-terminals.list`
- `~/.config/xsettingsd/xsettingsd.conf`
- `~/.config/zsh/.zshenv`
- `~/.config/zsh/.zshrc`
- `~/.local/share/aurorae/themes/CatppuccinMacchiato-Modern`
- `~/.local/share/color-schemes/CatppuccinMacchiatoLavender.colors`
- `~/.local/share/flatpak/overrides/global`
- `~/.local/share/fcitx5/themes/`
- `~/.local/share/icons/Bibata-Modern-Ice`
- `~/.local/share/icons/Papirus`
- `~/.local/share/icons/breeze`
- `~/.local/share/applications/mimeapps.list`
- `~/.local/share/plasma/look-and-feel/Catppuccin-Macchiato-Lavender`
- `~/.local/share/themes/Catppuccin-Macchiato`
- `~/.gtkrc-2.0`
- `~/.zshenv`

## Intentional Manual State

Some files remain outside strict Nix ownership on purpose:

- `~/.gitconfig`
  Git author name and email are machine-local. Activation only creates the
  writable file when missing and adds an include for the Nix-managed generic
  policy under `~/.config/git/config`.

- `~/.local/state/proxy-llm/` and its Podman volumes
  Proxy-LLM-API credentials, OAuth tokens, local configuration, logs, and
  databases remain writable machine state outside the Nix store.

- `~/.config/mimeapps.list`
  This is the writable, higher-priority MIME override layer used by desktop
  applications and user choices. Nix provides the reproducible fallback in
  `~/.local/share/applications/mimeapps.list`.
- `~/.config/ghostty/config-dankcolors`
  DMS still updates this file at runtime.
- `~/.config/kdeglobals`, `~/.config/kcminputrc`, `~/.config/arkrc`,
  `~/.config/dolphinrc`, and
  `~/.local/share/kxmlgui5/dolphin/dolphinui.rc`
  These are writable KDE UI state. Repo copies are defaults and capture
  targets, not continuously enforced files. GUI changes survive every switch.
- `~/.local/share/flatpak/overrides/<app-id>`
  App-specific Flatpak overrides are activation-managed regular files so they
  stay writable outside the Nix store while still following repo policy.
- `gh` keyring entries or fallback `~/.config/gh/hosts.yml`
  `gh` login remains local runtime state.
- `~/.local/share/fonts/`
  The `custom/` subtree is refreshed from the repo; extra manual fonts remain
  manual. Nixpkgs fonts are exposed through the Home Manager profile.
- `~/.local/share/fcitx5/rime/build/`
- `~/.local/share/fcitx5/rime/sync/`
- `~/.local/share/fcitx5/rime/*.userdb/`
- `~/.local/share/fcitx5/rime/user.yaml`
- `~/.local/share/fcitx5/rime/installation.yaml`
  These are live Rime runtime artifacts and remain writable.

## Flatpak IDE Rule

IDE Flatpaks follow one explicit split:

- host-side canonical source for read-only shared config
- host-side canonical source for CLI config that IDE terminals may edit
- app-private writable state inside `~/.var/app/<app-id>/`

Shared read-only config for IDE sandboxes should come from the host when it is
stable policy/config, for example:

- `~/.config/zsh`
- `~/.config/starship`
- `~/.config/atuin`
- `~/.config/git`
- `~/.gitconfig`
- the Home Manager / Nix profile bin dir and `/nix/store`

Shared IDE tool runtimes that are referenced by config must also be available
from that Home Manager / Nix profile. For example, Codex MCP servers in
`~/.codex/config.toml` use `npx`, so `node`, `npm`, and `npx` must resolve in
every managed IDE sandbox instead of only in one editor's private shim tree.

Shared writable config/login state for IDE sandboxes should also come from the
host when the tools are expected to edit it interactively, for example:

- `~/.codex` for Codex config writes. Codex persists `config.toml` with a
  temporary file and atomic rename, so a single-file Flatpak bind mount is not
  sufficient.
- `~/.config/opencode`
- `~/.config/gh`
- `~/.claude`
- `~/.continue`
- `~/.gemini`
- `~/.hapi`
- `~/.opencode`

Do not make a Flatpak app's private home the canonical source for shared config.
The IDE should read these paths directly from the host-visible home instead of
copying them into `~/.var/app/<app-id>/home`.

Keep app-private writable state in the sandbox, for example:

- `~/.vscode`, `~/.vscode-shared`
- Codex databases/logs/session state under app-private
  `$HOME/.local/share/codex`; `CODEX_HOME/config.toml` is a symlink to the
  shared host `~/.codex/config.toml`
- `.npm`, `.bun`
- app-local caches, plugin indexes, and editor-specific mutable state

Zed is the native Nix-managed IDE rather than a Flatpak. Its package and
nixGL wrapper are declared in `home/modules/gui/desktop-apps.nix`; writable
editor state remains under `~/.config/zed` and `~/.local/share/zed`.

`mise` is intentionally treated as environment/toolchain state rather than as a
pure shared config surface. Project-level `mise.toml` remains the canonical
tool-version declaration, while per-app `mise` runtime/cache/install state may
remain private when stronger isolation is desired.

## JetBrains Flatpak Rule

Installed `com.jetbrains.*` Flatpaks are managed automatically:

- force `Wayland` only
- never allow `X11` or `fallback-x11`
- never expose `ssh-auth` or `gpg-agent`
- keep shared shell/git/Codex config mounted from the host
- allow project writes under `~/code`
- allow sandbox access to `xdg-data/Trash` so IDE file deletes can use the host
  trash instead of only offering permanent deletion
- persist Java Preferences under the app-private `$HOME/.java`, which JetBrains
  uses for region and other `Prefs` state
- append every snippet from `home/files/jetbrains/vmoptions/` to each discovered
  `*64.vmoptions`
- seed the JetBrains region preference to `apac` when the app-private Java
  Preferences store has not created it yet
- read each installed product's `dataDirectoryName` from its Flatpak
  `product-info.json`, create the app-private config/data/cache roots and the
  exact versioned options directory before first launch, then seed app-level
  JetBrains defaults there:
  Maple Mono editor/console/terminal fonts, zh-CN locale, new UI, classic
  terminal engine, and the Nix profile zsh as terminal shell
- unpack `home/files/jetbrains/inputhelp.zip` into each app's private
  `config/JetBrains/inputhelp` directory and inject its `-javaagent`

This logic intentionally works by app discovery rather than by a hard-coded IDE
list. The activation step scans installed `com.jetbrains.*` Flatpaks for real
JetBrains config directories and only appends to vmoptions files that the IDE
has already created.

That design keeps ownership boundaries clear:

- JetBrains creates its own base vmoptions files under the Flatpak-managed XDG
  directories; Home Manager prepares the product/version options directory
  from package metadata, for example
  `~/.var/app/com.jetbrains.CLion/config/JetBrains`
- Home Manager applies sandbox policy and performs idempotent append-only
  customization on top
- Default seeding edits only app-level `options/*.xml` component fields. It does
  not copy project, workspace, or recent-project state between IDEs.

JetBrains uses Flatpak-managed XDG directories rather than the Code Studio-style
`~/.var/app/<app-id>/home` tree as the real storage boundary. For host-side
discoverability, activation creates a compatibility view under
`~/.var/app/<app-id>/home` with symlinks to the real app-private `config`,
`data`, `cache`, `.java`, `.local/state`, and Codex state paths. That view is
for inspection and tooling convenience; it is not the canonical storage layer.

`GTK_IM_MODULE`, `QT_IM_MODULE`, and `XMODIFIERS` are cleared for these IDE
sandboxes as an explicit compatibility workaround for the current JetBrains
Wayland runtimes on this machine.

## Runtime Expectations

After a successful switch:

- `~/.zshenv`, `~/.config/zsh/.zshenv`, and `~/.config/zsh/.zshrc` are Home
  Manager symlinks
- `~/.config/ghostty/config` is a Home Manager symlink when Ghostty is enabled
- `~/.config/ghostty/config-dankcolors` is a writable regular file when DMS
  runtime support is enabled
- `~/.config/fcitx5/config`, `profile`, and `conf/*.conf` are regular files
- `~/.gtkrc-2.0` is a regular file for Flatpak compatibility
- `~/.config/fontconfig/fonts.conf` is a regular file, not a store symlink
- `~/.config/fontconfig/conf.d/*.conf` snippets are regular files, not store
  symlinks
- `~/.config/mimeapps.list` is a writable regular override file, while
  `~/.local/share/applications/mimeapps.list` is the materialized Nix fallback
- `xdg-mime query default text/plain` resolves to `org.kde.kate.desktop`
- `~/.local/share/fonts/custom/` is a regular directory copied from the repo
- GTK themes, fcitx themes, icon themes, and Flatpak-facing Plasma/GTK assets
  are materialized as regular files or directories
- both Xcursor default locations inherit the configured cursor theme, and the
  XDG default file plus Flatpak-facing cursor assets are materialized
- `~/.local/share/fcitx5/rime/` contains a Nix-refreshed Wanxiang baseline plus
  writable runtime subtrees such as `build/`, `sync`, and `*.userdb/`
- `~/.gitconfig` is a writable machine-local identity and compatibility file
- KDE UI preference files are writable regular files, never store symlinks
- Dolphin, KDED, the KDE PolicyKit agent, KWallet, and every portal service
  resolve their `ExecStart` from `/nix/store`
- `XDG_MENU_PREFIX=plasma-`, and
  `~/.config/menus/plasma-applications.menu` pins the Nix Plasma menu, so
  KService cannot fall back to a stale Arch menu prefix
- the complete fcitx environment is imported into both the systemd user
  manager and the DBus activation environment during Home Manager activation
- the managed ABDM tray entry is the only active autostart entry; the vendor
  basename is declaratively shadowed with `Hidden=true`

The managed Plasma menu is XDG/KService infrastructure, not a KDE interface
preference. Appearance, layout, toolbar, mouse, Dolphin, and Ark settings remain
writable regular files and are not rewritten by `home-manager switch`.

## Package Cleanup

Use the cleanup helper in dry-run mode first:

```bash
~/.config/nix/bootstrap/cachyos.sh cleanup
~/.config/nix/bootstrap/cachyos.sh cleanup --apply
```

It is reverse-dependency aware and only proposes pacman removals that are safe
on this machine.

Intentionally kept outside that cleanup:

- `fcitx5`, `fcitx5-gtk`, `fcitx5-qt`, `fcitx5-rime`, `librime`,
  `librime-data`, because the fcitx runtime stays on the system side
- `zsh`, because the login shell still points at `/usr/bin/zsh`
- `dms-shell`, because the live Ghostty color overlay is still generated by DMS

## Validation

Run after switching and again after reboot:

```bash
~/.config/nix/bootstrap/cachyos.sh verify
```

Or target a specific deployment explicitly:

```bash
~/.config/nix/bootstrap/cachyos.sh verify shell
~/.config/nix/bootstrap/cachyos.sh verify container
```

The verifier decides most checks from
`~/.config/ahdg/enabled-features`, so custom feature mixes remain valid.
Successful checks are summarized by default; use `verify --verbose` when
diagnosing a machine and you need every individual result. Installed Flatpaks
that are undeclared or present in more than one installation are reported as
warnings: cleanup remains an explicit user decision because uninstalling an app
can also remove app-private data.
