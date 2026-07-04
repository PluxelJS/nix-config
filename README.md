# Home Manager Config

User-layer Home Manager flake for `ahdg` on `CachyOS/Arch`.

It makes shell, desktop config, themes, Flatpak integration, and selected user
services reproducible. It intentionally does not manage the whole host.

## Model

Home Manager owns:

- shell tools and interactive behavior
- GUI config under `$HOME`, including Ghostty, Mango, XDG defaults, and portals
- fonts, GTK/Plasma theme assets, icon/cursor policy, and Flatpak-visible copies
- `fcitx5` config/theme/Rime data, while the runtime stays on the host
- user-scoped services such as the Verdaccio Podman quadlet

The host package manager owns:

- `/etc`, PAM, display managers, login/session plumbing, and systemd system units
- compositor/session runtimes such as MangoWC and DMS
- graphics, seat, portal runtime, input-method runtime, and polkit system pieces
- local credentials and app runtime state

## Quick Start

Fresh CachyOS machine:

```bash
sudo pacman -S --needed git
git clone https://github.com/PluxelJS/nix-config.git ~/.config/nix
~/.config/nix/bootstrap/cachyos.sh
~/.config/nix/bootstrap/cachyos.sh --apply --with-recommended
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

## Structure

- `flake.nix`: top-level Home Manager entrypoints
- `home/default.nix`: shared module root
- `home/modules/profile.nix`: base profiles plus feature overrides
- `home/modules/shell/`: shell behavior and CLI tooling
- `home/modules/gui/`: fonts, GTK, Plasma, input method, portals, Flatpak
- `home/modules/podman/`: user-scoped container quadlets
- `home/files/`: native-format config sources and small runtime seeds
- `bootstrap/`: fresh-machine bootstrap entrypoints
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

## Docs

- [docs/cachyos-bootstrap.md](/home/ahdg/.config/nix/docs/cachyos-bootstrap.md):
  fresh install flow, Nix/paru bootstrap, host packages, and recommended
  Flatpak canaries
- [docs/system-boundary.md](/home/ahdg/.config/nix/docs/system-boundary.md):
  host vs Home Manager ownership
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
