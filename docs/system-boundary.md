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

## System-Layer Examples

Examples on this machine:

- `sddm`
- `plasma-login-manager`
- `plasma-workspace`
- `kwin`
- system `polkit` integration
- system portal packaging/runtime selection

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
- integration: `flatpak`, `podman`, `xdg-desktop-portal`,
  `xdg-desktop-portal-kde`, `dbus`
- Mango/DMS helpers: `wlr-randr`, `kservice`, `polkit-kde-agent`,
  `plasma-workspace`, `gtk3`, `python`
- desktop extras: `ab-download-manager`, `baloo`, `blueman`, `copyq`,
  `dms-shell`, `dolphin`, `flatseal`, `libappindicator`,
  `libayatana-appindicator`, `pavucontrol`, `zen-browser-bin`
- workstation apps with trusted repo packages: `mangohud`, `podman-desktop`,
  `protontricks`, `steam`
- Razer runtime: `linux-cachyos-headers`, `openrazer-daemon`,
  `openrazer-driver-dkms`, `python-openrazer`; the desktop user must be in the
  `openrazer` group

AUR packages used by the desktop profile:

- `mangowm-git`
- `polychromatic`
- `clash-party-bin`, `peazip-qt-bin`, `wps-office-cn`,
  `wps-office-mime-cn`, `wps-office-mui-zh-cn`

These AUR packages remain explicit exceptions because they provide current
desktop behavior that is not equivalently available from the trusted repo set:
MangoWM commands, Polychromatic's OpenRazer UI, PeaZip's Dolphin service menu,
Mihomo Party's desktop/scheme handler, and WPS desktop/MIME integration.

Home Manager supplies the user tools and assets listed in `home/modules/`.
Host packages are still used when a binary is launched by the compositor,
display/session plumbing, or a root/system-owned service before the Nix profile
can be assumed.

Small user glue scripts such as `abdm-launch` and
`protontricks-launch-mangohud` are Home Manager-owned under `~/.local/bin`; the
large applications they call stay in the host package layer.

Desktop Flatpaks are handled by `bootstrap/cachyos.sh --apply`
when they are part of the current workflow or validation canaries.

## Package-Repair Rule

- `f` / `fix` uses Arch-native package lookup on this machine
- long-lived tools that belong in the reproducible environment should still be
  added to this flake instead of installed ad hoc
- `paru` remains a manual AUR workflow tool, not the default package backend
