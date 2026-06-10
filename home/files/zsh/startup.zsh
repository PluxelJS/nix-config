# Startup output should stay separate from shell wiring. Keep it deterministic:
# only use tools that are actually managed by this Nix setup.

_supports_image_logo() {
  case "${TERM_PROGRAM:-}" in
    ghostty|WezTerm)
      return 0
      ;;
    *)
      [[ "${KITTY_WINDOW_ID:-}" != "" ]]
      ;;
  esac
}

if [[ $- == *i* ]] && [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && [[ "${TERM}" != "dumb" ]]; then
  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch_logo="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/assets/1544x1544_circle.png"
    if _supports_image_logo && [[ -f "$fastfetch_logo" ]]; then
      fastfetch --logo-type kitty-direct --logo "$fastfetch_logo" --logo-width 30 --logo-height 15
    else
      fastfetch
    fi
  fi
fi
