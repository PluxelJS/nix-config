# Operations

This document is the operator-facing reference for switching, cleanup,
validation, and runtime-state expectations.

## Switch Commands

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

Bootstrap the Arch-side runtime base:

```bash
~/.config/nix/scripts/install-arch-runtime-deps.sh
~/.config/nix/scripts/install-arch-runtime-deps.sh --apply
~/.config/nix/scripts/install-arch-runtime-deps.sh --apply --with-recommended
```

## Canonical Edit Paths

Canonical source files live here:

- `~/.config/nix/home/files/ghostty/config`
- `~/.config/nix/home/files/themes/ghostty/config-dankcolors`
  This is only the seed. The live runtime file stays writable at
  `~/.config/ghostty/config-dankcolors`.
- `~/.config/nix/home/files/fastfetch/config.jsonc`
- `~/.config/nix/home/files/starship/starship.toml`
- `~/.config/nix/home/files/zsh/interactive.zsh`
- `~/.config/nix/home/files/zsh/startup.zsh`
- `~/.config/nix/home/assets/fonts/custom/`
- `~/.config/nix/home/files/fcitx5/config`
- `~/.config/nix/home/files/fcitx5/profile`
- `~/.config/nix/home/files/fcitx5/conf/`
- `~/.config/nix/home/files/fcitx5/rime/default.yaml`
- `~/.config/nix/home/files/fcitx5/rime/custom_phrase.txt`
- `~/.config/nix/home/files/fcitx5/rime/custom/`
- `~/.config/nix/home/modules/gui/fontconfig.nix`
- `~/.config/nix/home/modules/gui/gtk.nix`
- `~/.config/nix/home/modules/gui/flatpak.nix`
- `~/.config/nix/home/modules/xdg.nix`
- `~/.config/nix/home/modules/profile.nix`
- `~/.config/nix/docs/shortcut-policy.md`
- `~/.config/nix/docs/shell-shortcuts.md`
- `~/.config/nix/docs/gh-auth.md`

The files under `~/.config/<tool>/...` and `~/.local/share/...` are runtime
outputs. They should exist after activation, but they are not the canonical
place to keep config.

Stable policy-style desktop config is generated directly in Nix modules for:

- fontconfig entrypoints and custom match rules
- GTK 2/3 defaults and `xsettingsd`
- Flatpak global override
- `xdg-terminals.list`

## Managed Runtime Paths

These runtime paths are owned by Home Manager or by activation steps driven
from this flake:

- `~/.config/ahdg/`
- `~/.config/atuin/config.toml`
- `~/.config/fastfetch/`
- `~/.config/fcitx5/`
- `~/.config/fontconfig/`
- `~/.config/ghostty/config`
- `~/.config/git/config`
- `~/.config/gtk-3.0/settings.ini`
- `~/.config/gtk-4.0/`
- `~/.config/mimeapps.list`
- `~/.config/starship/starship.toml`
- `~/.config/user-dirs.dirs`
- `~/.config/user-dirs.locale`
- `~/.config/xdg-desktop-portal/portals.conf`
- `~/.config/xdg-terminals.list`
- `~/.config/xsettingsd/xsettingsd.conf`
- `~/.config/zsh/.zshenv`
- `~/.config/zsh/.zshrc`
- `~/.local/share/aurorae/themes/CatppuccinMacchiato-Modern`
- `~/.local/share/color-schemes/CatppuccinMacchiatoLavender.colors`
- `~/.local/share/flatpak/overrides/global`
- `~/.local/share/fcitx5/themes/`
- `~/.local/share/fonts/nix/`
- `~/.local/share/icons/Bibata-Modern-Ice`
- `~/.local/share/icons/Papirus`
- `~/.local/share/icons/breeze`
- `~/.local/share/plasma/look-and-feel/Catppuccin-Macchiato-Lavender`
- `~/.local/share/themes/Catppuccin-Macchiato`
- `~/.gtkrc-2.0`
- `~/.zshenv`

## Intentional Manual State

Some files remain outside strict Nix ownership on purpose:

- `~/.config/ghostty/config-dankcolors`
  DMS still updates this file at runtime.
- `~/.local/share/flatpak/overrides/<app-id>`
  App-specific Flatpak overrides stay manual.
- `gh` keyring entries or fallback `~/.config/gh/hosts.yml`
  `gh` login remains local runtime state.
- `~/.local/share/fonts/`
  The `nix/` subtree is Nix-managed; extra manual fonts remain manual.
- `~/.local/share/fcitx5/rime/build/`
- `~/.local/share/fcitx5/rime/sync/`
- `~/.local/share/fcitx5/rime/*.userdb/`
- `~/.local/share/fcitx5/rime/user.yaml`
- `~/.local/share/fcitx5/rime/installation.yaml`
  These are live Rime runtime artifacts and remain writable.

## Runtime Expectations

After a successful switch:

- `~/.zshenv`, `~/.config/zsh/.zshenv`, and `~/.config/zsh/.zshrc` are Home
  Manager symlinks
- `~/.config/ghostty/config` is a Home Manager symlink when Ghostty is enabled
- `~/.config/ghostty/config-dankcolors` is a writable regular file when DMS
  runtime support is enabled
- `~/.config/fcitx5/config`, `profile`, and `conf/*.conf` are regular files
- `~/.gtkrc-2.0` is a Home Manager symlink
- `~/.config/fontconfig/fonts.conf` is a regular file, not a store symlink
- `~/.local/share/fonts/custom/` is a regular directory copied from the repo
- GTK themes, fcitx themes, icon themes, and Flatpak-facing Plasma/GTK assets
  are materialized as regular files or directories
- `~/.local/share/fcitx5/rime/` contains a Nix-refreshed Wanxiang baseline plus
  writable runtime subtrees such as `build/`, `sync`, and `*.userdb/`
- `~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-3.0/dank-colors.css` are gone
- `~/.config/autostart/org.fcitx.Fcitx5.desktop` should not exist
- `~/.config/environment.d/90-dms.conf` is gone
- `~/.gitconfig` exists as a compatibility entrypoint managed by Home Manager
- `~/.config/qt5ct` and `~/.config/qt6ct` are gone

## Package Cleanup

Use the cleanup helper in dry-run mode first:

```bash
~/.config/nix/scripts/cleanup-pacman-duplicates.sh
~/.config/nix/scripts/cleanup-pacman-duplicates.sh --apply
```

It is reverse-dependency aware and only proposes pacman removals that are safe
on this machine.

Intentionally kept outside that cleanup:

- `fcitx5`, `fcitx5-gtk`, `fcitx5-qt`, `fcitx5-rime`, `librime`,
  `librime-data`, because the fcitx runtime stays on the system side
- `zsh`, because the login shell still points at `/usr/bin/zsh`
- `dms-shell`, because the live Ghostty color overlay is still generated by DMS

## Validation

Run after switching and again after reboot:

```bash
~/.config/nix/scripts/verify-shell-migration.sh
```

Or target a specific deployment explicitly:

```bash
~/.config/nix/scripts/verify-shell-migration.sh shell
~/.config/nix/scripts/verify-shell-migration.sh container
```

The verification script decides most checks from
`~/.config/ahdg/enabled-features`, so custom feature mixes remain valid.
