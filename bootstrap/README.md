# Bootstrap

Fresh-machine setup lives here.

For the usual case where CachyOS KDE and the desktop user already exist, clone
the repo and use its root entrypoint:

```bash
git clone https://github.com/PluxelJS/nix-config.git ~/.config/nix && ~/.config/nix/setup
```

Use `./setup --check` for a non-mutating preview, `./setup --flatpaks` for the
deferred app list, and `./setup --verify` for validation. The optional remote
`install.sh` installs Git when needed, makes a shallow checkout, and hands off
to `setup`; read it before using the `curl | bash` form when the remote
repository is not fully trusted.

The bootstrap binary passes `--impure` only to its Home Manager invocation so
the portable flake output can resolve `USER` and `HOME`. It does not weaken
global Nix settings. Manual `home-manager`/`nix build` commands should pass
`--impure` explicitly.

The primary implementation is the committed Go binary:

- `bootstrap/bin/cachyos-bootstrap`: Linux amd64 bootstrap/deps/firewall/cleanup/verify CLI
- `bootstrap/cachyos.toml`: profile, package, AUR exception, and Flatpak policy
- `bootstrap/codestudio/`: local Code Studio Flatpak package used by desktop bootstrap
- `bootstrap/ufw/`: repo-owned host firewall application profiles
- `tools/cachyos-bootstrap/`: source for rebuilding the binary

The shell entrypoint is intentionally thin:

```bash
~/.config/nix/bootstrap/cachyos.sh
~/.config/nix/bootstrap/cachyos.sh --apply
~/.config/nix/bootstrap/cachyos.sh --apply --minimal
~/.config/nix/bootstrap/cachyos.sh deps
~/.config/nix/bootstrap/cachyos.sh firewall --apply
~/.config/nix/bootstrap/cachyos.sh pull-gui-config
~/.config/nix/bootstrap/cachyos.sh cleanup
~/.config/nix/bootstrap/cachyos.sh verify
```

`verify` checks the active deployment. Add `--verbose` only when individual
successful checks are useful for diagnosis.

Use [docs/cachyos-bootstrap.md](../docs/cachyos-bootstrap.md) for the complete
pure-CachyOS deployment flow.

The desktop profile installs the current desktop helper packages and XDG
default-app dependencies by default. Flathub apps and the local Code Studio
Flatpak are explicit catch-up work:

```bash
bootstrap/cachyos.sh flatpaks --apply
```

`--minimal` skips desktop extras and optional Flatpaks for lean shell/container
bring-up or debugging. `bootstrap --apply --with-flatpaks` explicitly requests
the foreground all-in-one flow.

`bootstrap/cachyos.toml` stays intentionally small: profiles select feature
names, package sections are plain package lists, `aurPackages.desktop` declares
the package-exact AUR exceptions required by XDG defaults, and `aurCommands`
declares command-based AUR checks such as MangoWM. Runtime dependency size is
irrelevant here because fresh machines run the committed binary, not `go run`.

`pull-gui-config` is the explicit reverse-import path for GUI-edited static
config. It is dry-run by default and only imports whitelisted non-secret files
with `--apply`. KDE live preferences stay writable and are used only as future
seed sources after an explicit import.

LocalSend is supplied by Home Manager through the desktop GUI module. Its host
integration remains on the system side: `bootstrap/cachyos.sh deps --apply`
installs UFW and applies the repo-owned `LocalSend` application profile for
TCP/UDP port 53317. The same policy can be checked or repaired independently
with `bootstrap/cachyos.sh firewall [--apply]`.

Rebuild the committed binary after changing Go code or `go.mod`:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -trimpath -ldflags='-s -w' \
  -o bootstrap/bin/cachyos-bootstrap ./tools/cachyos-bootstrap
```
