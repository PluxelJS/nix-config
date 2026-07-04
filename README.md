# Nix Home Manager Layout

This repo is the user-layer Home Manager flake for `ahdg` on `CachyOS/Arch`.
It owns reproducible user-space config, packages, and desktop-adjacent policy.
It does not try to be a full host-management repo.

## Scope

Primary areas owned here:

- shell tooling and interactive behavior
- CLI package set installed by Home Manager
- Ghostty, MangoWC user config, and helper scripts
- fonts, GTK, Plasma theme assets, and portal policy
- `fcitx5` config, themes, and pinned Rime payloads
- XDG defaults, MIME policy, and Flatpak host integration
- user-scoped Podman quadlets for explicitly managed local services

System-layer pieces such as the login manager, system desktop session, PAM,
and other root-owned services stay outside this repo.

For the detailed host/user split, read
[docs/system-boundary.md](/home/ahdg/.config/nix/docs/system-boundary.md).

## Ownership Summary

Canonical Nix-owned areas:

- shell behavior: `zsh`, `atuin`, `fzf`, `mise`, `starship`, `pay-respects`
- CLI tools: `git`, `gh`, `bat`, `delta`, `eza`, `fd`, `ripgrep`, `zoxide`
- desktop user config: `ghostty`, `mango`, XDG defaults, portal policy
- theme stack: GTK, Plasma assets, icons, cursors, font policy
- input method policy: `fcitx5` config, themes, Rime baseline payloads
- Flatpak-facing user integration: global override plus exposed theme/font data
- local user services: managed Podman quadlets such as Verdaccio

Intentionally not owned here:

- `/etc` and other root-owned paths
- systemd system units
- display managers such as `sddm` or `plasma-login-manager`
- the host-side Plasma/Mango session runtime itself
- mutable runtime overlays generated live by DMS
- unmanaged app-specific Flatpak overrides outside the explicit IDE policy
- local credential-store secrets and similar runtime auth state

For theme ownership details, read
[docs/theme-stack.md](/home/ahdg/.config/nix/docs/theme-stack.md).

## Quick Start

Fresh CachyOS machine:

```bash
sudo pacman -S --needed git
git clone https://github.com/PluxelJS/nix-config.git ~/.config/nix
~/.config/nix/scripts/bootstrap-cachyos.sh
~/.config/nix/scripts/bootstrap-cachyos.sh --apply --with-recommended
```

Switch configurations:

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

Operational details, cleanup flow, and validation live in
[docs/operations.md](/home/ahdg/.config/nix/docs/operations.md).
Fresh-machine bootstrap details live in
[docs/cachyos-bootstrap.md](/home/ahdg/.config/nix/docs/cachyos-bootstrap.md).

## Structure

- `flake.nix`: top-level Home Manager entrypoints
- `home/default.nix`: shared module root
- `home/modules/profile.nix`: base profiles plus feature overrides
- `home/modules/shell/`: shell behavior and CLI tooling
- `home/modules/gui/`: fonts, GTK, Plasma, input method, portals, Flatpak
- `home/modules/podman/`: user-scoped container quadlets
- `home/files/`: native-format config sources and small runtime seeds
- `docs/`: policy and operator docs
- `scripts/`: verification and host-side helper scripts

## Profiles

Base profiles:

- `desktop`: full workstation stack
- `shell`: shell stack plus fonts
- `container`: shell stack only

Feature control lives in `home/modules/profile.nix`:

- `ahdg.profile`: choose the base profile
- `ahdg.extraFeatures`: add features on top
- `ahdg.disabledFeatures`: subtract features from the base profile

Exported configurations:

- `ahdg`
- `ahdg-shell`
- `ahdg-container`

Activation writes resolved profile metadata to `~/.config/ahdg/`, which the
verification script uses for post-switch checks.

## Design Rules

- Keep system-layer ownership out of this repo.
- Keep app-native config in native formats under `home/files/` when that is
  materially easier to edit.
- Prefer official nixpkgs assets over vendored theme/icon/font payloads.
- Keep mutable runtime outputs writable when another tool owns them live.
- Prefer Nix ownership for stable theme selection and DMS ownership only for
  live runtime overlays.
- Prefer Nix-managed app themes only for apps whose runtime is also
  Nix-managed, with explicitly documented exceptions.

## Docs

- [docs/system-boundary.md](/home/ahdg/.config/nix/docs/system-boundary.md):
  host vs Home Manager ownership, required root/system rationale, host runtime
  dependencies
- [docs/cachyos-bootstrap.md](/home/ahdg/.config/nix/docs/cachyos-bootstrap.md):
  fresh CachyOS install flow, Nix/paru bootstrap, and host runtime setup
- [docs/theme-stack.md](/home/ahdg/.config/nix/docs/theme-stack.md):
  theme ownership between Nix and DMS
- [docs/operations.md](/home/ahdg/.config/nix/docs/operations.md):
  switch commands, cleanup, validation, runtime expectations, canonical edit
  paths
- [docs/shortcut-policy.md](/home/ahdg/.config/nix/docs/shortcut-policy.md):
  shortcut rules and cross-app decisions
- [docs/shell-shortcuts.md](/home/ahdg/.config/nix/docs/shell-shortcuts.md):
  actual shell shortcut cheatsheet
- [docs/gh-auth.md](/home/ahdg/.config/nix/docs/gh-auth.md):
  GitHub auth strategy
- [docs/prep-cleanup-plan.md](/home/ahdg/.config/nix/docs/prep-cleanup-plan.md):
  staging note for splitting large cleanup work into coherent commits
