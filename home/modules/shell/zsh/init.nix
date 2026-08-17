{ config, lib, pkgs, ... }:
let
  zshSnippetDir = ../../../files/zsh;

  miseInit = lib.mkBefore ''
    # mise should initialize early so runtime shims exist before completions
    # and prompt modules inspect the shell environment.
    if command -v mise >/dev/null 2>&1; then
      eval "$(mise activate zsh)"
    fi
  '';

  fzfTabInit = lib.mkOrder 550 ''
    # fzf-tab extends compinit, so its plugin file must be sourced first.
    source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
  '';

  interactiveInit = ''
    # Let Starship be the single prompt owner inside nix-shell / nix develop.
    export NIX_SHELL_PRESERVE_PROMPT=1
    unset GTK_IM_MODULE
    export INPUT_METHOD="''${INPUT_METHOD:-fcitx}"
    export SDL_IM_MODULE="''${SDL_IM_MODULE:-fcitx}"
    export GLFW_IM_MODULE="''${GLFW_IM_MODULE:-ibus}"

    # Nix fully owns the shell now. After switching successfully, the old
    # HyDE-era helper files under ~/.config/zsh are no longer required.
    if [[ -o interactive ]] && [[ -t 0 ]] && [[ -t 1 ]] && [[ $options[zle] = on ]]; then
      source <(${pkgs.fzf}/bin/fzf --zsh)
    fi

    source ${zshSnippetDir}/interactive.zsh
    source ${zshSnippetDir}/startup.zsh

    # Keep only the remaining line-editor helpers that still add value.
    source ${pkgs.zsh-autopair}/share/zsh/zsh-autopair/autopair.zsh
    if [[ -n "''${TERM:-}" ]] && [[ "''${TERM}" != "dumb" ]]; then
      source ${pkgs.zsh-you-should-use}/share/zsh/plugins/you-should-use/you-should-use.plugin.zsh
    fi

    if [[ -o interactive ]] && [[ -t 1 ]] && [[ -n "''${TERM:-}" ]] && [[ "''${TERM}" != "dumb" ]]; then
      eval "$(${pkgs.starship}/bin/starship init zsh)"
    fi

    # fzf-tab is responsible only for completion UI. Search bindings stay in fzf.
    zstyle ':completion:*' menu yes select
    zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*'
    zstyle ':completion:*:descriptions' format '[%d]'
    zstyle ':fzf-tab:*' switch-group 'alt-,' 'alt-.'
    zstyle ':fzf-tab:complete:*' fzf-preview \
      'command ls --color=always --group-directories-first -l -- "$realpath" 2>/dev/null | head -200'
    zmodload zsh/complist 2>/dev/null
    zmodload zsh/terminfo 2>/dev/null

    # Keep only the documented keybindings explicit so they do not depend on
    # old files or hidden muscle memory.
    bindkey '\e\e' sudo-command-line
    bindkey '^[e' quick-insert
    bindkey '^[s' sudo-command-line
    bindkey '^[a' opencode-tui
    bindkey '^e' end-of-line
    bindkey '^t' transpose-chars
    bindkey '^p' up-line-or-history
    bindkey '^[[A' history-up-with-search-hint
    bindkey '^[OA' history-up-with-search-hint
    bindkey '^[r' atuin-prefix-history-search
    bindkey '^w' backward-kill-word
    [[ -n "''${terminfo[kf1]-}" ]] && bindkey "''${terminfo[kf1]}" term-help
    bindkey '\eOP' term-help
    bindkey '\e[11~' term-help

    # Some interactive helpers reinitialize parts of the environment. Re-assert
    # the IM compatibility exports at the end so terminal-launched GUI apps and
    # Flatpak helper shells see the same values as the desktop session.
    unset GTK_IM_MODULE
    export INPUT_METHOD="''${INPUT_METHOD:-fcitx}"
    export SDL_IM_MODULE="''${SDL_IM_MODULE:-fcitx}"
    export GLFW_IM_MODULE="''${GLFW_IM_MODULE:-ibus}"
  '';
in {
  programs.zsh = {
    completionInit = ''
      autoload -U compinit
      mkdir -p ${config.xdg.cacheHome}/zsh
      compinit -d ${config.xdg.cacheHome}/zsh/.zcompdump-$ZSH_VERSION
    '';

    initContent = lib.mkMerge [
      miseInit
      fzfTabInit
      interactiveInit
    ];
  };
}
