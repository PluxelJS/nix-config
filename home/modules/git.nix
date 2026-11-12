{
  config,
  lib,
  pkgs,
  ...
}:
let
  desktop = config.ahdg.features.gui;
  gitPackage = config.programs.git.package;
  walletHelper = pkgs.callPackage ../../pkgs/git-credential-libsecret.nix { };
  oauthHelper = lib.getExe pkgs.git-credential-oauth;
  storageHelper =
    if desktop then
      lib.getExe walletHelper
    else
      "${gitPackage}/bin/git-credential-cache --timeout=2592000";
in
{
  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Macchiato";
      style = "plain";
      paging = "never";
    };
  };

  # Home Manager owns generic Git behavior under XDG_CONFIG_HOME. Author
  # identity stays in the writable, machine-local ~/.gitconfig so a shared
  # checkout never assigns the repository owner's identity to another user.
  home.activation.ensureLocalGitConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    target="${config.home.homeDirectory}/.gitconfig"
    managed_config="${config.xdg.configHome}/git/config"

    if [[ ! -e "$target" && ! -L "$target" ]]; then
      install -m600 /dev/null "$target"
    fi

    if [[ -f "$target" && ! -L "$target" ]]; then
      chmod u+rw "$target"
      if ! ${pkgs.git}/bin/git config --file "$target" --get-all include.path \
        | ${pkgs.gnugrep}/bin/grep -Fqx "$managed_config"; then
        ${pkgs.git}/bin/git config --file "$target" --add include.path "$managed_config"
      fi
    fi
  '';

  # Retire the previous hand-written helper setup without touching identity,
  # custom host helpers, includes, or the credentials in the desktop wallet.
  home.activation.migrateGitOAuthHelpers = lib.hm.dag.entryAfter [ "ensureLocalGitConfig" ] ''
    target="${config.home.homeDirectory}/.gitconfig"
    backup="$target.pre-nix-oauth.bak"

    remove_legacy_git_helper() {
      local key="$1" value="$2"
      if ${pkgs.git}/bin/git config --file "$target" --fixed-value --get-all "$key" "$value" >/dev/null; then
        if [[ ! -e "$backup" && ! -L "$backup" ]]; then
          cp -p -- "$target" "$backup"
        fi
        ${pkgs.git}/bin/git config --file "$target" --fixed-value --unset-all "$key" "$value"
        legacy_helper_removed=1
      fi
    }

    remove_unused_helper_reset() {
      local key="$1" remaining
      if [[ "$legacy_helper_removed" == 1 ]]; then
        remaining="$(${pkgs.git}/bin/git config --file "$target" --get-all "$key" || true)"
        if [[ -z "$remaining" ]]; then
          remove_legacy_git_helper "$key" ""
        fi
      fi
    }

    if [[ -f "$target" && ! -L "$target" ]]; then
      legacy_helper_removed=0
      remove_legacy_git_helper credential.helper libsecret
      remove_legacy_git_helper credential.helper oauth
      remove_unused_helper_reset credential.helper
      for host in github.com gist.github.com; do
        legacy_helper_removed=0
        remove_legacy_git_helper "credential.https://$host.helper" '!gh auth git-credential'
        remove_legacy_git_helper "credential.https://$host.helper" "!${pkgs.gh}/bin/gh auth git-credential"
        remove_unused_helper_reset "credential.https://$host.helper"
      done
    fi
  '';

  home.packages = [
    pkgs.git-credential-oauth
  ] ++ lib.optional desktop walletHelper;

  programs.git = {
    enable = true;
    signing.format = "openpgp";

    settings = {
      # Reset inherited helpers, then read durable storage before generating
      # OAuth credentials. Absolute paths also work with Flatpak's own Git.
      credential.helper = [
        ""
        storageHelper
        (oauthHelper + lib.optionalString (!desktop) " -device")
      ];
      init.defaultBranch = "main";
      pull.rebase = false;
      push.autoSetupRemote = true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "Catppuccin Macchiato";
      navigate = true;
      side-by-side = true;
    };
  };
}
