# Operations

This document is the operator-facing reference for switching, cleanup,
validation, and runtime-state expectations.

## Switch Commands

```bash
home-manager switch --flake ~/.config/nix#ahdg
home-manager switch --flake ~/.config/nix#ahdg-shell
home-manager switch --flake ~/.config/nix#ahdg-container
```

If `home-manager` is not installed globally:

```bash
nix run github:nix-community/home-manager -- switch --flake ~/.config/nix#ahdg -b pre-nix
```

Build activation package only:

```bash
nix build ~/.config/nix#homeConfigurations.ahdg.activationPackage
```

Bootstrap the Arch-side runtime base:

```bash
~/.config/nix/scripts/install-arch-runtime-deps.sh
~/.config/nix/scripts/install-arch-runtime-deps.sh --apply
~/.config/nix/scripts/install-arch-runtime-deps.sh --apply --with-recommended
```

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
- `~/.config/nix/home/assets/fonts/custom/`
- `~/.config/nix/home/files/fcitx5/config`
- `~/.config/nix/home/files/fcitx5/profile`
- `~/.config/nix/home/files/fcitx5/conf/`
- `~/.config/nix/home/files/fcitx5/rime/default.yaml`
- `~/.config/nix/home/files/fcitx5/rime/custom_phrase.txt`
- `~/.config/nix/home/files/fcitx5/rime/custom/`
- `~/.config/nix/home/modules/gui/fontconfig.nix`
- `~/.config/nix/home/modules/gui/gtk.nix`
- `~/.config/nix/home/modules/gui/flatpak.nix`
- `~/.config/nix/home/modules/xdg.nix`
- `~/.config/nix/home/modules/profile.nix`
- `~/.config/nix/docs/shortcut-policy.md`
- `~/.config/nix/docs/shell-shortcuts.md`
- `~/.config/nix/docs/gh-auth.md`

The files under `~/.config/<tool>/...` and `~/.local/share/...` are runtime
outputs. They should exist after activation, but they are not the canonical
place to keep config.

Stable policy-style desktop config is generated directly in Nix modules for:

- fontconfig entrypoints and custom match rules
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
for example IDE terminal access to shell config and Nix profile binaries. Large
font package directories under `~/.local/share/fonts/nix/` also stay store-backed
because fontconfig resolves them through the mounted store and the real Flatpak
font check covers that behavior.

When adding a new path to `home/modules/gui/flatpak.nix`, decide whether it is a
scanned runtime asset or an explicit config/toolchain path. Scanned assets need
an activation materialization step and a verification check.

## Managed Runtime Paths

These runtime paths are owned by Home Manager or by activation steps driven
from this flake:

- `~/.config/ahdg/`
- `~/.config/atuin/config.toml`
- `~/.config/fastfetch/`
- `~/.config/fcitx5/`
- `~/.config/fontconfig/`
- `~/.config/ghostty/config`
- `~/.config/git/config`
- `~/.config/gtk-3.0/settings.ini`
- `~/.config/gtk-4.0/`
- `~/.config/mimeapps.list`
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
- `~/.local/share/fonts/nix/`
- `~/.local/share/icons/Bibata-Modern-Ice`
- `~/.local/share/icons/Papirus`
- `~/.local/share/icons/breeze`
- `~/.local/share/plasma/look-and-feel/Catppuccin-Macchiato-Lavender`
- `~/.local/share/themes/Catppuccin-Macchiato`
- `~/.gtkrc-2.0`
- `~/.zshenv`

## Intentional Manual State

Some files remain outside strict Nix ownership on purpose:

- `~/.config/ghostty/config-dankcolors`
  DMS still updates this file at runtime.
- `~/.local/share/flatpak/overrides/<app-id>`
  App-specific Flatpak overrides are activation-managed regular files so they
  stay writable outside the Nix store while still following repo policy.
- `gh` keyring entries or fallback `~/.config/gh/hosts.yml`
  `gh` login remains local runtime state.
- `~/.local/share/fonts/`
  The `nix/` subtree is Nix-managed; extra manual fonts remain manual.
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
- seed app-level JetBrains defaults for existing product config directories:
  Maple Mono editor/console/terminal fonts, zh-CN locale, new UI, classic
  terminal engine, and the Nix profile zsh as terminal shell
- unpack `home/files/jetbrains/inputhelp.zip` into each app's private
  `config/JetBrains/inputhelp` directory and inject its `-javaagent`

This logic intentionally works by app discovery rather than by a hard-coded IDE
list. The activation step scans installed `com.jetbrains.*` Flatpaks for real
JetBrains config directories and only appends to vmoptions files that the IDE
has already created.

That design keeps ownership boundaries clear:

- JetBrains creates its own product/version directories and base vmoptions files
  under the Flatpak-managed XDG directories, for example
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
- `~/.local/share/fonts/custom/` is a regular directory copied from the repo
- GTK themes, fcitx themes, icon themes, and Flatpak-facing Plasma/GTK assets
  are materialized as regular files or directories
- `~/.local/share/fcitx5/rime/` contains a Nix-refreshed Wanxiang baseline plus
  writable runtime subtrees such as `build/`, `sync`, and `*.userdb/`
- `~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-3.0/dank-colors.css` are gone
- `~/.config/autostart/org.fcitx.Fcitx5.desktop` should not exist
- `~/.config/environment.d/90-dms.conf` is gone
- `~/.gitconfig` exists as a compatibility entrypoint managed by Home Manager
- `~/.config/qt5ct` and `~/.config/qt6ct` are gone

## Package Cleanup

Use the cleanup helper in dry-run mode first:

```bash
~/.config/nix/scripts/cleanup-pacman-duplicates.sh
~/.config/nix/scripts/cleanup-pacman-duplicates.sh --apply
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
~/.config/nix/scripts/verify-shell-migration.sh
```

Or target a specific deployment explicitly:

```bash
~/.config/nix/scripts/verify-shell-migration.sh shell
~/.config/nix/scripts/verify-shell-migration.sh container
```

The verification script decides most checks from
`~/.config/ahdg/enabled-features`, so custom feature mixes remain valid.
