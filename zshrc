#PATH config
export PATH=/usr/local/gdatacopier:/opt/local/bin:/bin:/usr/local/bin:/usr/bin:/opt/local/sbin::$HOME/bin:/sbin:/usr/sbin:/usr/local/sbin:$PATH
export MANPATH=/opt/local/man:/usr/local/man:$MANPATH
export TERM=xterm-color
export LANG=ja_JP.UTF-8
export XDG_DATA_HOME=/opt/local/share


#Prompt display config
PROMPT="%/%% "
PROMPT2="%_%% "
SPROMPT="%r is correct? [n,y,a,e]: "

#config history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt hist_ignore_dups     # ignore duplication command history list
setopt share_history        # share command history data

#search history config
autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^n" history-beginning-search-forward-end

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

#alias
alias ls='ls -G'
alias ll='ls -lG'
alias rm='rm -i'

#complement config
autoload -U compinit
compinit

#colorのロード
autoload -U colors

#補完のときに大文字小文字を区別しない
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

#if .zshrc.mine exist, do source this
[ -f ~/.zshrc.mine ] && source ~/.zshrc.mine
