# Bootstrap

Fresh-machine setup lives here.

The primary implementation is the committed Go binary:

- `bootstrap/bin/cachyos-bootstrap`: Linux amd64 bootstrap/deps/cleanup/verify CLI
- `bootstrap/cachyos.toml`: profile, package, AUR exception, and Flatpak policy
- `tools/cachyos-bootstrap/`: source for rebuilding the binary

The shell entrypoint is intentionally thin:

```bash
~/.config/nix/bootstrap/cachyos.sh
~/.config/nix/bootstrap/cachyos.sh --apply
~/.config/nix/bootstrap/cachyos.sh --apply --minimal
~/.config/nix/bootstrap/cachyos.sh deps
~/.config/nix/bootstrap/cachyos.sh cleanup
~/.config/nix/bootstrap/cachyos.sh verify
```

The desktop profile installs the current desktop helper packages and managed
Flatpak app set by default. `--minimal` skips those extras for lean
shell/container bring-up or debugging.

`bootstrap/cachyos.toml` stays intentionally small: profiles select feature
names, package sections are plain package lists, and the remaining AUR exception
maps to the commands expected on the desktop. Runtime dependency size is
irrelevant here because fresh machines run the committed binary, not `go run`.

Rebuild the committed binary after changing Go code or `go.mod`:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -trimpath -ldflags='-s -w' \
  -o bootstrap/bin/cachyos-bootstrap ./tools/cachyos-bootstrap
```
