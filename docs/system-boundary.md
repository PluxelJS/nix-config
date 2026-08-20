# System Boundary

This repo is intentionally a Home Manager user-layer repo, not a full
system-management repo.

The host is still administered as `CachyOS/Arch + Nix`, so the default rule
is:

- user scope goes in this flake
- system scope stays with the host package manager and root-owned config

## Why

This boundary is not about Nix lacking capability. Nix can manage system files
in other deployment shapes. The reason is that this repo is scoped to Home
Manager while the machine is not managed as NixOS.

Anything that needs one or more of the following should be treated as
system-layer and kept out of this repo:

- root-owned paths such as `/etc`
- systemd system units rather than `systemd --user`
- PAM integration
- display-manager or greeter startup
- seat, login-session, or boot-time service wiring
- host firewall rules

## System-Layer Examples

Examples on this machine:

- `sddm`
- `plasma-login-manager`
- `kwin`
- the system PolicyKit daemon and rules

Display-manager note:

- `sddm` and `plasma-login-manager` are not ordinary user apps
- they start before the user session
- they participate in system login flow
- they depend on root-owned config and system services

That makes them system-layer components even though they present a UI to the
user.

## User-Layer Examples

Things that do belong in this repo:

- `~/.config` app config
- user session environment variables
- user-facing theme assets
- per-user KDE/GTK settings
- Nix-owned KDE applications and user services
- user-scoped systemd services
- user-scoped Podman quadlets
- per-user Flatpak override policy for explicitly managed desktop/dev sandboxes

Flatpak note:

- per-app sandbox policy belongs here
- shared read-only config should usually stay in the host home and be mounted in
- sandbox-private mutable state should stay under `~/.var/app/<app-id>/`
- if a specific app needs a runtime workaround, keep it as a small app-local
  exception rather than introducing another generic wrapper layer

## Host Runtime Dependencies

The authoritative install/check path is:

```bash
~/.config/nix/bootstrap/cachyos.sh
~/.config/nix/bootstrap/cachyos.sh deps
```

The conceptual host package set is:

Needed from Arch repositories:

- baseline: `zsh`, `pkgfile`
- desktop runtime: `fcitx5`, `fcitx5-gtk`, `fcitx5-qt`, `fcitx5-rime`
- integration: `flatpak`, `podman`, `dbus`, `ufw`
- diagnostics: `atop`, with a root-owned recorder and daily log rotation
- Mango/DMS helpers: `wlr-randr`, `gtk3`, `python`
- desktop extras: `ab-download-manager`, `baloo`, `blueman`,
  `dms-shell`, `easyeffects`, `flatseal`, `libappindicator`,
  `libayatana-appindicator`, `pavucontrol`, `zen-browser-bin`
- workstation apps with trusted repo packages: `mangohud`, `podman-desktop`,
  `protontricks`, `steam`
- Razer runtime: `linux-cachyos-headers`, `openrazer-daemon`,
  `openrazer-driver-dkms`, `python-openrazer`; the desktop user must be in the
  `openrazer` group

The two indicator libraries are intentionally separate host dependencies:
`libappindicator` supports Clash Party, Polychromatic, and the ABDM tray, while
`libayatana-appindicator` keeps Lutris tray support available. Nix-managed
LocalSend uses its own store closure and does not consume either host package.

AUR packages used by the desktop profile:

- `mangowm-git`
- `polychromatic`
- `clash-party-bin`, `wps-office-cn`,
  `wps-office-mime-cn`, `wps-office-mui-zh-cn`

These AUR packages remain explicit exceptions because they provide current
desktop behavior that is not equivalently available from the trusted repo set:
MangoWM commands, Polychromatic's OpenRazer UI, Mihomo Party's desktop/scheme
handler, and WPS desktop/MIME integration. Kate is supplied by the Nix-managed
KDE runtime and owns the text editor desktop/MIME defaults.

Mango session startup is user-layer and Home Manager-owned:

- `~/.config/systemd/user/mango-session.target` defines the compositor session
  target started by Mango's `exec-once`
