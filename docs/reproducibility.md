# Reproducibility Boundary

This repository targets reproducible function on a fresh x86_64 CachyOS KDE
installation. It does not try to clone credentials, databases, device state, or
every byte supplied by rolling host repositories.

## Locked User Environment

The Home Manager layer is the strongest boundary:

- `flake.lock` pins nixpkgs, Home Manager, nixGL, ragenix, and their transitive
  inputs by revision and NAR hash.
- Custom Nix packages and downloaded desktop resources use immutable versions
  or commits plus content hashes.
- Fonts from nixpkgs are part of the Home Manager profile. The custom
  TsangerJinKai font is committed directly under `home/assets/fonts/custom/`.
- GTK/KDE themes, icons, cursors, fontconfig policy, input-method policy, and
  Flatpak-facing materialized copies are generated from the locked closure.
- Proxy LLM and Verdaccio container images are selected by digest.
- Code Studio's editor, SDK, and shell form an explicitly pinned compatibility
  baseline selected by immutable archive hashes and a fixed runtime branch. It
  is not advanced by routine dependency refreshes because newer tested editor
  builds regress Wayland font clarity.

Building the activation package realizes the complete Nix-side dependency
graph, not only the configuration text:

```bash
nix build --impure \
  ~/.config/nix#homeConfigurations.current.activationPackage
```

## Rime Resource Chain

The Wanxiang input-method payload has an explicit end-to-end chain:

1. The Wanxiang v17.2.4 base archive is fetched through immutable GitHub
   release asset ID `504043698` and checked against SHA-256
   `6427bd629c7cc9f36d34f864407463145dd22b42a504f8669262bec401efa64b`.
2. The 420255788-byte zh-Hans grammar is fetched through GitHub release asset
   ID `506440692`, not the mutable `LTS` alias, and is checked against
   SHA-256 `316dbce6fcad232d8679bbca39d5a6820c870b3fe954a5b98e4838ade9b2a831`.
3. Repo-owned `default.yaml`, custom phrases, and schema patches are added in a
   Nix derivation.
4. That derivation generates `.nix-resource-manifest.sha256` over every static
   payload file.
5. Activation refreshes only the static baseline while preserving Rime build,
   sync, installation, and user-database state.
6. `setup --verify` checks the complete static manifest and confirms that
   `wanxiang.schema.yaml` selects `wanxiang-lts-zh-hans`.

The large grammar is deliberately not duplicated in Git. The asset ID and hash
prevent silent upstream drift; long-term independence from upstream deletion
requires publishing the fixed-output derivation through an accessible Nix
binary cache such as Attic or Cachix.

## Rolling Host and Application Layer

The following are declaratively selected but not bit-for-bit version-locked:

- CachyOS/pacman packages and explicit AUR packages
- Flathub applications and runtimes
- hardware drivers matched to the currently installed CachyOS kernel

These layers recreate the requested capabilities from their current repository
state. Exact archival reproduction would require snapshot repositories and
pinned Flatpak commits, which this setup does not currently provide.

## Deliberately Local State

The following must not be reproduced from a shared repository:

- Git author identity, GitHub authentication, KWallet, and application tokens
- Proxy LLM secrets and databases
- Verdaccio packages, caches, logs, and other service data
- Rime user dictionaries, sync data, and generated build output
- device pairing, per-monitor runtime state, and application history

Services that require secrets fail closed until their machine-local state is
provided. This separation makes a fresh deployment safe to share without
pretending that private mutable state is reproducible configuration.
