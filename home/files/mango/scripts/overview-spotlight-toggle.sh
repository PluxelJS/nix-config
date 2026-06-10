#!/bin/sh
set -eu

# 最接近 niri 的“总览里直接打字搜索”的体验（MangoWC 版）：
# - 切换 MangoWC 总览
# - 同时切换 DMS Spotlight（Spotlight 自带输入焦点，直接打字）
#
# 注意：这是 best-effort；如果两者状态不同步，用 Esc 退出或分别触发即可。

mmsg -d toggleoverview
dms ipc call spotlight toggle
