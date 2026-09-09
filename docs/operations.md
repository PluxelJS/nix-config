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

After the first installation, update to the latest published configuration and
apply it with:

```bash
nixup
```

This safely fetches and fast-forwards `~/.config/nix` to `origin/main`, reads
the active profile from `~/.config/ahdg/profile`, and then runs the matching
setup flow. Local changes or a diverged branch stop the update; the command
never stashes, overwrites, or creates a merge commit. Available updates can be
inspected without changing `HEAD` or switching a generation:

```bash
nixup --check
```

To update the checkout and switch only Home Manager, skipping host dependency
reconciliation:

```bash
nixup --home
```

To advance all flake inputs to their latest available revisions and switch
Home Manager without running pacman/paru, Flatpak, or other host reconciliation:

```bash
nixup --latest
```

This leaves the resulting `flake.lock` change in the checkout for review and
commit. It requires a clean checkout before starting, like the other updating
`nixup` modes.

To test local edits without committing, fetching, or updating inputs:

```bash
nixup --local
```

This switches only Home Manager using the active profile and a `path:` flake,
so untracked files are included too. It also works on a local branch without
an upstream remote. The default `nixup` keeps its clean-checkout requirement.

For plain `nixup`, “latest” means the latest published repository revision
together with its reviewed, committed `flake.lock`. Advancing nixpkgs, Home
Manager, and other flake inputs remains an explicit maintainer workflow using
`nixup --latest` (or `nix flake update` directly), followed by review and
testing before committing the new lock file.

On an existing checkout whose active generation predates `nixup`, the packaged
entrypoint can be invoked directly:

```bash
nix run --impure ~/.config/nix#nixup -- --check
```

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

## Dev Runtime

The desktop profile installs `dev-runtime` and queues `dev-runtime.service`
asynchronously. It is a rootless Podman Compose project, not a Podman pod:
services share one Compose network and stable service names while keeping
their own lifecycle, logs, ports, and health checks.

On a new machine the systemd unit starts the default development targets:

```bash
systemctl --user status dev-runtime.service
journalctl --user-unit=dev-runtime.service --follow
dev-runtime status
dev-runtime env
```

PostgreSQL and Dragonfly are enabled by default because they are broadly useful
development dependencies. They bind to `127.0.0.1:5432` and
`127.0.0.1:6379` by default, but they are still just local targets and can be
persistently disabled on a host. Machine-local settings live under
`~/.local/state/dev-runtime/`: `.env` controls ports, images, retention, and
credentials; `enabled` records the persistent target set. These files are local
state and do not follow Nix generations.

PostgreSQL is shared as one local container and one local cluster, but service
access is isolated by database and login role. The admin URL printed as
`DATABASE_URL` is for local maintenance. New local services should get their
own managed database instead of reusing the admin URL. New API uses its own
SQLite database and does not need this PostgreSQL instance.

```bash
dev-runtime pg-create my-service
dev-runtime pg-url my-service
dev-runtime pg-list
```

`pg-create` normalizes `my-service` to `my_service`, creates
`my_service_owner` with a generated password, creates `my_service` owned by
that role, and stores only the local metadata under
`~/.local/state/dev-runtime/postgres-databases/`. It starts PostgreSQL
transiently if needed, but it does not persistently enable PostgreSQL if this
host has disabled it. Dragonfly is a shared local cache service; use app-level
key prefixes for separation.

Persistent enablement controls what comes back after login or after
`dev-runtime.service` restarts:

```bash
dev-runtime disable postgres
dev-runtime disable dragonfly
dev-runtime enable postgres dragonfly
dev-runtime enable vmetrics
dev-runtime enable vlogs
dev-runtime enable --no-start new-api
dev-runtime disable vlogs
```

Transient start/stop does not rewrite `~/.local/state/dev-runtime/enabled`:

```bash
dev-runtime start vlogs
dev-runtime stop vlogs
```

New API is the local AI gateway, with a Web dashboard and persistent token
usage logs. It uses SQLite and has no PostgreSQL or Dragonfly dependency:

```bash
dev-runtime enable new-api
dev-runtime check new-api
dev-runtime logs new-api
dev-runtime restart new-api
```

Open `http://127.0.0.1:23000` for the dashboard; API clients use
`http://127.0.0.1:23000/v1`. On a fresh installation, complete the setup page,
choose self-use mode, add an OpenAI channel with the upstream origin (without
`/v1`), and create client tokens. The migrated machine retains its existing
client keys and uses the `admin` account with the previously chosen password.
Credentials are machine-local and are never stored in this repository.

