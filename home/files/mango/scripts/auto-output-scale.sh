#!/bin/sh
set -eu

interval="${MANGO_OUTPUT_SCALE_INTERVAL:-2}"

is_internal_output() {
  case "$1" in
    eDP-*|LVDS-*|DSI-*) return 0 ;;
    *) return 1 ;;
  esac
}

desired_scale() {
  width="$1"
  height="$2"

  if [ "$width" -ge 3840 ] || [ "$height" -ge 2160 ]; then
    printf '%s\n' 1.5
  elif [ "$width" -ge 2560 ] || [ "$height" -ge 1440 ]; then
    printf '%s\n' 1.25
  else
    printf '%s\n' 1
  fi
}

scale_matches() {
  current="$1"
  wanted="$2"

  awk -v current="$current" -v wanted="$wanted" '
    BEGIN {
      diff = current - wanted
      if (diff < 0) diff = -diff
      exit(diff < 0.001 ? 0 : 1)
    }
  '
}

current_outputs() {
  wlr-randr 2>/dev/null | awk '
    /^[^[:space:]]/ {
      output=$1
      enabled=""
      width=""
      height=""
      scale=""
    }
    /^[[:space:]]+Enabled:/ {
      enabled=$2
    }
    /^[[:space:]]+[0-9]+x[0-9]+ px/ && /current/ {
      split($1, mode, "x")
      width=mode[1]
      height=mode[2]
    }
    /^[[:space:]]+Scale:/ {
      scale=$2
      if (enabled == "yes" && width != "" && height != "") {
        print output, width, height, scale
      }
    }
  '
}

apply_scales() {
  current_outputs | while read -r output width height scale; do
    [ -n "$output" ] || continue
    is_internal_output "$output" && continue

    wanted="$(desired_scale "$width" "$height")"
    if scale_matches "$scale" "$wanted"; then
      continue
    fi

    wlr-randr --output "$output" --scale "$wanted" >/dev/null 2>&1 || true
  done
}

while :; do
  apply_scales
  sleep "$interval"
done
