# Prep Cleanup Plan

This note is a staging document for cleanup work. It intentionally does not
introduce new implementation. The goal is to make future commits small,
coherent, and easy to review.

## Current Direction

The current cleanup direction is:

- keep the desktop theme stack reproducible in Nix
- keep DMS runtime generation only where live mutable files are required
- avoid adding theme ports for apps that are not managed by Nix/Home Manager
- separate policy cleanup from unrelated editor, shell, or app behavior changes

## Ownership Layers

The repo currently has four different layers that should not be mixed into one
commit:

1. Theme policy and desktop asset ownership
2. Desktop/XDG/editor integration
3. Shell interaction policy
4. MangoWC/DMS session behavior

If one change touches more than one layer, the change should be split unless
the files are tightly coupled by a single user-visible behavior.

## Suggested Commit Split

### 1. Theme Stack Cleanup

Scope:

- `docs/theme-stack.md`
- `home/modules/gui/theme-policy.nix`
- `home/modules/gui/theme-runtime.nix`
- `home/modules/gui/default.nix`
- `home/modules/gui/gtk.nix`
- `home/modules/gui/plasma.nix`
- `home/modules/gui/portal.nix`
- `home/modules/gui/mango.nix`
- `home/modules/git.nix`
- `home/modules/shell/yazi.nix`
- `home/modules/shell/default.nix`
- `README.md`

Intent:

- centralize canonical theme names and font/cursor policy
- document Nix vs DMS ownership
- keep portal and session theme behavior aligned with the shared runtime values
- add only Nix-managed app themes such as `yazi`, `bat`, and `delta`

### 2. Desktop/XDG And Editor Defaults

Scope:

- `home/modules/xdg.nix`
- `home/modules/gh.nix`

Intent:

- editor defaults, MIME ownership, desktop entry additions, and open-with
  policy belong together
- this commit should stand on its own without any theme rationale

Note:

- this bucket may mention VSCode desktop IDs for MIME fallback ordering, but it
  is still not a VSCode theming commit

### 3. Shell UX And Shortcut Policy

Scope:

- `docs/shortcut-policy.md`
- `docs/shell-shortcuts.md`
- `home/files/zsh/interactive.zsh`
- `home/modules/shell/atuin.nix`
- `home/modules/shell/opencode.nix`
- `home/modules/shell/zsh/init.nix`

Intent:

- keep shell keybinding behavior, Atuin coordination, cheatsheet content, and
  `opencode` TUI entrypoints in one reviewable change

### 4. MangoWC / DMS Session Behavior

Scope:

- `home/files/mango/config.conf`
- `home/files/mango/dms.conf`
- `home/files/mango/env.conf`
- `home/files/mango/rules/10-float-and-geometry.conf`

Intent:

- Mango keybinds, DMS environment propagation, and session-side launch behavior
  should be reviewed as compositor/session policy, not as theme or shell work

### 5. Runtime Dependency Or Packaging Adjustments

Scope:

- `flake.nix`
- `home/modules/gui/assets.nix`
- `home/modules/gui/flatpak.nix`
- `home/modules/gui/input-method.nix`

Intent:

- package/runtime fixes such as `songrec` audio dependency overrides,
  additional GUI package ownership, Flatpak exposure rules, or IM environment
  fixes belong in an infra-style commit

## What Not To Do

- do not mix shortcut rewrites into theme commits
- do not mix editor/MIME defaults into portal/theme commits
- do not treat DMS runtime mutation as if it were the same thing as stable
  Nix-owned theme selection
- do not add new app theme ports for host-installed apps just because they are
  present on the machine

## Review Standard

Before each future cleanup commit:

- the commit should answer one clear policy question
- the touched files should mostly belong to one ownership layer
- the resulting behavior should still be explainable from the docs without
  hidden runtime patches
