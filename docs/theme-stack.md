# Theme Stack Policy

This document defines the ownership boundary between Nix-managed theme assets
and DMS-generated runtime colors.

## Current Canonical Theme Stack

- Day mode: `Catppuccin Latte + Lavender`
- Night mode: `Catppuccin Macchiato + Lavender`
- Default activation baseline: night mode
- Runtime mode switcher: `darkman`
- Icons: `Papirus`
- Cursor: `Bibata-Modern-Ice`

Important:

- The active Catppuccin desktop palette is selected at runtime. Nix installs
  both `Latte + Lavender` and `Macchiato + Lavender` assets.
- The runtime source of truth is `darkman`; DMS remains limited to mutable
  compositor/session overlays.

## Nix-Owned Theme Assets

These assets are declaratively sourced from nixpkgs and projected into the user
environment by Home Manager:

- `pkgs.catppuccin-gtk`
- `pkgs.catppuccin-kde`
- `pkgs.darkly`
- `pkgs.papirus-icon-theme`
- `pkgs.bibata-cursors`
- `pkgs.kdePackages.breeze-icons`
- font packages and fontconfig rules

Nix ownership includes both of these delivery modes:

- symlinked assets under `~/.config` / `~/.local/share`
- materialized regular files/directories copied from Nix store for Flatpak or
  sandbox compatibility

Materialized files are still Nix-controlled. They are regenerated on
`home-manager switch`.

## DMS-Owned Runtime Outputs

DMS remains the owner only for runtime-generated outputs that are expected to be
mutable while the session is running:

- `~/.config/ghostty/config-dankcolors`
- `~/.config/mango/dms/colors.conf`
- `~/.config/mango/dms/cursor.conf`
- `~/.config/mango/dms/layout.conf`
- `~/.config/mango/dms/outputs.conf`

Those files may change live and should not become Home Manager symlinks.

## Authority Rule

The policy is:

- Nix is the source of truth for stable theme selection, theme assets, toolkit
  settings, font policy, and app themes that should stay reproducible.
- DMS is only the source of truth for live runtime color generation and mutable
  compositor/session overlays.

This means:

- GTK, KDE, portal, icons, cursors, and most app themes should prefer Nix.
- MangoWC runtime overlay files should continue to prefer DMS.
- Terminal/TUI app themes such as `yazi` do not conflict with DMS and should be
  Nix-managed if we want a pinned reproducible theme.

Portal-specific rule:

- `org.freedesktop.impl.portal.Settings` should prefer `darkman`, so apps that
  follow the XDG Settings portal can react to system light/dark changes without
  app-specific theme wiring.
- `xdg-desktop-portal` backends that need toolkit environment should read
  `~/.config/ahdg/theme/session.env`.
- Do not rely on ad-hoc session import timing as the primary mechanism for
  portal theming, because DBus/systemd user activation can otherwise start the
  same GUI app under a different theme context.

## Current Dynamic DMS Scope

At the moment, DMS should be treated as the live owner only for:

- `~/.config/ghostty/config-dankcolors`
- `~/.config/mango/dms/colors.conf`
- `~/.config/mango/dms/cursor.conf`
- `~/.config/mango/dms/layout.conf`
- `~/.config/mango/dms/outputs.conf`

Everything outside that set should default to Nix ownership unless there is a
clear reason to keep runtime mutation.

## Current Nix-Managed App Themes

The following app-facing theme integrations are already expected to stay
Nix-managed and not DMS-managed:

- GTK theme assets and toolkit settings
- KDE color scheme, look-and-feel, window decoration, and widget style
- `darkman` mode switch hooks and the shared `ahdg-theme` apply script
- icon and cursor assets
- `fcitx5` Catppuccin theme assets
- `yazi` Catppuccin flavor
- `bat` / `delta` Catppuccin syntax theme selection

## App Theme Admission Rule

New app-specific theme integrations should be added only when the app runtime
itself is managed by Nix or Home Manager.

This keeps the theme stack reproducible and prevents us from writing Nix-owned
theme policy for random pacman/AUR apps that may disappear, diverge, or keep
their real state elsewhere.

Practical rule:

- new theme ports: Nix-managed apps only
- system-installed apps: do not add new theme ports by default
- if a system app only needs to follow toolkit/session theme settings, let GTK,
  KDE, portal, icon, and cursor policy handle it implicitly

## Grandfathered Exceptions

There are a small number of existing user-config cases where the runtime binary
is system-owned but the user-facing config is still intentionally Nix-owned:

- `fcitx5`: runtime stays on the host side, but Nix owns the config, theme
  assets, Rime baseline payload, and desktop/session environment policy
- `dolphin`: runtime may come from the host side, but `dolphinrc` and
  `dolphinui.rc` are still part of the repo-managed desktop policy; its DBus
  `org.freedesktop.FileManager1` daemon must read
  `~/.config/ahdg/theme/session.env`

These are legacy ownership decisions with a clear policy surface. They are not
a reason to expand new app theming to unrelated system-installed apps.

## VSCode Boundary

VSCode and related desktop IDs currently appear only as desktop-integration
participants such as MIME fallback ordering or window rules.

That is not the same thing as declaring VSCode to be part of the Nix-owned
theme stack.

Until the editor runtime itself is deliberately moved under Nix ownership, its
theme should not become a first-class target in this theme policy.

## GTK Direction

`catppuccin/gtk` is archived upstream. Keeping it is still valid if visual
consistency matters more than upstream churn, but it should be treated as a
frozen theme source.

If GTK is migrated away from Catppuccin, the preferred direction is:

- use an actively maintained GTK theme in Nix
- keep KDE/icon/cursor ownership unchanged
- avoid moving GTK theme generation into DMS unless the whole desktop is meant
  to become wallpaper-reactive

## Light/Dark Split

The active split is:

- light: `Latte`
- dark: `Macchiato`
- accent: `Lavender`

The efficient path is to use system-level mechanisms first:

- apps that support the XDG Settings portal follow `darkman`
- GTK follows `gtk-3.0/settings.ini`, `gtk-4.0`, `gsettings`, and xsettings
- KDE/Qt follows `kdeglobals`, KDE color schemes, and the KDE platform theme
- daemonized services such as Dolphin and portal backends read
  `~/.config/ahdg/theme/session.env` and are restarted by `ahdg-theme`

Avoid adding app-specific theme hooks unless an app cannot follow one of those
system surfaces.
