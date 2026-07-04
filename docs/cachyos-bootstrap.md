# CachyOS Bootstrap

This is the fresh-machine path for recreating the current user environment on a
new CachyOS/Arch install.

## Ownership Model

Home Manager owns the reproducible user layer:

- shell tools and config
- Mango/DMS user config and helper scripts
- fonts, GTK, Plasma assets, portals, input method policy
- Flatpak integration and IDE sandbox policy
- user Podman quadlets such as Verdaccio

The host still owns compositor/session runtimes and system integration:

- `mangowc` / `mangowm-git`
- `dms-shell`
- `fcitx5` runtime and addons
- portal runtimes
- graphics, seat, login, display-manager, and polkit system pieces

This keeps migration fast without forcing fragile compositor and graphics-stack
integration through Nix on a non-NixOS host.

## Fresh Install Flow

Install Git and clone this repo:

```bash
sudo pacman -S --needed git
git clone https://github.com/PluxelJS/nix-config.git ~/.config/nix
```

Dry-run the bootstrap:

```bash
~/.config/nix/bootstrap/cachyos.sh
```

Apply the full desktop bootstrap:

```bash
~/.config/nix/bootstrap/cachyos.sh --apply --with-recommended
```

What it does:

- installs Nix through pacman when `nix` is missing
- enables `nix-daemon.service`
- installs `paru` when missing, using the repo package if available or
  `paru-bin` from AUR as a fallback
- installs required pacman packages for the selected profile
- installs required AUR packages such as `mangowc` and `dms-shell`
- runs the matching Home Manager flake output
- runs the verification script after switch

Useful variants:

```bash
~/.config/nix/bootstrap/cachyos.sh --apply --profile shell
~/.config/nix/bootstrap/cachyos.sh --apply --profile container
~/.config/nix/bootstrap/cachyos.sh --apply --no-switch
```

After the first bootstrap, log out and back in if the script added the user to
`nix-users`, then run:

```bash
~/.config/nix/scripts/verify-shell-migration.sh desktop
```

## Runtime Dependency Check

For an already prepared host, use the lower-level dependency checker:

```bash
~/.config/nix/scripts/install-arch-runtime-deps.sh
~/.config/nix/scripts/install-arch-runtime-deps.sh --apply
~/.config/nix/scripts/install-arch-runtime-deps.sh --apply --with-recommended
```

This checker is profile-aware and separates pacman packages from AUR packages.
