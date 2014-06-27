# env config
export JRUBY_HOME=/usr/local/jruby
export MANPATH=/opt/local/man:/usr/local/man:/usr/share/man:/usr/local/share/man:$MANPATH
export TERM=xterm-color
export LC_ALL=en_US.UTF-8
export LANG=ja_JP.UTF-8
export XDG_DATA_HOME=/opt/local/share
export PERLDOC_PAGER=lv
export RLWRAP_HOME=$HOME/.rlwrap
export XDG_DATA_HOME=/usr/local/share
export XDG_DATA_DIRS=/usr/local/share

# export DYLD_FALLBACK_LIBRARY_PATH=/usr/local/lib:/usr/local/mysql/lib:$DYLD_FALLBACK_LIBRARY_PATH

# Path config
export PATH=/Users/shibayu36/development/Hatena/servers/bin:/usr/local/share/python:$HOME/bin:/usr/local/bin:/usr/local/sbin:/opt/local/bin:/usr/bin:/usr/sbin:/opt/local/sbin:/bin:/sbin:$JRUBY_HOME/bin

# anyenv
export PATH="$HOME/.anyenv/bin:$PATH"
eval "$(anyenv init -)"

# Go PATH
export GOPATH=$HOME/development/go
export GOROOT=/usr/local/opt/go/libexec
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

# Docker env
export DOCKER_HOST=tcp://localhost:4243

#Prompt display config
PROMPT="%/%% "
PROMPT2="%_%% "
SPROMPT="%r is correct? [n,y,a,e]: "

#config history
HISTFILE=~/.zsh_history
HISTSIZE=10000000
SAVEHIST=10000000
setopt hist_ignore_dups      # ignore duplication command history list
setopt share_history         # share command history data
setopt hist_ignore_all_dups  # 重複するコマンド行は古い方を削除
setopt hist_ignore_space     # スペースで始まるコマンド行はヒストリリストから削除
                             # (→ 先頭にスペースを入れておけば、ヒストリに保存されない)
unsetopt hist_verify         # ヒストリを呼び出してから実行する間に一旦編集可能を止める
setopt hist_reduce_blanks    # 余分な空白は詰めて記録
setopt hist_save_no_dups     # ヒストリファイルに書き出すときに、古いコマンドと同じものは無視する。
setopt hist_no_store         # historyコマンドは履歴に登録しない
## C-sでのヒストリ検索が潰されてしまうため、出力停止・開始用にC-s/C-qを使わない。
setopt no_flow_control
## すぐにヒストリファイルに追記する。
setopt inc_append_history

#search history config
autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^n" history-beginning-search-forward-end
bindkey "^r" history-incremental-pattern-search-backward
bindkey "^s" history-incremental-pattern-search-forward

#needless input cd
setopt auto_cd

#remind dir history
#cd -
setopt auto_pushd

#correct command
setopt correct

#先方予測
#autoload predict-on
#predict-on

#補完時に色表示
#zstyle ':completion:*' list-colors ''

#--prefixのイコールの後の部分を補完
setopt magic_equal_subst

#makeを色づけ
e_normal=`echo -e "\033[0;30m"`
e_RED=`echo -e "\033[1;31m"`
e_BLUE=`echo -e "\033[1;36m"`

function make() {
    LANG=C command make "$@" 2>&1 | sed -e "s@[Ee]rror:.*@$e_RED&$e_normal@g" -e "s@cannot\sfind.*@$e_RED&$e_normal@g" -e "s@[Ww]arning:.*@$e_BLUE&$e_normal@g"
}
function cwaf() {
    LANG=C command ./waf "$@" 2>&1 | sed -e "s@[Ee]rror:.*@$e_RED&$e_normal@g" -e "s@cannot\sfind.*@$e_RED&$e_normal@g" -e "s@[Ww]arning:.*@$e_BLUE&$e_normal@g"
}

# clipboard copy
if which pbcopy >/dev/null 2>&1 ; then 
    # Mac  
    alias -g C='| pbcopy'
elif which xsel >/dev/null 2>&1 ; then 
    # Linux
    alias -g C='| xsel --input --clipboard'
elif which putclip >/dev/null 2>&1 ; then 
    # Cygwin 
    alias -g C='| putclip'
fi

#complement config
fpath=(~/.zsh/functions/Completion ${fpath})
autoload -U compinit
compinit -u

#colorのロード
autoload -U colors

# zargs
autoload zargs

