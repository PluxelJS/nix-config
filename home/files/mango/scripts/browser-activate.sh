#!/bin/sh
set -eu

browser_tag="${1:-4}"
desktop_id="${BROWSER_DESKTOP_ID:-zen}"
browser_cmd="${BROWSER_CMD:-zen-browser}"

tag_has_clients() {
  mask="$1"
  tag_id="$2"
  len=${#mask}
  idx=$((len - tag_id + 1))

  [ "$idx" -ge 1 ] || return 1
  [ "$idx" -le "$len" ] || return 1

  [ "$(printf '%s\n' "$mask" | cut -c "$idx")" = "1" ]
}

# `mmsg -g -t` exposes three tag bitmasks. In practice the first one is the
# occupied-tag mask, which is enough for "switch if browser window exists".
occupied_mask="$(
  mmsg -g -t 2>/dev/null | awk '
    $2 == "tags" && $3 ~ /^[01]+$/ && $4 ~ /^[01]+$/ && $5 ~ /^[01]+$/ {
      occupied = $3
    }
    END {
      print occupied
    }
  '
)"

if [ -n "$occupied_mask" ] && tag_has_clients "$occupied_mask" "$browser_tag"; then
  exec mmsg -s -t "$browser_tag"
fi

mmsg -s -t "$browser_tag"

if command -v gtk-launch >/dev/null 2>&1 && gtk-launch "$desktop_id" >/dev/null 2>&1; then
  exit 0
fi

"$browser_cmd" >/dev/null 2>&1 &
