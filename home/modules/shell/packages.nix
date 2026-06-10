{ pkgs, ragenix, ... }:
let
  pkgfileCompat = pkgs.writeShellApplication {
    name = "pkgfile";
    text = ''
      set -euo pipefail

      if [[ -x /usr/bin/pkgfile ]]; then
        if /usr/bin/pkgfile "$@" 2>/dev/null; then
          exit 0
        fi
      fi

      if [[ $# -eq 2 && "$1" == "-b" ]]; then
        exec /usr/bin/pacman -Fq "/usr/bin/$2"
      fi

      if [[ -x /usr/bin/pkgfile ]]; then
        exec /usr/bin/pkgfile "$@"
      fi

      echo "pkgfile: command not found" >&2
      exit 127
    '';
  };
in {
  home.packages =
    (with pkgs; [
      bat
      eza
      fd
      mise
      ripgrep
      yazi
      zsh-autopair
      zsh-completions
      pkgfileCompat
    ])
    ++ [
      ragenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
}
