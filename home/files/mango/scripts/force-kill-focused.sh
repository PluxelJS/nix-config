#!/bin/sh
set -eu

cache_dir="${XDG_CACHE_HOME:-"$HOME/.cache"}/mango"
log_file="$cache_dir/force-kill-focused.log"

mkdir -p "$cache_dir"

ts="$(date -Iseconds)"
tmp_file="$(mktemp "${TMPDIR:-/tmp}/mango-force-kill.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

if ! mmsg -g >"$tmp_file" 2>/dev/null; then
  printf '%s | error=mmsg_unavailable\n' "$ts" >>"$log_file"
  exit 1
fi

appid="$(
  awk '$2=="appid" {print $3; exit}' "$tmp_file"
)"
title="$(
  awk '$2=="title" {sub(/^[^ ]+ title /,""); print; exit}' "$tmp_file"
)"

normalize() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9._-]/ /g'
}

add_name() {
  name="$1"
  [ -n "$name" ] || return 0
  case " $candidates " in
    *" $name "*) return 0 ;;
  esac
  candidates="${candidates}${candidates:+ }$name"
}

candidates=""
appid_lc="$(normalize "$appid" | tr ' ' '\n' | sed '/^$/d')"

for token in $appid_lc; do
  add_name "$token"
  add_name "${token##*.}"
done

case "$appid" in
  org.kde.dolphin|dolphin|Dolphin) add_name "dolphin" ;;
  org.telegram.desktop|telegram-desktop|telegramdesktop) add_name "telegram-desktop" ;;
  com.qq.QQ|QQ) add_name "QQ" ;;
  org.gnome.eog|eog) add_name "eog" ;;
  org.pulseaudio.pavucontrol|pavucontrol) add_name "pavucontrol" ;;
  io.missioncenter.MissionCenter) add_name "missioncenter" ;;
  org.mozilla.firefox|firefox) add_name "firefox" ;;
  zen|app.zen_browser.zen|zen-browser) add_name "zen-browser"; add_name "zen" ;;
  code|codium|vscodium|com.visualstudio.code) add_name "code"; add_name "codium"; add_name "vscodium" ;;
  steam) add_name "steam" ;;
  steam_app_*|steam_proton|wine|wine64|*.exe|*.EXE) add_name "steam"; add_name "wine"; add_name "wine64" ;;
esac

matched_pids=""

for name in $candidates; do
  exact="$(pgrep -x "$name" || true)"
  if [ -n "$exact" ]; then
    matched_pids="$matched_pids $exact"
    continue
  fi

  pattern="(^|.*/)${name}([[:space:]]|$)"
  fuzzy="$(pgrep -f "$pattern" || true)"
  if [ -n "$fuzzy" ]; then
    matched_pids="$matched_pids $fuzzy"
  fi
done

matched_pids="$(
  printf '%s\n' "$matched_pids" \
    | tr ' ' '\n' \
    | sed '/^$/d' \
    | sort -u
)"

if [ -z "$matched_pids" ]; then
  printf '%s | appid=%s | title=%s | result=no_match\n' "$ts" "${appid:--}" "${title:--}" >>"$log_file"
  exit 1
fi

printf '%s\n' "$matched_pids" | xargs -r kill -TERM
sleep 0.4

still_running=""
for pid in $matched_pids; do
  if kill -0 "$pid" 2>/dev/null; then
    still_running="${still_running}${still_running:+ }$pid"
  fi
done

if [ -n "$still_running" ]; then
  printf '%s\n' "$still_running" | tr ' ' '\n' | xargs -r kill -KILL
fi

printf '%s | appid=%s | title=%s | pids=%s\n' "$ts" "${appid:--}" "${title:--}" "$(printf '%s' "$matched_pids" | tr '\n' ',' | sed 's/,$//')" >>"$log_file"
