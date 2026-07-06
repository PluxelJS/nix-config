# Flatpak Environment Policy

This document defines which desktop environment values are managed by the host session and which Flatpak-specific values are managed by this repository.

## Official Flatpak Behavior

Flatpak generally passes environment variables from the launcher process into the sandbox unless `--clear-env` is used. It then unsets or overrides variables that would interfere with sandbox correctness, including `PATH`, library search paths, temporary directory variables, and several XDG variables.

Flatpak always points these variables at the app-private storage under `~/.var/app/$APPID/`:

- `XDG_DATA_HOME`
- `XDG_CONFIG_HOME`
- `XDG_CACHE_HOME`
- `XDG_STATE_HOME`

The host values are exposed with `HOST_` prefixes:

- `HOST_XDG_DATA_HOME`
- `HOST_XDG_CONFIG_HOME`
- `HOST_XDG_CACHE_HOME`
- `HOST_XDG_STATE_HOME`

References:

- <https://docs.flatpak.org/en/latest/flatpak-command-reference.html>
- `man flatpak-run`
- `man flatpak-metadata`

## Values We Do Not Pin In Flatpak Overrides

Do not add these to the Home Manager-owned Flatpak global override unless
there is a specific bug that requires pinning them:

- `XDG_CURRENT_DESKTOP`
- `XDG_SESSION_DESKTOP`
- `XDG_SESSION_TYPE`
- `DESKTOP_SESSION`
- `WAYLAND_DISPLAY`
- `GTK_THEME`
- `GDK_BACKEND`
- `GTK_IM_MODULE`
- `GTK_USE_PORTAL`
- `INPUT_METHOD`
- `LANG`
- `LC_*`
- `COLORTERM`
- `MOZ_ENABLE_WAYLAND`
- `NIXOS_OZONE_WL`
- `OZONE_PLATFORM`
- `QT_IM_MODULE`
- `QT_IM_MODULES`
- `QT_QPA_PLATFORM`
- `QT_QPA_PLATFORMTHEME`
- `SDL_IM_MODULE`
- `XMODIFIERS`

These are session values. They should come from the compositor/session setup,
currently managed by MangoWC/Home Manager outside this Flatpak package. Pinning
them globally would make Flatpak apps stale after changing the WM, theme, input
method, locale, or terminal color policy.

Current host policy keeps `ELECTRON_OZONE_PLATFORM_HINT=auto` as the global
session default. That is intentional: it is safer for general Electron apps.
`CodeStudio` overrides only Electron's Wayland hint locally because this app is
intentionally Wayland-only.

On the current machine, these values are observed inside
`io.github.trumank.CodeStudio` without being written in the global override:

- `XDG_CURRENT_DESKTOP=mangowc`
- `XDG_SESSION_DESKTOP=mangowc`
- `XDG_SESSION_TYPE=wayland`
- `DESKTOP_SESSION=mangowc`
- `WAYLAND_DISPLAY=wayland-0`
- `GTK_THEME=Catppuccin-Macchiato:dark`
- `LANG=zh_CN.UTF-8`

Use this to inspect the effective sandbox environment:

```bash
flatpak run --command=env io.github.trumank.CodeStudio | sort
```

## Values We Pin In Flatpak Overrides

None by default.

The global Flatpak override should not be a second source of truth for GUI
environment variables. Put common GUI env in the host session, then let Flatpak
inherit it.

`CodeStudio` sets only app-specific Electron values in `code-studio-launcher`.
The launcher pins `ELECTRON_OZONE_PLATFORM_HINT=wayland` and passes
`--ozone-platform=wayland` because the app manifest exposes Wayland only.
It does not disable Chromium/Electron rendering features; version pinning is
used for the current font-rendering regression instead.

## Filesystem Integration

The Home Manager-owned global override exposes read-only desktop integration
files because Flatpak apps cannot otherwise see all host theme/input/font
resources:

- GTK config: `xdg-config/gtk-2.0`, `xdg-config/gtk-3.0`, `xdg-config/gtk-4.0`, `~/.gtkrc-2.0`
- Qt/KDE config: `xdg-config/kdeglobals`, `xdg-config/kcminputrc`, `xdg-config/Kvantum`, `xdg-data/Kvantum`
- Input method config: `xdg-config/fcitx5`, `xdg-data/fcitx5`
- Fonts/icons/themes: `xdg-data/fonts`, `xdg-data/icons`, `xdg-data/themes`, `~/.fonts`, `~/.icons`, `~/.themes`
- Other desktop data: `xdg-data/color-schemes`, `xdg-config/color-schemes`, `xdg-data/sounds`, `xdg-config/mimeapps.list`, `xdg-config/mimeinfo.cache`

Keep these read-only. Do not add host home access or writable desktop config access to the global override.

`CodeStudio` has one app-specific writable host path, `~/code`, declared in its Flatpak manifest. Keep project access app-specific rather than putting writable host paths in the global override.

## App-Specific State

Do not put `CodeStudio` runtime or developer-tool state in the global override. Keep it app-private:

- VS Code user data
- VS Code extensions
- `.codex`
- `.bun`
- `pnpm`
- `mise`
- `.gnupg`
- `.ssh`
- zsh config/history

Those are managed by `code-studio-launcher` under:

```text
~/.var/app/io.github.trumank.CodeStudio/home
```