#補完のときに大文字小文字を区別しない
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# 一部のコマンドライン定義は、展開時に時間のかかる処理を行う -- apt-get, dpkg (Debian), rpm (Redhat), urpmi (Mandrake), perlの-Mオプション, bogofilter (zsh 4.2.1以降), fink, mac_apps (MacOS X)(zsh 4.2.2以降)
zstyle ':completion:*' use-cache true

unsetopt promptcr            # 改行のない出力をプロンプトで上書きするのを防ぐ

setopt no_beep # beep

# zmv
autoload -Uz zmv
alias zmv='noglob zmv -W -i'

# copyするやつ
pbcopy-buffer(){
    print -rn $BUFFER | pbcopy
    zle -M "pbcopy: ${BUFFER}" 
}

zle -N pbcopy-buffer
bindkey '^x^p' pbcopy-buffer

## cdr system stuff.
autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
add-zsh-hook chpwd chpwd_recent_dirs
zstyle ':chpwd:*' recent-dirs-max 5000
zstyle ':chpwd:*' recent-dirs-default yes
zstyle ':completion:*' recent-dirs-insert both

# setting for cdd
source ~/.zsh/functions/cdd
function chpwd() {
    _reg_pwd_screennum
}

# seting for zaw
source ~/.zsh/zaw/zaw.zsh
source ~/.zsh/zaw-sources/git-recent-branches.zsh

zstyle ':filter-select' case-insensitive yes

# setting for percol
source ~/.zsh/percol.zsh
bindkey '^x^b' percol-git-recent-branches
bindkey '^xb' percol-git-recent-all-branches

alias gstp="percol-git-status-files"

# setting for peco
for f (~/.zsh/peco-sources/*) source "${f}" # load peco sources
bindkey '^@' peco-cdr
bindkey '^r' peco-select-history

# ---------------- setting for auto-fu --------------------------
# source ~/.zsh/auto-fu/auto-fu.zsh
# zle-line-init () {auto-fu-init;}; zle -N zle-line-init
# zstyle ':completion:*' completer _oldlist _complete
# zle -N zle-keymap-select auto-fu-zle-keymap-select

# perldoc-complete

# alias
alias minicpanm='cpanm --mirror ~/mirrors/minicpan --mirror-only'

# ------------- setting for perlbrew ------------------------
# source ~/perl5/perlbrew/etc/bashrc

# ------------- setting for tmux ----------------------------
[ -n "$TMUX" ] && export TERM=screen-256color
# alias tmux='tmuxx'
# alias tm='tmuxx'
# alias tma='tmux attach'
# alias tml='tmux list-window'

# ----------------------------------------

# 表示の設定
[ -e ~/.zsh/appearance.zsh ] && source ~/.zsh/appearance.zsh

# direnv
eval "$(direnv hook zsh)"

# coreutils
# source /usr/local/Cellar/coreutils/8.5/aliases

#if .zshrc.mine exist, do source this
[ -f ~/.zshrc.mine ] && source ~/.zshrc.mine

#if .zshrc.function exist, do source this
[ -f ~/.zshrc.function ] && source ~/.zshrc.function

## create emacs env file
perl -wle \
    'do { print qq/(setenv "$_" "$ENV{$_}")/ if exists $ENV{$_} } for @ARGV' \
    PATH > ~/.emacs.d/shellenv.el

[[ -r "$HOME/.smartcd_config" ]] && source ~/.smartcd_config

autoload -Uz add-zsh-hook

# tmuxにもWINDOWを設定
if [ "$TMUX" != "" ] ; then
    export WINDOW=`tmux respawn-window 2>&1 > /dev/null | cut -d ':' -f 3`
fi

function cmd-exit-notify() {
    $HOME/bin/cmd-exit-notify.pl `history -n -1`
}
add-zsh-hook precmd cmd-exit-notify

#alias
alias ls='ls -G'
alias ll='ls -lG'
alias rm='rm -i'

alias ack='ack --pager="less -R" -H'

# alias git=hub
alias glgg='git logg'
alias glg='git logg | head'
# compdef hub=git

# alias for git
alias gst='git st'
alias gch='git cherry -v'
alias gg='git grep -H --break'
alias ggg='git grep -H --break -C 5'

alias P='percol --match-method migemo'

alias ssh='TERM=xterm-256color ssh'

# alias for perl
alias ce='carton exec --'

alias pc='proxychains4'
