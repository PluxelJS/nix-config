# Bootstrap

Fresh-machine setup lives here.

The primary implementation is the committed Go binary:

- `bootstrap/bin/cachyos-bootstrap`: Linux amd64 bootstrap/deps/cleanup/verify CLI
- `bootstrap/cachyos.toml`: profile, package, command, and Flatpak policy
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

`bootstrap/cachyos.toml` is TOML because this file is maintained by humans:
comments, dotted sections, and array tables fit package policy well. Runtime
dependency size is irrelevant here because fresh machines run the committed
binary, not `go run`.

Rebuild the committed binary after changing Go code or `go.mod`:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -trimpath -ldflags='-s -w' \
  -o bootstrap/bin/cachyos-bootstrap ./tools/cachyos-bootstrap
```
