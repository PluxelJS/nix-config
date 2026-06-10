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
mmsg -g >"$tmp_file" 2>/dev/null || exit 1
mv "$tmp_file" "$raw_file"

# 2) 提取关键信息并“追加写入”日志（不覆盖）
#    只抓常用字段：title/appid/last_layer/layout/floating/fullscreen/scale_factor
summary="$(
  awk -v ts="$ts" '
    $2=="title"        {title=$0; sub(/^[^ ]+ title /,"",title)}
    $2=="appid"        {appid=$3}
    $2=="last_layer"   {last_layer=$3}
    $2=="layout"       {layout=$3}
    $2=="floating"     {floating=$3}
    $2=="fullscreen"   {fullscreen=$3}
    $2=="scale_factor" {scale=$3}
    END {
      if (title=="") title="-";
      if (appid=="") appid="-";
      if (last_layer=="") last_layer="-";
      if (layout=="") layout="-";
      if (floating=="") floating="-";
      if (fullscreen=="") fullscreen="-";
      if (scale=="") scale="-";
      printf "ts=%s | appid=%s | floating=%s | fullscreen=%s | layout=%s | layer=%s | scale=%s | title=%s\n", ts, appid, floating, fullscreen, layout, last_layer, scale, title;
    }
  ' "$raw_file"
)"

if [ -f "$log_file" ] && [ -s "$log_file" ]; then
  # If previous write missed a trailing newline, separate entries cleanly.
  if [ "$(tail -c 1 "$log_file" 2>/dev/null || true)" != "" ]; then
    printf '\n' >>"$log_file"
  fi
fi
printf '%s' "$summary" >>"$log_file"

printf '%s\n' "$log_file"
printf '%s\n' "$raw_file"
