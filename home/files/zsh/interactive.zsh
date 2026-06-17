# Shell interaction helpers managed by Home Manager.
#
# This file intentionally carries over the useful parts of the old `~/.config/zsh`
# setup so that Nix can fully replace it. After switching, the old HyDE files are
# no longer runtime dependencies. Atuin now owns interactive history search, so
# this file focuses on editor widgets and file/directory helpers.

setopt INTERACTIVE_COMMENTS
setopt HIST_VERIFY
setopt AUTO_PUSHD

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --theme="Catppuccin Macchiato" --style=plain --paging=never --color auto'
  alias -g -- --help='--help 2>&1 | bat --language=help --style=plain --paging=never --color always'
fi

if command -v eza >/dev/null 2>&1; then
  alias l='eza -lh --icons=auto'
  alias ll='eza -lha --icons=auto --sort=name --group-directories-first'
  alias ld='eza -lhD --icons=auto'
  alias lt='eza --icons=auto --tree'
fi

o() {
  if [[ $# -eq 0 ]]; then
    xdg-open . >/dev/null 2>&1 &
    return
  fi

  local arg
  for arg in "$@"; do
    xdg-open "$arg" >/dev/null 2>&1 &
  done
}

_term_edit_cheatsheet() {
  local data_full=$'\e[1;36m 终端编辑快捷键小抄 \e[0m

\e[1;35m► 我的入口\e[0m          \e[1;33m► 文本编辑\e[0m            \e[1;32m► 系统控制\e[0m
F1      帮助提示          \e[1;32mCtrl+W  删前单词\e[0m      Ctrl+C  终止命令
Alt+E   Env / Path 插入   Ctrl+U  删到行首          Ctrl+Z  暂停进程
Alt+S   sudo 切换         Ctrl+K  删到行尾          Ctrl+D  退出Shell
Ctrl+R  Atuin 历史        Ctrl+Y  粘贴内容          Ctrl+L  清屏
Esc Esc sudo 兼容入口     \e[1;36m► 文本选择\e[0m            bg      后台运行
Alt+A   Opencode TUI      \e[1;34m► 光标导航\e[0m            fg      前台恢复
                         \e[3m双击单词\e[0m → 选择整个单词
                         \e[3m三击行\e[0m → 选择整行
                         Ctrl+Shift+C → 复制选中
                         Ctrl+Shift+V → 粘贴

Ctrl+A  行首              \e[1;36m► Alt+E\e[0m
Ctrl+E  行尾              默认 env；Tab 直进 yazi
Ctrl+T  交换字符          自动替换当前 $变量 / 路径片段
↑/Ctrl+P 历史上翻策略     Space / Enter / o 在 yazi 里确认插入
Alt+B   后移一词          Esc / q 取消返回
Alt+F   前移一词

  \e[1;35m► sudo 切换\e[0m
Alt+S   显式切换 sudo 前缀
空命令行 先取上一条命令，再加 sudo
再次触发 去掉 sudo 前缀
Esc Esc  兼容旧入口

  \e[1;35m► 标签页策略\e[0m
Ghostty  Ctrl+T 新标签 / Ctrl+Shift+W 关标签 / Ctrl+PgUp,PgDn 切换
Dolphin  Ctrl+T 新标签 / Ctrl+W 关标签 / Ctrl+Shift+T 恢复关闭标签
原则     Ctrl+W 保留给 shell 删前一个单词，不给终端层抢占

  \e[1;35m► AI\e[0m
Shell    Alt+A 进入 opencode TUI
Opencode Ctrl+X 为 leader；/help 或 Ctrl+X H 查看内置帮助

  \e[1;35m► 命令补充\e[0m
keys     打开快捷键帮助
o        打开当前目录或指定路径
z        按使用频率跳转目录
f / fix  修正上一条命令
oc       启动 opencode
ffcd     模糊切目录
ffe      模糊找文件并编辑
ffec     按内容筛文件并编辑
gst / gl Git 状态 / 简洁日志
'

  local -r tsv=$'我的入口\t\e[33mF1\e[0m\t帮助提示
我的入口\t\e[33mAlt+E\e[0m\tEnv / Path 插入
我的入口\t\e[33mAlt+S\e[0m\tsudo 切换
我的入口\t\e[33mAlt+A\e[0m\tOpencode TUI
我的入口\t\e[33mCtrl+R\e[0m\tAtuin 历史
我的入口\t\e[33mEsc Esc\e[0m\tsudo 兼容入口
文本编辑\t\e[32mCtrl+W\e[0m\t删前单词
文本编辑\t\e[32mCtrl+U\e[0m\t删到行首
文本编辑\t\e[32mCtrl+K\e[0m\t删到行尾
文本编辑\t\e[32mCtrl+Y\e[0m\t粘贴内容
文本选择\t\e[36m鼠标拖动\e[0m\t选择并自动复制
文本选择\t\e[36m双击单词\e[0m\t选择整个单词
文本选择\t\e[36m三击行\e[0m\t选择整行
文本选择\t\e[36mCtrl+Shift+C\e[0m\t复制选中
文本选择\t\e[36mCtrl+Shift+V\e[0m\t粘贴
光标导航\t\e[34mCtrl+A\e[0m\t行首
光标导航\t\e[34mCtrl+E\e[0m\t行尾
光标导航\t\e[34mCtrl+T\e[0m\t交换字符
光标导航\t\e[34m↑ / Ctrl+P\e[0m\t统一历史上翻策略
光标导航\t\e[34mAlt+B\e[0m\t后移一词
光标导航\t\e[34mAlt+F\e[0m\t前移一词
Alt+E\t\e[35m默认\e[0m\t先进入环境变量选择
Alt+E\t\e[35mTab\e[0m\t从 env 面板切到 yazi 路径选择
Alt+E\t\e[35m替换\e[0m\t自动覆盖当前 $变量 / 路径片段
Alt+E\t\e[35mSpace\e[0m\tyazi 内选择项
Alt+E\t\e[35mEnter / o\e[0m\tyazi 内确认插入
Alt+E\t\e[35mEsc / q\e[0m\t取消 / 返回
sudo\t\e[35mAlt+S\e[0m\t显式切换 sudo 前缀
sudo\t\e[35m空行触发\e[0m\t先取上一条命令再切换 sudo
sudo\t\e[35m再次触发\e[0m\t切回非 sudo 版本
sudo\t\e[35mEsc Esc\e[0m\t兼容旧入口
标签页策略\t\e[35mGhostty\e[0m\tCtrl+T 新标签 / Ctrl+Shift+W 关标签 / Ctrl+PgUp,PgDn 切换
标签页策略\t\e[35mDolphin\e[0m\tCtrl+T 新标签 / Ctrl+W 关标签 / Ctrl+Shift+T 恢复
标签页策略\t\e[35m原则\e[0m\tCtrl+W 保留给 shell 删前一个单词
AI\t\e[35mShell\e[0m\tAlt+A 进入 opencode TUI
AI\t\e[35mOpencode\e[0m\tCtrl+X leader；/help 或 Ctrl+X H 查看帮助
命令补充\t\e[35mkeys\e[0m\t打开快捷键帮助
命令补充\t\e[35mo\e[0m\t打开当前目录或指定路径
命令补充\t\e[35mz\e[0m\t按使用频率跳转目录
命令补充\t\e[35mf / fix\e[0m\t修正上一条命令
命令补充\t\e[35moc\e[0m\t启动 opencode
命令补充\t\e[35mffcd\e[0m\t模糊切目录
命令补充\t\e[35mffe\e[0m\t模糊找文件并编辑
命令补充\t\e[35mffec\e[0m\t按内容筛文件并编辑
命令补充\t\e[35mgst / gl\e[0m\tGit 状态 / 简洁日志
系统控制\t\e[31mCtrl+C\e[0m\t终止命令
系统控制\t\e[31mCtrl+Z\e[0m\t暂停进程 (bg/fg)
系统控制\t\e[31mCtrl+D\e[0m\t退出 Shell
系统控制\t\e[31mCtrl+L\e[0m\t清屏
系统控制\t\e[31mbg / fg\e[0m\t后台 / 前台恢复
'

  if command -v fzf >/dev/null 2>&1; then
    local tmp
    tmp="$(mktemp)"
    printf '%b' "$data_full" > "$tmp"
    printf '%b' "$tsv" \
      | fzf --ansi --no-sort --border=none --height=95% --layout=reverse \
            --prompt='Cheats ⌨  ' \
            --header=$'输入关键字过滤；Tab 多选；Enter/ESC 退出' --header-first \
            --delimiter='\t' --with-nth=1,2,3 --tabstop=24 \
            --preview="cat $tmp" --preview-window=up,70%,border-rounded,wrap \
            --bind='ctrl-l:clear-query,alt-/:toggle-preview,change:top' \
            --no-multi
    rm -f "$tmp"
  else
    printf '%b' "$data_full" | LESS='-R' less
  fi

  zle && zle -I
}

zle -N term-help _term_edit_cheatsheet

keys() {
  _term_edit_cheatsheet
}

_fzf_env_browser() {
  emulate -L zsh
  setopt pipefail no_aliases

  local out key sel name env_frag query inserted
  local -a lines

  env_frag="$(__last_env_fragment)"
  query="${env_frag#\$\{}"
  query="${query#\$}"

  out="$(
    env \
    | sort -f \
    | fzf --prompt='ENV > ' \
          --preview 'echo {} | cut -d= -f2-' \
          --preview-window=down:4:wrap \
          --height=60% --border --reverse \
          --header=$'Enter 插入环境变量；Tab 切到 yazi 路径选择；Esc 取消' \
          ${query:+--query="$query"} \
          --expect=tab
  )" || {
    zle -I
    return 0
  }

  lines=("${(@f)out}")
  key="${lines[1]}"
  sel="${lines[2]}"

  if [[ "$key" == "tab" ]]; then
    _quick_insert_with_yazi
    return $?
  fi

  name="${sel%%=*}"
  if [[ -n "$name" ]]; then
    if [[ "$env_frag" == '$'*'{'* ]]; then
      inserted="\${${name}}"
    else
      inserted="$""$name"
    fi
    _insert_shell_words --replace-frag "$env_frag" "$inserted"
  fi
  zle redisplay
}

_insert_shell_words() {
  local replace_frag="" frag joiner joined
  local -a quoted
  local item

  if [[ "${1:-}" == "--replace-frag" ]]; then
    replace_frag="${2:-}"
    shift 2
  fi

  for item in "$@"; do
    [[ -n "$item" ]] || continue
    quoted+=("${(qq)item}")
  done

  [[ ${#quoted[@]} -gt 0 ]] || return 1

  joined="${(j: :)quoted}"

  if [[ -n "$replace_frag" ]]; then
    LBUFFER="${LBUFFER%$replace_frag}${joined}"
  else
    joiner="$(__shell_insert_joiner)"
    LBUFFER+="${joiner}${joined}"
  fi
}

_quick_insert_with_yazi() {
  emulate -L zsh
  setopt pipefail no_aliases

  if ! command -v yazi >/dev/null 2>&1; then
    zle -M "未找到 yazi"
    return 1
  fi

  local chooser frag expanded start_dir base_dir
  local -a selected
  local item

  chooser="$(mktemp)"
  start_dir="$PWD"
  frag="$(__last_fragment)"

  if [[ -n "$frag" ]]; then
    expanded="${~frag}"
    if [[ -d "$expanded" ]]; then
      start_dir="$expanded"
    else
      base_dir="${expanded:h}"
      if [[ "$base_dir" == "." ]]; then
        base_dir="$PWD"
      fi
      [[ -d "$base_dir" ]] && start_dir="$base_dir"
    fi
  fi

  zle -M "yazi: Space 选择，Enter/o 确认插入，q/Esc 取消"
  yazi "$start_dir" --chooser-file "$chooser" < /dev/tty > /dev/tty

  if [[ -s "$chooser" ]]; then
    while IFS= read -r item; do
      [[ -n "$item" ]] && selected+=("$item")
    done < "$chooser"
    _insert_shell_words --replace-frag "$frag" "${selected[@]}"
  fi

  rm -f "$chooser"
  zle redisplay
}

_quick_insert_dispatch() {
  _fzf_env_browser
}

zle -N quick-insert _quick_insert_dispatch

_sudo_command_line() {
  if [[ -z "$BUFFER" ]]; then
    zle up-history
  fi

  if [[ "$BUFFER" == sudo\ * ]]; then
    BUFFER="${BUFFER#sudo }"
  elif [[ -n "$BUFFER" ]]; then
    BUFFER="sudo $BUFFER"
  fi

  CURSOR=${#BUFFER}
  zle -I
}

zle -N sudo-command-line _sudo_command_line

typeset -gi __smart_history_up_count=0

_smart_history_up() {
  emulate -L zsh

  local threshold="${ZSH_ATUIN_UP_THRESHOLD:-1}"
  if [[ ! "$threshold" =~ '^[0-9]+$' ]] || (( threshold < 1 )); then
    threshold=1
  fi

  if [[ "$LASTWIDGET" == smart-history-up ]]; then
    (( __smart_history_up_count++ ))
  else
    __smart_history_up_count=1
  fi

  if (( threshold == 1 || __smart_history_up_count >= threshold )); then
    __smart_history_up_count=0
    zle atuin-up-search
    return
  fi

  zle up-history
}

zle -N smart-history-up _smart_history_up

_opencode_tui_widget() {
  emulate -L zsh
  setopt pipefail no_aliases

  if ! command -v opencode >/dev/null 2>&1; then
    zle -M "未找到 opencode"
    return 1
  fi

  zle -I
  opencode < /dev/tty > /dev/tty 2>&1
  zle redisplay
}

zle -N opencode-tui _opencode_tui_widget

ffcd() {
  _fuzzy_change_directory "$@"
}

ffe() {
  _fuzzy_edit_search_file "$@"
}

ffec() {
  _fuzzy_edit_search_file_content "$@"
}

_fuzzy_change_directory() {
  local initial_query="$1"
  local selected_dir
  local -a fzf_options
  local -a dir_cmd

  fzf_options=('--preview=ls -p {}' '--preview-window=right:60%' '--height=80%' '--layout=reverse' '--cycle')
  dir_cmd=(fd --type d --hidden --follow --strip-cwd-prefix --exclude .git --exclude node_modules --exclude .venv --exclude target --exclude .cache)

  if [[ -n "$initial_query" ]]; then
    fzf_options+=("--query=$initial_query")
  fi

  selected_dir="$("${dir_cmd[@]}" | fzf "${fzf_options[@]}")" || return 1

  if [[ -n "$selected_dir" && -d "$selected_dir" ]]; then
    cd "$selected_dir" || return 1
  else
    return 1
  fi
}

_fuzzy_edit_search_file() {
  local selected_file
  selected_file="$(
    fd --type f --hidden --follow --exclude .git \
      | fzf --preview 'bat --color=always --style=plain --paging=never {} 2>/dev/null || sed -n "1,200p" {}'
  )" || return

  [[ -n "$selected_file" ]] && "${EDITOR:-nvim}" "$selected_file"
}

_fuzzy_edit_search_file_content() {
  local selected_file
  local preview_cmd
  local -a source_cmd
  if command -v bat >/dev/null 2>&1; then
    preview_cmd=('bat --color always --style=plain --paging=never {}')
  else
    preview_cmd=('cat {}')
  fi

  if [[ -n "${1:-}" ]]; then
    source_cmd=(
      rg --files-with-matches --hidden --follow --smart-case
      --glob '!.git' --glob '!node_modules' --glob '!.venv' --glob '!target' --glob '!.cache'
      -- "${1}" .
    )
  else
    source_cmd=(
      fd --type f --hidden --follow --strip-cwd-prefix
      --exclude .git --exclude node_modules --exclude .venv --exclude target --exclude .cache
    )
  fi

  selected_file="$("${source_cmd[@]}" | fzf --height "80%" --layout=reverse --cycle --preview-window right:60% --preview "${preview_cmd[@]}")" || return

  if [[ -n "$selected_file" ]]; then
    "${EDITOR:-nvim}" "$selected_file"
  else
    print -r -- "No file selected or search returned no results."
  fi
}

__last_fragment() {
  local buf="$LBUFFER"
  if [[ "$buf" =~ ([A-Za-z0-9._+\-/:@%~]+)$ ]]; then
    print -r -- "${match[1]}"
  else
    print -r -- ""
  fi
}

__last_env_fragment() {
  local buf="$LBUFFER"
  if [[ "$buf" =~ (\$\{?[A-Za-z_][A-Za-z0-9_]*)$ ]]; then
    print -r -- "${match[1]}"
  else
    print -r -- ""
  fi
}

__shell_insert_joiner() {
  local last_char

  [[ -n "$LBUFFER" ]] || {
    print -r -- ""
    return 0
  }

  last_char="${LBUFFER[-1]}"
  case "$last_char" in
    ' '|$'\t'|$'\n'|'/'|':'|'='|'('|')'|'['|']'|'{'|'}')
      print -r -- ""
      ;;
    *)
      print -r -- " "
      ;;
  esac
}

if command -v bun >/dev/null 2>&1 && [[ -s "$HOME/.bun/_bun" ]]; then
  source "$HOME/.bun/_bun"
fi

alias -- oc=opencode
