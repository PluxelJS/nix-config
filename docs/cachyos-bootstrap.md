# CachyOS Bootstrap

Fresh-machine path for recreating this environment on CachyOS/Arch.

## Layers

Bootstrap prepares three layers:

- **Host packages:** compositor/session runtimes and system integration from
  CachyOS/Arch repositories, with explicit AUR exceptions only when no reliable
  repo package is available.
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

Routine repair, Flatpak catch-up, cleanup, and verification are subcommands of
the same binary: `bootstrap/cachyos.sh deps`, `bootstrap/cachyos.sh flatpaks`,
`bootstrap/cachyos.sh cleanup`, and `bootstrap/cachyos.sh verify`.

## Fresh Install

On a pure CachyOS install, first update the host and install Git:

```bash
sudo pacman -Syu
sudo pacman -S --needed git
```

Clone the repo into the canonical path:

```bash
git clone https://github.com/PluxelJS/nix-config.git ~/.config/nix
cd ~/.config/nix
```

Dry-run the bootstrap:

```bash
bootstrap/cachyos.sh
```

Apply the desktop bootstrap:

```bash
bootstrap/cachyos.sh --apply
```

What it does:

- installs Nix through pacman and enables `nix-daemon.service`
- installs `paru` from the CachyOS repository when missing
- installs required repository packages and explicit AUR exceptions for the
  selected profile
- installs desktop helper packages, browser/download-manager packages,
  OpenRazer runtime packages, and selected desktop extras such as CopyQ and
  EasyEffects
- adds the current user to profile-required groups such as `openrazer`
- switches the matching Home Manager flake output
- defers Flathub apps plus the local Code Studio Flatpak package to an
  explicit catch-up command
- prints the verification command to run after the session has been refreshed

Useful variants:

```bash
~/.config/nix/bootstrap/cachyos.sh --apply --profile shell
~/.config/nix/bootstrap/cachyos.sh --apply --profile container
~/.config/nix/bootstrap/cachyos.sh --apply --minimal
~/.config/nix/bootstrap/cachyos.sh --apply --with-flatpaks
~/.config/nix/bootstrap/cachyos.sh --apply --no-switch
```

The default `--apply` path prioritizes the desktop base: host packages, Nix,
Home Manager, shell, WM/session config, portals, and theme/runtime files.
Install slower app-layer Flatpaks later with:

```bash
~/.config/nix/bootstrap/cachyos.sh flatpaks --apply
```

Use `--with-flatpaks` only when you explicitly want remote and local Flatpak app
installation to run in the same foreground bootstrap.

After the first bootstrap, log out and back in if the script added the user to
`nix-users` or profile-required hardware groups. Reboot if kernel modules were
installed or rebuilt, for example after installing `openrazer-driver-dkms`.
Then run:

```bash
~/.config/nix/bootstrap/cachyos.sh verify desktop
```

Expected first-run notes:

- `nix-users` membership may require a new login before Nix daemon operations
  work for the user.
- `openrazer` membership may require a new login before Razer devices are
  accessible.
- DKMS modules may require a reboot before the device stack is fully active.
- Code Studio is built from `bootstrap/codestudio/`; the pinned VS Code tarball
  is downloaded by `flatpak-builder` instead of being committed to git.

## Dependency Repair

For an already prepared host, use the lower-level dependency checker:

```bash
~/.config/nix/bootstrap/cachyos.sh deps
~/.config/nix/bootstrap/cachyos.sh deps --apply
~/.config/nix/bootstrap/cachyos.sh deps --apply --minimal
```

This checker is profile-aware and separates repository packages, explicit AUR
exceptions, desktop extras, and profile-required user groups.
