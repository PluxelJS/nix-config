#!/bin/sh
set -eu

interval="${MANGO_LID_OUTPUT_INTERVAL:-1}"

lid_state() {
  for state_file in /proc/acpi/button/lid/*/state; do
    [ -r "$state_file" ] || continue
    awk '{ print $NF; exit }' "$state_file"
    return 0
  done

  printf '%s\n' open
}

internal_outputs() {
  wlr-randr 2>/dev/null | awk '
    /^[^[:space:]]/ && $1 ~ /^(eDP|LVDS|DSI)-/ {
      print $1
    }
  '
}

set_internal_outputs() {
  action="$1"

  internal_outputs | while IFS= read -r output; do
    [ -n "$output" ] || continue
    wlr-randr --output "$output" "$action" >/dev/null 2>&1 || true
  done
}

apply_lid_state() {
  case "$1" in
    closed)
      set_internal_outputs --off
      ;;
    open)
      set_internal_outputs --on
      ;;
  esac
}

last_state=""

while :; do
  state="$(lid_state)"

  if [ "$state" != "$last_state" ]; then
    apply_lid_state "$state"
    last_state="$state"
  fi

  sleep "$interval"
done
