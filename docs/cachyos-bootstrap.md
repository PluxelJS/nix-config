# CachyOS Bootstrap

Fresh-machine path for recreating this environment on CachyOS/Arch.

## Layers

Bootstrap prepares three layers:

- **Host packages:** compositor/session runtimes and system integration from
  pacman/AUR.
- **Home Manager:** reproducible user config, Nix packages, themes, Flatpak
  policy, and user services.
- **Desktop Flatpaks:** apps currently used on the workstation, including
  keybind targets, MIME defaults, IDE sandboxes, and validation canaries.

This keeps migration fast without forcing MangoWC, DMS, or graphics/session
integration through Nix on a non-NixOS host.

## Implementation

The fresh-machine logic is not embedded in large shell scripts. It is split into:

- `bootstrap/cachyos.toml`: declarative package, command, profile, and Flatpak
  policy
- `bootstrap/bin/cachyos-bootstrap`: committed Linux amd64 binary that can run
  immediately after `git clone`
- `tools/cachyos-bootstrap/`: Go source for the binary
- `bootstrap/cachyos.sh`: thin compatibility wrapper

Routine repair, cleanup, and verification are subcommands of the same binary:
`bootstrap/cachyos.sh deps`, `bootstrap/cachyos.sh cleanup`, and
`bootstrap/cachyos.sh verify`.

## Fresh Install

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
~/.config/nix/bootstrap/cachyos.sh --apply
```

What it does:

- installs Nix through pacman and enables `nix-daemon.service`
- installs `paru` when missing, using a repo package if available or
  `paru-bin` from AUR as a fallback
- installs required pacman/AUR packages for the selected profile
- installs desktop helper packages, browser/download-manager packages, and the
  managed Flatpak app set
- switches the matching Home Manager flake output
- runs verification after switch

Useful variants:

```bash
~/.config/nix/bootstrap/cachyos.sh --apply --profile shell
~/.config/nix/bootstrap/cachyos.sh --apply --profile container
~/.config/nix/bootstrap/cachyos.sh --apply --minimal
~/.config/nix/bootstrap/cachyos.sh --apply --no-switch
```

After the first bootstrap, log out and back in if the script added the user to
`nix-users`, then run:

```bash
~/.config/nix/bootstrap/cachyos.sh verify desktop
```

## Dependency Repair

For an already prepared host, use the lower-level dependency checker:

```bash
~/.config/nix/bootstrap/cachyos.sh deps
~/.config/nix/bootstrap/cachyos.sh deps --apply
~/.config/nix/bootstrap/cachyos.sh deps --apply --minimal
```

This checker is profile-aware and separates pacman packages from AUR packages.
