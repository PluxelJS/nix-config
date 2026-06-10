#!/bin/sh
set -eu

# screenshot: mark-shot wrapper
# - 保留 `region|screen` 两种入口
# - `clip` 映射为进入 Mark Shot 后默认选中 `move`，便于快速框选后复制
# - `annotate` 映射为进入 Mark Shot 后默认选中 `pen`，保持“开局就标注”的手感

mode="${1:-region}" # region|screen
action="${2:-clip}" # clip|annotate

if ! command -v mark-shot >/dev/null 2>&1; then
  command -v notify-send >/dev/null 2>&1 && notify-send "Screenshot" "mark-shot 未安装，请先应用 Home Manager"
  echo "mark-shot 未安装" >&2
  exit 127
fi

tool="move"
case "$action" in
  annotate) tool="pen" ;;
esac

case "$mode" in
  screen)
    exec mark-shot --fullscreen --fullscreen-default-tool "$tool"
    ;;
  region|*)
    exec mark-shot --default-tool "$tool"
    ;;
esac
