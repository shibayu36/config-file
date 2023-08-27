# 一定時間を超えたら自動でtimeする
export REPORTTIME=10

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
# コマンド実行時にコメントを使えるように
setopt interactivecomments
# dotfilesなどがマッチ&補完されるように
setopt globdots

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
fpath=(~/.zsh/functions/Completion /usr/local/share/zsh/functions/ ${fpath})
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

# dockerの補完
zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes

# setting for cdd
source ~/.zsh/functions/cdd
function chpwd() {
    _reg_pwd_screennum
}

# setting for peco
for f (~/.zsh/peco-sources/*) source "${f}" # load peco sources
bindkey '^@' peco-cd
bindkey '^r' peco-select-history
bindkey '^x^b' peco-git-recent-branches
bindkey '^xb' peco-git-recent-all-branches
bindkey '^xB' peco-git-recent-pull-requests
bindkey '^x^h' peco-complete-mackerel-host-ip
bindkey '^x^f' peco-open-code-by-git-ls-files

# ------------- setting for tmux ----------------------------
[ -n "$TMUX" ] && export TERM=screen-256color

# 表示の設定
[ -e ~/.zsh/appearance.zsh ] && source ~/.zsh/appearance.zsh

# direnv
eval "$(direnv hook zsh)"
if direnv status | grep -q 'Loaded RC'; then
    direnv reload
fi

#if .zshrc.mine exist, do source this
[ -f ~/.zshrc.mine ] && source ~/.zshrc.mine

#if .zshrc.function exist, do source this
[ -f ~/.zshrc.function ] && source ~/.zshrc.function

## create emacs env file
# perl -wle \
#     'do { print qq/(setenv "$_" "$ENV{$_}")/ if exists $ENV{$_} } for @ARGV' \
#     PATH > ~/.emacs.d/shellenv.el

autoload -Uz add-zsh-hook

# tmuxにもWINDOWを設定
if [ "$TMUX" != "" ] ; then
    export WINDOW=`tmux respawn-window 2>&1 > /dev/null | cut -d ':' -f 3`
fi

#alias
alias ls='ls -a -G'
alias ll='ls -a -lG'
alias rm='rm -i'
alias cg='code $(git ls-files | peco --query "$LBUFFER")'
alias sed='gsed'
alias awk='gawk'

# alias git=hub
alias glgg='git logg'
alias glg='git logg | head'
# compdef hub=git

# alias for git
alias gst='git st'
alias gch='git cherry -v'
alias gg='git grep -H --break -n --recurse-submodule'
alias ggg='git grep -H --break -C 5 -n --recurse-submodule'

alias P='percol --match-method migemo'

alias ssh='TERM=xterm-256color ssh'

# alias for perl
alias ce='carton exec --'

alias pc='proxychains4'

# peco
alias cdsrc='cd $(ghq list --full-path | peco --query "$LBUFFER")'
p() { peco | while read LINE; do $@ $LINE; done }

# psを選択して殺す
alias pskl="ps aux | peco | awk '{ print \$2 }' | xargs kill -9"

# gibo
alias gibol='gibo -l | sed "/=/d" | tr "\t", "\n" | sed "/^$/d" | sort | peco | xargs gibo'

# IntelliJ
alias ij="open -a /Applications/IntelliJ\ IDEA\ CE.app"

# alias for emacsclient
alias e='emacsclient -n'

alias c='code'

# editor
export EDITOR='code -w'


test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# 文字化けした時の対処用
alias clear2="echo -e '\026\033c'"

alias tssh="tssh --ssh-option '-o StrictHostKeyChecking=no'"
alias pctssh="proxychains4 ssh"

# ---------------- setting for zplug --------------------------
export ZPLUG_HOME=/opt/homebrew/opt/zplug
source $ZPLUG_HOME/init.zsh

zplug "Tarrasch/zsh-autoenv"

# Install plugins if there are plugins that have not been installed
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

# プラグインを読み込み、コマンドにパスを通す
zplug load

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/shibayu36/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/shibayu36/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/shibayu36/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/shibayu36/google-cloud-sdk/completion.zsh.inc'; fi

export PATH="$HOME/.poetry/bin:$PATH"

# copilot for cli
eval "$(github-copilot-cli alias -- "$0")"
