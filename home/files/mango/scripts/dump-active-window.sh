#!/bin/sh
set -eu

out_dir="${XDG_CACHE_HOME:-"$HOME/.cache"}/mango"
raw_dir="$out_dir/active-window"
log_file="$out_dir/active-windows.log"

mkdir -p "$raw_dir"

ts="$(date -Iseconds | tr ':' '-')"
raw_file="$raw_dir/$ts.txt"
tmp_file="$raw_dir/.tmp.$$.txt"

# 1) 先保存原始 dump（便于回溯）
mmsg get focusing-client >"$tmp_file" 2>/dev/null || exit 1
mv "$tmp_file" "$raw_file"

# Preserve the JSON response and log the fields provided by the current API.
summary="$(jq -cr --arg ts "$ts" '
  {ts: $ts, appid, title, monitor, tags,
   floating: .is_floating, fullscreen: .is_fullscreen}
' "$raw_file")"

if [ -f "$log_file" ] && [ -s "$log_file" ]; then
  # If previous write missed a trailing newline, separate entries cleanly.
  if [ "$(tail -c 1 "$log_file" 2>/dev/null || true)" != "" ]; then
    printf '\n' >>"$log_file"
  fi
fi
printf '%s\n' "$summary" >>"$log_file"

printf '%s\n' "$log_file"
printf '%s\n' "$raw_file"
