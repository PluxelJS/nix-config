# Bootstrap

Fresh-machine setup lives here.

The primary implementation is the committed Go binary:

- `bootstrap/bin/cachyos-bootstrap`: Linux amd64 bootstrap/deps/cleanup/verify CLI
- `bootstrap/cachyos.json`: profile, package, command, and Flatpak policy
- `tools/cachyos-bootstrap/`: source for rebuilding the binary

The shell entrypoint is intentionally thin:

```bash
~/.config/nix/bootstrap/cachyos.sh
~/.config/nix/bootstrap/cachyos.sh --apply --with-recommended
~/.config/nix/bootstrap/cachyos.sh deps
~/.config/nix/bootstrap/cachyos.sh cleanup
~/.config/nix/bootstrap/cachyos.sh verify
```

`--with-recommended` includes desktop helper packages and Flatpak apps used by
current keybinds, MIME defaults, and validation canaries.

`bootstrap/cachyos.json` is intentionally JSON rather than YAML/TOML/Nix. The
bootstrap binary must run directly after `git clone`, before Nix or Go packages
can be assumed, so the config format stays on Go's standard library parser.
Move repeated policy into data structures there; avoid adding a parser
dependency just for nicer syntax.

Rebuild the committed binary after changing Go code or `go.mod`:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -trimpath -ldflags='-s -w' \
  -o bootstrap/bin/cachyos-bootstrap ./tools/cachyos-bootstrap
```
