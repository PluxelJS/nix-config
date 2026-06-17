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

## Host Runtime Dependencies

The current setup still expects a small system-side base outside Nix.

Needed from Arch repositories:

- `zsh`
  The login shell still resolves to `/usr/bin/zsh`.
- `fcitx5`
  The runtime itself intentionally stays system-owned.
- `fcitx5-gtk`
  GTK input method modules for non-Nix desktop apps.
- `fcitx5-qt`
  Qt input method plugins for non-Nix desktop apps.
- `fcitx5-rime`
  The Rime addon binary remains on the system side.
- `flatpak`
  Nix only manages the global override file.
- `xdg-desktop-portal-kde`
  The portal runtime itself is still host-managed.
- `mangowc` or `mangowm-git`
  The compositor/session binary still lives on the host side.
- `dms-shell`
  DMS runtime still lives on the host side.
- `wlr-randr`
  Used directly by the Mango config.
- `kservice`
  Provides `kbuildsycoca6` for the DMS startup path.
- `polkit-kde-agent`
  Still launched from the DMS startup path.
- `plasma-workspace`
  Provides `xembedsniproxy` for legacy tray bridge behavior.
- `pkgfile`
  Recommended for fast `pay-respects` package lookup on Arch.

Optional AUR packages:

- `paru` or `yay`
  Optional helper tools for AUR management.
- `zen-browser-bin`
  Optional if the current Mango browser hotkey target should stay unchanged.

Not required from pacman/AUR when Home Manager already provides them:

- `git`
- `fd`
- `ripgrep`
- old font/theme/icon packages that no host package still depends on

## Package-Repair Rule

- `f` / `fix` uses Arch-native package lookup on this machine
- long-lived tools that belong in the reproducible environment should still be
  added to this flake instead of installed ad hoc
- `paru` remains a manual AUR workflow tool, not the default package backend
