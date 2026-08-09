# GitHub Auth Notes

This file records the preferred `git` / `gh` / `GitButler` auth shape without
adding more runtime complexity to the Home Manager config today.

## Current Practice

- Keep `gh` in the Home Manager profile as well as the host package set, so
  Flatpak IDE terminals can resolve the GitHub credential helper.
- Let Home Manager own normal config for `git`; seed `gh` defaults as a writable
  runtime file so `gh` can migrate or update its own config.
- Keep the original `agenix` CLI and Home Manager module available for a future
  encrypted recovery secret, but do not wire it into `gh` auth yet.
- Let local runtime auth stay local:
  `gh` should use the desktop credential store when available.
- Prefer SSH for Git transport and `gh` as the GitHub credential helper.

Recommended day-to-day login:

```bash
gh auth login --web --git-protocol ssh
gh auth status
```

On KDE, this should normally store the live credential in the system
credential store instead of trying to keep a repo-managed secret in sync.

## Why Not Sync It Yet

- Browser/device auth produces local runtime state, usually in the desktop
  keyring.
- That state is convenient for daily use but is a poor fit for declarative Nix
  management.
- Syncing `~/.config/gh/hosts.yml` is possible, but it is a runtime artifact and
  less stable than syncing a token on purpose.

## Future Option

If cross-machine recovery becomes worth the extra complexity later:

1. Keep daily auth in the local keyring.
2. Export a recovery token from `gh auth token`.
3. Encrypt that token with `agenix` and declare its runtime destination through
   the already imported Home Manager module.
4. Use the encrypted token only as a backup/bootstrap source for new machines.

This keeps local UX simple while still leaving a path to future recovery.

## GitButler

- Install `GitButler` from official `nixpkgs` when needed.
- Prefer letting it reuse the system Git executable and existing SSH /
  credential flow instead of introducing a second auth stack first.