`~/.local/state/dev-runtime/.env` controls `NEW_API_PORT`,
`NEW_API_BIND_ADDRESS`, `NEW_API_IMAGE`, `NEW_API_DATA_DIR`, and the generated
persistent `NEW_API_SESSION_SECRET`. The default is loopback port 23000 and
the pinned release `docker.io/calciumion/new-api:v0.13.2`. Image upgrades are
explicit: back up first, change `NEW_API_IMAGE`, then pull and restart.

SQLite data and consumption logs live in `~/.local/state/dev-runtime/new-api/`.
For local builds and tests, CPU admission rejection is disabled in the New API
admin settings: `performance_setting.monitor_cpu_threshold=0`. In v0.13.2,
zero disables the CPU check; the change applies live and persists in SQLite.
Memory and disk thresholds remain at their defaults. CPU saturation can still
increase latency, but no longer triggers the gateway's CPU-overload 503.

Container diagnostic logs are capped at 16 MB. Dashboard consumption records
are retained in SQLite until explicitly deleted. For a consistent backup,
stop `new-api`, copy its data directory to a private backup location, then
start it again. Preserve the session secret alongside the backup. Restore
with the same image version before attempting an upgrade.

The migration imports the upstream and nine models directly, without a second
proxy hop. Model and default-group multipliers are set to 1 for local quota
accounting;
cached tokens use weight 1, while output weights follow New API's effective
model rules (for example GPT-5.6 output uses 8 even if the stored completion
map says 1). The input baseline is $2 per million tokens, not a verified
upstream price list. The admin account initially had $200 of local credit. Administrators can add credit under
User Management; it does not fund the upstream API account. Earlier zero-priced
requests keep their original token records and zero cost. Configure actual
model prices before using these reports as an upstream billing estimate.
Existing Hub statistics are retained in the old PostgreSQL volume,
not merged into New API history.

PostgreSQL and Dragonfly remain independent development targets. Disabling
them preserves their data volumes. The old Hub target and CLI login commands have been retired.
CLIProxyAPI is available again as the independent `cliproxy` target, using web management. Their local state
and database volumes remain available for archival or manual rollback.

## Helper CLI Specs

Repository-owned helper CLIs use `usage.kdl` as their machine-readable command
spec. The Nix packages lint these specs during build and install generated zsh
and bash completion scripts. Current covered commands:

```bash
nixup --usage
dev-runtime --usage
```

`dev-runtime` completions include command, target, service, and
managed PostgreSQL database names. The managed database completion reads
`~/.local/state/dev-runtime/postgres-databases/` directly and does not start
containers.

## Gateway State

`dev-runtime.service` is the sole lifecycle owner for New API and enabled CLIProxyAPI. Machine-local
enablement is stored in `~/.local/state/dev-runtime/enabled`; `enable` and
`disable` persist it across login and Home Manager switches. Old gateway
credentials remain archived under `~/.local/state/proxy-llm/` and should be
protected like the New API SQLite database.

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
- `~/.config/systemd/user/dev-runtime.service`
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

- `~/.local/state/dev-runtime/` and its Podman volumes
  Development runtime enablement, ports, database credentials, and service data
  are machine-local. Nix installs the helper and unit; this directory decides
  which targets are active on the host.

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

## CLIProxyAPI with optional sing-box

```bash
dev-runtime enable cliproxy
dev-runtime ui cliproxy
dev-runtime check cliproxy
dev-runtime logs cliproxy
dev-runtime restart cliproxy
dev-runtime disable cliproxy
```

The target delegates to the upstream runtime package with state under
`~/.local/state/dev-runtime/cliproxy/`. It does not enable a second systemd unit.
The default local image is built from the official CLIProxyAPI Git source when
missing; accounts and configuration are managed at `http://127.0.0.1:8317/management.html`.
The `ui` command explicitly displays the separate management key.

Direct upstream access is the default. To use sing-box, set `SINGBOX_NODE_URL`
in the target's private `.env` and restart it. `check cliproxy` tests a real HTTP
request through sing-box from the CLIProxyAPI container. A failed probe prints
WARNING and leaves the service running. It does not silently change proxy
settings or retry model calls directly. Clear the link and restart, or choose
another proxy/direct access in the page. Per-account overrides remain under web
management. `SINGBOX_CHECK_URL` selects the probe destination.

Cloudflared is not enabled for this machine. New API and CLIProxyAPI join a
shared `<DEV_RUNTIME_PROJECT_NAME>-llm` network. New API can use
`http://cli-proxy-api:8317` as a channel origin, with a CLIProxyAPI API key and
model list. The management password is not a channel API key. Channel creation
is still explicit in New API; the two applications keep independent data and
can be enabled or stopped separately. The shared network is retained on down.

The `proxy-llm` flake input uses the published GitHub repository, pinned in
`flake.lock`. Use `nix flake update proxy-llm` to select a newer runtime helper;
the local development checkout is not required for deployment.
