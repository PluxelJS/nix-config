# CachyOS Bootstrap

Fresh-machine path for recreating this environment on CachyOS/Arch.

## Layers

Bootstrap prepares three layers:

- **Host packages:** compositor/session runtimes, firewall policy, and system
  integration from CachyOS/Arch repositories, with explicit AUR exceptions only
  when no reliable repo package is available.
- **Home Manager:** reproducible user config, Nix packages, themes, Flatpak
  policy, and user services.
- **Desktop Flatpaks:** apps currently used on the workstation, including
  keybind targets, MIME defaults, IDE sandboxes, and validation canaries.

MangoWC, DMS, drivers, and system integration stay on CachyOS. KDE applications
and portal/user services form a coherent Nix-owned user runtime connected to
the host graphics stack through nixGL.

## Implementation

The fresh-machine logic is not embedded in large shell scripts. It is split into:

- `bootstrap/cachyos.toml`: declarative package, command, profile, and Flatpak
  policy
- `bootstrap/ufw/`: repo-owned UFW application profiles
- `bootstrap/atop/`: root-owned persistent sampling policy installed by the
  bootstrap
- `bootstrap/bin/cachyos-bootstrap`: committed Linux amd64 binary that can run
  immediately after `git clone`
- `tools/cachyos-bootstrap/`: Go source for the binary
- `bootstrap/cachyos.sh`: thin compatibility wrapper

Routine repair, performance recording, firewall policy, Flatpak catch-up, GUI
config import, cleanup, and verification are subcommands of the same binary:
`bootstrap/cachyos.sh deps`, `bootstrap/cachyos.sh atop`, `bootstrap/cachyos.sh firewall`,
`bootstrap/cachyos.sh flatpaks`, `bootstrap/cachyos.sh pull-gui-config`,
`bootstrap/cachyos.sh cleanup`, and `bootstrap/cachyos.sh verify`.

## Fresh Install

After CachyOS KDE has created the desktop user, run this as that user. The
installer adds Git when missing, clones the repository, or fast-forwards an
existing clean checkout, and then applies the desktop profile:

```bash
curl -fsSL https://raw.githubusercontent.com/PluxelJS/nix-config/main/bootstrap/install.sh | bash
```

Preview without changing the machine:

```bash
~/.config/nix/setup --check
```

If needed, update the host and install Git first:

```bash
sudo pacman -Syu
sudo pacman -S --needed git
```

Then rerun the clone-and-setup command above. The lower-level
`bootstrap/cachyos.sh` interface remains available for maintenance and custom
profile work, but is not required for a normal first install.

What it does:

- installs Nix through pacman, idempotently repairs its build users, runtime
  directories, and canonical store permissions, initializes the database when
  a fresh package install left it incomplete, enables `nix-daemon.service`, and
  verifies the daemon store before invoking the Home Manager CLI pinned by this
  repository's flake lock
- installs `paru` from the CachyOS repository when missing
- installs required repository packages and explicit AUR exceptions for the
  selected profile
- installs desktop helper packages, browser/download-manager packages,
  OpenRazer runtime packages, and host desktop extras such as EasyEffects;
  Dolphin, Ark, KDED, KDE utilities, KWallet, PolicyKit agent, and portals come
  from Home Manager
- adds the current user to profile-required groups such as `openrazer`
- installs LocalSend's UFW profile and allows TCP/UDP port 53317
- installs `atop`, records system and per-process state every 10 seconds,
  retains seven daily logs, and enables daily rotation
- switches the matching Home Manager flake output
- defers Flathub apps plus the local Code Studio Flatpak package to an
  explicit catch-up command
- prints the verification command to run after the session has been refreshed

The normal apply path is non-interactive after sudo authentication: pacman uses
the configured signed repositories, while paru is limited to the explicit AUR
allowlist in `bootstrap/cachyos.toml` and skips its interactive review screen.
Treat changes to that allowlist as code changes and review them before merging.

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

Check or repair only LocalSend's host firewall policy with:

```bash
~/.config/nix/bootstrap/cachyos.sh firewall
~/.config/nix/bootstrap/cachyos.sh firewall --apply
```

Check or repair only persistent performance sampling with:

```bash
~/.config/nix/bootstrap/cachyos.sh atop
~/.config/nix/bootstrap/cachyos.sh atop --apply
```

## GUI Config Import

Some GUI tools are easier to tune live. Import those changes back into the Nix
source tree with an explicit dry-run first:

```bash
~/.config/nix/bootstrap/cachyos.sh pull-gui-config
~/.config/nix/bootstrap/cachyos.sh pull-gui-config --apply
```

The import list is intentionally conservative: static Mango, Ghostty, KDE
appearance, Dolphin, Ark, and fcitx config files only. KDE INI files are
normalized and generated hashes, timestamps, duplicate keys, and recent
directory history are discarded. Runtime state such as DMS colors, `gh` auth,
KWallet, user dictionaries, app caches, Flatpak private state, and IDE project
history stays local.

After the first bootstrap, log out and back in if the script added the user to
`nix-users` or profile-required hardware groups. Reboot if kernel modules were
installed or rebuilt, for example after installing `openrazer-driver-dkms`.
Then run:

```bash
~/.config/nix/bootstrap/cachyos.sh verify desktop
```

Verification covers the active deployment and enabled services.

Git author identity is not stored in the repository. Configure it once per
account with `git config --global user.name ...` and
`git config --global user.email ...` when the machine will create commits.

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
