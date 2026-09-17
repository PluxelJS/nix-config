#!/bin/sh
set -eu

browser_tag="${1:-4}"
desktop_id="${BROWSER_DESKTOP_ID:-zen}"
browser_cmd="${BROWSER_CMD:-zen-browser}"

# Query the compositor's current JSON API, scoped to the focused monitor.
case "$browser_tag" in
  ''|*[!0-9]*) exit 2 ;;
esac
occupied="$(mmsg get all-monitors | jq -r --argjson tag "$browser_tag" '
  any(.monitors[] | select(.active) | .tags[];
      .index == $tag and .client_count > 0)
')"

mmsg dispatch view,"$browser_tag"
[ "$occupied" = true ] && exit 0

if command -v gtk-launch >/dev/null 2>&1 && gtk-launch "$desktop_id" >/dev/null 2>&1; then
  exit 0
fi

"$browser_cmd" >/dev/null 2>&1 &
