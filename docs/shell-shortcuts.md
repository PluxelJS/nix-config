# Shell Shortcuts

This file documents the actual interactive shell behavior managed by the Nix
zsh setup. `shortcut-policy.md` explains the rules and tradeoffs; this file is
the operator-facing cheatsheet.

## Primary Entry Points

- `F1`: open the interactive shell shortcut help.
- `keys`: print the same shortcut help on demand.
- `Ctrl+R`: open Atuin history search.
- `Up` / `Ctrl+P`: run the shared history-up policy.
- `Alt+E`: open the env-first quick insert picker.
- `Alt+S`: toggle `sudo` on the current command.
- `Alt+A`: open `opencode` TUI in the current workspace.

## History

- `Ctrl+R` is the primary history search entry point.
- `Up` and `Ctrl+P` intentionally share one behavior.
- `ZSH_ATUIN_UP_THRESHOLD=1`: first press opens Atuin immediately.
- `ZSH_ATUIN_UP_THRESHOLD=2`: first press steps to the previous command, second consecutive press opens Atuin.
- `ZSH_ATUIN_UP_THRESHOLD=3`: first two presses step backward, third consecutive press opens Atuin.
- `Down` remains normal shell history/down-line behavior.

## Sudo Toggle

- `Alt+S` is the explicit, documented `sudo` toggle.
- `Esc Esc` remains as a compatibility alias, not the primary advertised entry.
- If the command line is empty, the widget first pulls the previous history item, then toggles `sudo`.
- If the current command already starts with `sudo `, triggering the widget removes that prefix.
- Otherwise, triggering the widget prefixes the current command with `sudo `.

## Quick Insert

- `Alt+E` opens the environment-variable picker first.
- If the cursor is after `$NAME` or `${NAME`, the picker uses that fragment as the initial query.
- `Enter` inserts the selected environment variable reference.
- `Tab` jumps from the env picker into `yazi` file selection.
- In the `yazi` chooser, `Space` selects items and `Enter` or `o` confirms insertion.
- If the cursor is after a path-like fragment, confirmed `yazi` selections replace that fragment.

## Editing

- `Ctrl+A`: beginning of line.
- `Ctrl+E`: end of line.
- `Ctrl+T`: transpose characters.
- `Ctrl+W`: delete the previous word using standard shell behavior.
- `Ctrl+U`: delete to beginning of line.
- `Ctrl+K`: delete to end of line.
- `Ctrl+Y`: yank the last killed text.
- `Alt+B`: move backward by word.
- `Alt+F`: move forward by word.

## Built-in Helpers

- `o`: open the current directory, or explicit paths, through `xdg-open`.
- `z`: jump to a known directory by frecency.
- `f` / `fix`: rerun the previous command through `pay-respects`.
- `oc`: launch `opencode`.
- `ffcd`: fuzzy-pick and `cd` into a directory.
- `ffe`: fuzzy-pick a file and open it in `$EDITOR`.
- `ffec`: fuzzy-pick a file by content match and open it in `$EDITOR`.
- `gst`: terse Git status.
- `gl`: short decorated Git graph log.

## Notes

- `Ctrl+W` is intentionally reserved for shell editing, not terminal tab close.
- `Alt+S` exists because hidden double-escape gestures are hard to discover.
- `F1` and `keys` should be kept in sync with real bindings whenever shell behavior changes.
