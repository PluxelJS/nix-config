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
- user-scoped services such as the Proxy LLM compose stack and Verdaccio
  Podman quadlet
- LocalSend from Nixpkgs, wrapped for the CachyOS graphics stack

The host package manager owns:

- `/etc`, PAM, display managers, login/session plumbing, and systemd system units
- compositor/session runtimes such as MangoWC and DMS
- graphics, seat, input-method runtime, and PolicyKit/system plumbing
- local credentials and app runtime state
- host firewall state; the bootstrap applies repo-owned UFW profiles

## Quick Start

After the normal x86_64 CachyOS + KDE installer has created your desktop user,
open a terminal as that user and run:

```bash
git clone https://github.com/PluxelJS/nix-config.git ~/.config/nix && ~/.config/nix/setup
```

`setup` is idempotent, defaults to the desktop profile, and may be rerun after
config updates. To inspect the planned work first:

```bash
~/.config/nix/setup --check
```

If Git is not installed yet, install it with `sudo pacman -S --needed git`.
An optional remote installer that installs Git and performs the shallow clone is:

```bash
curl -fsSL https://raw.githubusercontent.com/PluxelJS/nix-config/main/bootstrap/install.sh | bash
```

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

Switch configurations:

```bash
home-manager switch --flake ~/.config/nix#current --impure
home-manager switch --flake ~/.config/nix#current-shell --impure
home-manager switch --flake ~/.config/nix#current-container --impure
```

If `home-manager` is not installed globally:

```bash
nix run github:nix-community/home-manager -- switch --flake ~/.config/nix#current -b pre-nix --impure
```

Build activation package only:

```bash
nix build ~/.config/nix#homeConfigurations.current.activationPackage --impure
```

The desktop profile enables `proxy-llm.service`. Nix owns its compose topology
and pinned images, while machine-local configuration and persistent data stay
under `~/.local/state/proxy-llm/`. See
[docs/operations.md](docs/operations.md) for service and backup commands.

## Structure

- `flake.nix`: top-level Home Manager entrypoints
- `home/default.nix`: shared module root
- `home/modules/profile.nix`: base profiles plus feature overrides
- `home/modules/shell/`: shell behavior and CLI tooling
- `home/modules/gui/`: fonts, GTK, Plasma, input method, portals, Flatpak, LocalSend
- `home/modules/podman/`: user-scoped Podman compose services and quadlets
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

The portable outputs still carry this repository owner's Git author identity
and opinionated desktop/app selection. That is appropriate for moving the same
person to a differently named account; change `home/modules/git.nix` and review
`bootstrap/cachyos.toml` before giving the setup to another person.

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
- [docs/shortcut-policy.md](docs/shortcut-policy.md):
  shortcut rules and cross-app decisions
- [docs/shell-shortcuts.md](docs/shell-shortcuts.md):
  actual shell shortcut cheatsheet
- [docs/gh-auth.md](docs/gh-auth.md):
  GitHub auth strategy
