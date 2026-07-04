# Bootstrap

Fresh-machine setup entrypoints live here.

These scripts may install host packages, AUR helpers, Nix itself, and then run
Home Manager. Routine validation, cleanup, and repair scripts stay under
`scripts/`.

Current entrypoint:

```bash
~/.config/nix/bootstrap/cachyos.sh
~/.config/nix/bootstrap/cachyos.sh --apply --with-recommended
```
