# PATH指定
export GEM_HOME=~/.gem/ruby/1.8/

#Prompt display config
PROMPT="%/%% "
PROMPT2="%_%% "
SPROMPT="%r is correct? [n,y,a,e]: "

#config history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt hist_ignore_dups      # ignore duplication command history list
setopt share_history         # share command history data
setopt hist_ignore_all_dups  # 重複するコマンド行は古い方を削除
setopt hist_ignore_space     # スペースで始まるコマンド行はヒストリリストから削除
                             # (→ 先頭にスペースを入れておけば、ヒストリに保存されない)
unsetopt hist_verify         # ヒストリを呼び出してから実行する間に一旦編集可能を止める
setopt hist_reduce_blanks    # 余分な空白は詰めて記録
setopt hist_save_no_dups     # ヒストリファイルに書き出すときに、古いコマンドと同じものは無視する。
setopt hist_no_store         # historyコマンドは履歴に登録しない



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

#alias
alias ls='ls -G'
alias ll='ls -lG'
alias rm='rm -i'

#complement config
fpath=(~/.zsh/functions/Completion ${fpath})
autoload -U compinit
compinit -u

#colorのロード
autoload -U colors

#補完のときに大文字小文字を区別しない
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# 一部のコマンドライン定義は、展開時に時間のかかる処理を行う -- apt-get, dpkg (Debian), rpm (Redhat), urpmi (Mandrake), perlの-Mオプション, bogofilter (zsh 4.2.1以降), fink, mac_apps (MacOS X)(zsh 4.2.2以降)
zstyle ':completion:*' use-cache true

unsetopt promptcr            # 改行のない出力をプロンプトで上書きするのを防ぐ

# perlbrew
source ~/perl5/perlbrew/etc/bashrc

# coreutils
# source /usr/local/Cellar/coreutils/8.5/aliases

#if .zshrc.mine exist, do source this
[ -f ~/.zshrc.mine ] && source ~/.zshrc.mine

#if .zshrc.function exist, do source this
[ -f ~/.zshrc.function ] && source ~/.zshrc.function