- Home Manager writes shared XDG autostart entries for ABDM tray, Mihomo Party,
  and browser warmup; Plasma consumes shared entries natively and Mango consumes
  the same files through `dex`. DMS and CopyQ run as `mango-session.target`
  user services so their IPC survives Home Manager switches. The managed CopyQ
  autostart entry is disabled because `copyq.service` owns the clipboard
  manager process. DMS's clipboard widget is hidden, and its backend tracking is
  disabled by an ordered one-shot service after the DMS backend becomes ready.
- Cachy-Update is the sole graphical update notifier. A hidden per-user desktop
  entry suppresses Shelly's legacy notification helper, avoiding duplicate
  checks and stale-settings errors during login.
- Mango-only XDG entries use the extension desktop ID `OnlyShowIn=X-Mango;`, while the compositor's
  `startup.conf` is reserved for one-shot session hardware helpers
- package-provided XDG autostart entries and unrelated user overrides remain
  host/user state; this flake owns only its `ahdg-*.desktop` entries and does
  not delete other files under `~/.config/autostart`

Home Manager supplies the user tools and assets listed in `home/modules/`.
The active KDE user stack is deliberately Nix-owned: Dolphin, Ark, KDED,
KIO/KService helpers, Plasma utilities, Darkly/Breeze, KWallet, the PolicyKit
agent, and all portal processes are selected from one flake. Explicit user
units and pinned DBus entries override equivalent Arch units so DBus search
order cannot silently mix implementations.
GPU-facing entrypoints use nixGL to reach the CachyOS Mesa/EGL driver without
virtualization or software-rendering overhead.

This does not move the hardware/session boundary into Home Manager. CachyOS
still owns the kernel, graphics and input drivers, Wayland compositor,
PipeWire, systemd/DBus, the system PolicyKit daemon, PAM, and the display
manager. Arch KDE packages may remain as dependencies or recovery tools, but
the managed user session does not select their executables.

KDE runtime ownership and KDE preference ownership are intentionally separate.
Nix owns packages, services, desktop entries, default seeds, and immutable
theme assets. Live `kdeglobals`, `kcminputrc`, `arkrc`, `dolphinrc`, and
`dolphinui.rc` are writable regular files. A Home Manager switch never replaces
or rewrites an existing live KDE preference file.

CopyQ, meatshell, and Zed are desktop-profile Home Manager packages. CopyQ owns
clipboard history with a 20,000-entry retention limit and no automatic expiry;
DMS clipboard tracking is explicitly disabled after the DMS backend starts.
CopyQ is pinned to 16.0.0 until nixpkgs catches up because that release line
fixes the long-running clipboard process leak. Ark and its 7z, RAR,
Unarchiver, and Info-ZIP backends belong to the coherent KDE runtime above;
meatshell is pinned to the verified upstream 0.6.10 release artifact;
GPU-backed meatshell and Zed launch through the CachyOS nixGL bridge.

Small user glue scripts such as `abdm-launch` and
`protontricks-launch-mangohud` are Home Manager-owned under `~/.local/bin`; the
large applications they call stay in the host package layer.

Persistent performance sampling is another deliberate split-boundary case.
The bootstrap installs the trusted-repository `atop` package, owns
`/etc/default/atop`, and enables its system service because complete process and
kernel accounting must start at boot and write under `/var/log/atop`. The
policy records every 10 seconds and retains seven daily logs. Home Manager does
not replace this with a user service, which would miss system processes and
fail when the desktop user manager is unhealthy.

Desktop Flatpaks are handled by `bootstrap/cachyos.sh --apply`
when they are part of the current workflow or validation canaries.

LocalSend is an explicit split-boundary case: Home Manager owns the application
package and launchers, while the bootstrap owns its UFW application profile and
the TCP/UDP 53317 host rules. Run `bootstrap/cachyos.sh firewall --apply` to
repair just that system-layer policy. Both sides follow the desktop profile's
independent `localsend` feature, so disabling the feature removes LocalSend
without coupling firewall policy to the rest of the GUI stack.

## Package-Repair Rule

- `f` / `fix` uses Arch-native package lookup on this machine
- long-lived tools that belong in the reproducible environment should still be
  added to this flake instead of installed ad hoc
- `paru` remains a manual AUR workflow tool, not the default package backend
