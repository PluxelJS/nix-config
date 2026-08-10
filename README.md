# Home Manager Config

User-layer Home Manager flake for a `CachyOS/Arch` workstation. The portable
outputs resolve the current username and home directory at evaluation time.

It makes shell, desktop config, themes, Flatpak integration, and selected user
services reproducible. It intentionally does not manage the whole host.

## Model

Home Manager owns:

- shell tools and interactive behavior
- GUI config under `$HOME`, including Ghostty, Mango, XDG defaults, and portals
- a coherent Nix-owned KDE user runtime: Dolphin, Ark, KDED, KIO/KService
  helpers, KWallet, PolicyKit agent, themes, and portal services
- fonts, GTK/Plasma theme assets, icon/cursor policy, and Flatpak-visible copies
- `fcitx5` config/theme/Rime data, while the runtime stays on the host
- the user-scoped Proxy LLM Podman compose stack
- LocalSend from Nixpkgs, wrapped for the CachyOS graphics stack

The host package manager owns:

- `/etc`, PAM, display managers, login/session plumbing, and systemd system units
- compositor/session runtimes such as MangoWC and DMS
- graphics, seat, input-method runtime, and PolicyKit/system plumbing
- local credentials and app runtime state
- host firewall state; the bootstrap applies repo-owned UFW profiles

## Quick Start

After the normal x86_64 CachyOS + KDE installer has created your desktop user,
open a terminal as that user and run the self-updating installer. It installs
Git when needed and then hands off to the idempotent setup flow:

```bash
curl -fsSL https://raw.githubusercontent.com/PluxelJS/nix-config/main/bootstrap/install.sh | bash
```

`setup` is idempotent, defaults to the desktop profile, and may be rerun after
config updates. To inspect the planned work first:

```bash
~/.config/nix/setup --check
```

The normal first run is unattended apart from sudo authentication. Repository
packages and the repository's explicit AUR package allowlist use non-interactive
installation; an error stops the flow instead of asking for a package-management
decision mid-bootstrap.

The equivalent manual path is:

```bash
sudo pacman -S --needed git
git clone https://github.com/PluxelJS/nix-config.git ~/.config/nix
~/.config/nix/setup
```

Re-running the remote installer fast-forwards an existing clean checkout and
reconciles the machine. Local repository changes are never overwritten.

The default apply path prioritizes the usable desktop base and defers slower
Flatpak app downloads. Catch up those apps later:

```bash
~/.config/nix/setup --flatpaks
```

Then log out and back in if the bootstrap added `nix-users` or hardware access
groups such as `openrazer`, reboot if DKMS/kernel modules were installed, and
validate:

```bash
~/.config/nix/setup --verify
```

Git author identity is intentionally machine-local and is never copied from
this repository. Configure it once on a new account:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Switch configurations:

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

The desktop profile consumes the official Proxy-LLM-API flake and starts its
packaged helper through `proxy-llm.service`; a source checkout is not required.
The lock file pins the tested upstream module and compose behavior, while local
credentials and runtime state stay writable outside the store. See
[docs/operations.md](docs/operations.md).

## Structure

- `flake.nix`: top-level Home Manager entrypoints
- `home/default.nix`: shared module root
- `home/modules/profile.nix`: base profiles plus feature overrides
- `home/modules/shell/`: shell behavior and CLI tooling
- `home/modules/gui/`: fonts, GTK, Plasma, input method, portals, Flatpak, LocalSend
- `home/modules/podman/`: user-scoped Podman client/runtime defaults
- `home/files/`: native-format config sources and small runtime seeds
- `setup`: clone-and-run entrypoint for the normal CachyOS KDE scenario
- `bootstrap/`: advanced fresh-machine binary, config, and shell entrypoint
- `tools/cachyos-bootstrap/`: Go source for the bootstrap binary
- `docs/`: policy and operator docs

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

- `current`, `current-shell`, `current-container`: portable outputs for the
  invoking account; use them with `--impure`

The portable outputs do not carry a Linux account or Git author identity. The
desktop/app selection remains opinionated, so review `bootstrap/cachyos.toml`
before giving the full desktop profile to another person.

Before publishing or handing the repo to someone else, also review the Rime
custom phrase files, custom font redistribution terms, enabled Podman services,
hardware packages/groups, and proprietary/AUR/Flatpak app lists. Credentials,
KWallet, GitHub auth, databases, and other runtime state are intentionally not
stored here.

Activation writes resolved profile metadata to `~/.config/ahdg/`, which the
bootstrap verifier uses for post-switch checks.

KDE interface files remain writable user state. Home Manager only seeds them
when missing; it never locks or overwrites existing GUI choices. Use
`pull-gui-config` to capture live choices back into the repo, and
`ahdg-kde-config reset ...` only for an explicit backed-up restore.

## Docs

- [docs/cachyos-bootstrap.md](docs/cachyos-bootstrap.md):
  fresh install flow, Nix/paru bootstrap, host packages, and desktop Flatpaks
- [docs/system-boundary.md](docs/system-boundary.md):
  host vs Home Manager ownership
- [docs/theme-stack.md](docs/theme-stack.md):
  theme ownership between Nix and DMS
- [docs/operations.md](docs/operations.md):
  switch commands, cleanup, validation, runtime expectations, canonical edit
  paths
- [docs/reproducibility.md](docs/reproducibility.md):
  locked resources, Rime model integrity, rolling host boundaries, and local state
- [docs/shortcut-policy.md](docs/shortcut-policy.md):
  shortcut rules and cross-app decisions
- [docs/shell-shortcuts.md](docs/shell-shortcuts.md):
  actual shell shortcut cheatsheet
- [docs/gh-auth.md](docs/gh-auth.md):
  GitHub auth strategy
