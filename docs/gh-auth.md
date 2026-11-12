# Git OAuth and GitHub CLI Authentication

Home Manager owns the Git HTTPS credential-helper policy in
`home/modules/git.nix`. The desktop profile uses this order:

1. Reset inherited credential helpers.
2. Read stored credentials through `git-credential-libsecret` and the desktop
   Secret Service (KWallet on this workstation).
3. Run `git-credential-oauth` when new credentials are needed.

The wallet helper is built from the locked Git source with
`pkgs/git-credential-libsecret.nix`; both helpers use absolute Nix store paths.
The main nixpkgs input pins both OAuth and its Go build toolchain, so routine
flake updates advance them together. Code Studio and managed
JetBrains Flatpaks read the same host Git config and can reach the same desktop
Secret Service; their own Git executables can call these helpers too.

The wallet helper's patch keeps reads, writes, and erases on SecretService.
Upstream mixes direct SecretService reads with backend-selected writes/erases;
inside Flatpak, libsecret selects the portal's app-private file backend for
the latter. A successful login is then saved somewhere the next read does not
search, causing repeated browser prompts. `SECRET_BACKEND=service` does not
override that Flatpak auto-selection. This is a storage mismatch, not a short
OAuth lifetime. The patch uses the same system wallet for all operations.
Existing tokens in the private backend are not automatically imported; a new
login saves to the correct wallet, or a targeted local migration can preserve
the token and refresh token without exposing either in logs.

## Login Lifetime

On the desktop, credentials persist in the system wallet across reboots. There
is no local cache timeout that forces another browser login every few hours.
The wallet must be available and unlocked. Provider expiry, revocation, and
organization policy still apply; when the provider supplies a refresh token,
the helper can use it to renew access without another browser login.

The shell/container profiles have no managed desktop wallet. They instead use
an in-memory cache with a 30-day timeout (`2592000` seconds), followed by OAuth
device flow. Restarting the cache daemon or machine clears that cache early.
The timeout does not extend a provider's token lifetime.

Upstream describes the
[storage-helper/OAuth order](https://github.com/hickford/git-credential-oauth#configuration)
and Git documents the
[memory cache lifetime](https://git-scm.com/docs/git-credential-cache).

## Everyday Use

Use HTTPS remotes. The first authenticated fetch or push opens the provider's
browser login; later operations reuse the wallet credential. Public reads may
not require authentication at all.

For an existing GitHub checkout that currently uses SSH:

```bash
git remote set-url origin https://github.com/OWNER/REPO.git
```

Remote URLs remain repository-local. Home Manager does not rewrite checkouts.
For a custom GitLab/Gitea/Forgejo host, follow the helper's upstream host setup
instructions when it cannot discover an OAuth application automatically.

## GitHub CLI

`gh` remains available for API operations such as issues and pull requests. Its
API login is separate from Git's OAuth helper. Home Manager configures HTTPS
for new `gh` clones, while `gh` continues to own its writable settings and
account state under `~/.config/gh`.

```bash
gh auth login --web --git-protocol https
gh auth status
```

Do not run `gh auth setup-git` or `git credential-oauth configure` as part of
bootstrap: those commands write another helper policy into the local Git
config. Home Manager already declares the helper chain.

## Migration and Diagnostics

Activation removes the old bare `libsecret`/`oauth` helper entries and the
previous `gh auth git-credential` entries for GitHub/Gist from the regular
machine-local `~/.gitconfig`. Before changing that file it saves
`~/.gitconfig.pre-nix-oauth.bak`, without overwriting an existing backup. Identity,
includes, custom helpers, and wallet contents are retained. Custom local helper
entries can still change the effective chain; review them if behavior differs.

Inspect helper configuration without printing tokens:

```bash
git config --show-origin --get-all credential.helper
git config --show-origin --get-regexp '^credential\..*helper$'
```

GitButler should reuse the configured system Git and credential helpers.
Avoid verbose OAuth traces or printing `git credential fill` output when
sharing diagnostics, since they can contain tokens.

`tests/git-wallet-flatpak-test.py` exercises sandbox approval, a second Git
process reading the saved credential, cross-boundary reuse, rejection, and
expired-token refresh handoff. Run it with `CODESTUDIO_TEST_INSTANCE` set to
the running Flatpak instance and `CODESTUDIO_TEST_ENV_PID` to the editor's host
PID. It uses unique `.invalid` hosts and fake tokens, and removes its wallet
entries afterward. A read-only host-to-sandbox test alone cannot detect the
write-backend mismatch.

Credentials, refresh tokens, wallet data, and `gh` account state remain local.
Nix declares packages and policy, not login secrets. The existing agenix tools
remain available for a future explicit recovery workflow.
