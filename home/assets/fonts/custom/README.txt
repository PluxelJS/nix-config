Put custom fonts here when they are not yet modeled in Nix.

This directory is the canonical source for non-nixpkgs fonts in this setup.

Workflow:
- add font files or font directories here
- run `home-manager switch --flake ~/.config/nix#ahdg`
- Home Manager will sync them to `~/.local/share/fonts/custom/`

Keep the Home Manager-managed fonts under `~/.local/share/fonts/nix/` untouched.
