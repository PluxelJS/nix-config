# Code Studio Flatpak

This directory contains the local Flatpak package for `io.github.trumank.CodeStudio`.
It is installed by the CachyOS bootstrap desktop profile after Flathub apps.

## Design

- Pin upstream VS Code to a known-good build.
- Keep all editor, shell, Codex, extension, and tool state under the app-private
  Flatpak home: `~/.var/app/io.github.trumank.CodeStudio/home`.
- Expose only `~/code` as writable host project storage.
- Use Wayland only; X11 and fallback X11 are intentionally not granted.
- Keep theme/font/input integration in the Home Manager-owned Flatpak global
  override.

The launcher creates:

```text
~/.var/app/io.github.trumank.CodeStudio/home/code -> ~/code
```

Home Manager creates `~/code` before applying the Flatpak override, so fresh
machines get the same private-home layout.

## Version Pin

Code Studio currently pins VS Code `1.116.0`
(`560a9dba96f961efea7b1612916f89e5d5d4d679`). Newer tested VS Code `1.124.x`
builds rendered editor text visibly blurrier on this Wayland setup, including
with equivalent fontconfig visibility and settings.

When bumping the editor, update `io.github.trumank.CodeStudio.yml`, keep the
sha256 pinned, and compare font clarity against the host editor before shipping.

## Install

Normally use the main bootstrap flow:

```bash
bootstrap/cachyos.sh --apply
```

Manual rebuild/install from the repo root:

```bash
bash bootstrap/codestudio/install-code-studio.sh "$PWD"
```

Prerequisites are declared in `bootstrap/cachyos.toml`:

- `flatpak`
- `flatpak-builder`
- `desktop-file-utils`
- `org.freedesktop.Sdk//24.08` from Flathub

The VS Code tarball is downloaded by `flatpak-builder` from the pinned URL in
the manifest; it is intentionally not committed to git.

The local Flatpak repository is kept at:

```text
~/.local/share/ahdg/flatpak-repos/code-studio
```

The installer registers it as the user remote `ahdg-code-studio` with
`no-enumerate` and `no-gpg-verify`. `no-enumerate` is intentional for this
single-app local repo; it keeps the package out of Flatpak search/discovery.

## Diagnostics

Inspect the effective launcher environment:

```bash
flatpak run --command=code-studio io.github.trumank.CodeStudio --print-code-studio-env
```

Open a shell inside the private home:

```bash
flatpak run --command=code-studio-shell io.github.trumank.CodeStudio
```

## Legacy Cleanup

The installer removes stale desktop entries and old app IDs for previous local
experiments:

- `com.mint.DevCode`
- `io.github.trumank.MintCodeStudio`
- old `mint-*` desktop launchers
