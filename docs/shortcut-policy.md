# Shortcut Policy

This file is the source of truth for cross-app shortcut decisions.

## Principles

- Keep shell editing keys stable unless the benefit is clearly larger than the ecosystem cost.
- Let GUI apps keep standard tab semantics where they do not interfere with shell input.
- When terminal and shell conflict, prefer preserving the shell.
- Use one primary shortcut per action and keep alternates only when they are already a broad convention.

## Shell

- `F1`: show the shell help / shortcut cheatsheet.
- `keys`: show the same shell shortcut help from a normal command prompt.
- `Up` / `Ctrl+P`: use one shared history policy. Default to Atuin on the
  first press, but allow a configurable delay threshold in zsh when direct
  step-back through the last commands is more useful.
- `Alt+E`: open the env picker first; press `Tab` there to jump into `yazi`
  path selection, and replace the current env/path fragment when one exists.
- `Alt+S`: explicit `sudo` toggle for the current command line.
- `Alt+A`: open `opencode` TUI in the current workspace.
- `Ctrl+W`: delete the previous word. Do not repurpose this.
- `Ctrl+E`: end of line.
- `Ctrl+T`: transpose characters.

## Command Helpers

- `o`: open the current directory or explicit paths via `xdg-open`.
- `z`: jump to a known directory by frecency.
- `ffcd`: discover a directory by fuzzy search when `z` is not enough.
- `f` / `fix`: rerun the previous command using `pay-respects` suggestions.
  On Arch, missing-command package lookup should use `pacman` / `pkgfile`, not
  declarative Nix package changes.
- `oc`: launch `opencode`.
- `ffe`: fuzzy open a file in `$EDITOR`.
- `ffec`: fuzzy content-first open in `$EDITOR`.
- `gst` / `gl`: terse Git status and short graph log.

## AI

- Shell only keeps one AI shortcut: `Alt+A` for `opencode`.
- Interactive AI keybinds belong to `opencode` TUI, not to zsh widgets.
- One-shot scripted prompts stay as explicit commands such as `opencode run ...`.

## Ghostty

- `Ctrl+T`: new tab.
- `Ctrl+Shift+W`: close tab.
- `Ctrl+PgUp` / `Ctrl+PgDn`: previous / next tab.
- `Ctrl+Shift+Tab` / `Ctrl+Tab`: alternate previous / next tab.
- `Ctrl+W` stays unbound at the terminal layer so the shell keeps backward-kill-word.

## Dolphin

- `Ctrl+T`: new tab.
- `Ctrl+W`: close tab.
- `Ctrl+Shift+T`: reopen closed tab.
- `Ctrl+PgUp` / `Ctrl+PgDn`: previous / next tab.
- `Ctrl+Shift+Tab` / `Ctrl+Tab`: alternate previous / next tab.

## MangoWC

- `Ctrl+\``: toggle `CopyQ`.
- `Super+Shift+M`: launch `SongRec` in `gui-norecording` mode first.
- `Super+Shift+R`: reload the MangoWC config.

## Intentional Mismatch

`Ghostty` does not use `Ctrl+W` for close-tab. That mismatch is intentional:
it protects shell editing and avoids breaking remote shells, TUIs, and readline
muscle memory.
