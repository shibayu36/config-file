###
# Need this so the prompt will work.
setopt PROMPT_SUBST

###
# color prompt on
autoload -U colors
colors

###
# add-zsh-hook
autoload -Uz add-zsh-hook

###
# for vcs
autoload -Uz vcs_info
zstyle ':vcs_info:*' formats '%s:%b'
zstyle ':vcs_info:*' actionformats '%s:%b' '%m' '<!%a>'

# git 用のフォーマット
# git のときはステージしているかどうかを表示
zstyle ':vcs_info:git:*' formats '%s:%b' '%c%u%m'
zstyle ':vcs_info:git:*' actionformats '%s:%b' '%c%u%m' '<!%a>'
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr "+"    # %c で表示する文字列
zstyle ':vcs_info:git:*' unstagedstr "-"  # %u で表示する文字列

# hooks 設定
# git のときはフック関数を設定する

# formats '(%s)-[%b]' '%c%u %m' , actionformats '(%s)-[%b]' '%c%u %m' '<!%a>'
# のメッセージを設定する直前のフック関数
# 今回の設定の場合はformat の時は2つ, actionformats の時は3つメッセージがあるので
# 各関数が最大3回呼び出される。
zstyle ':vcs_info:git+set-message:*' hooks \
    git-hook-begin \
    git-untracked \
    git-push-status \
    git-stash-count

# フックの最初の関数
# git の作業コピーのあるディレクトリのみフック関数を呼び出すようにする
# (.git ディレクトリ内にいるときは呼び出さない)
# .git ディレクトリ内では git status --porcelain などがエラーになるため
function +vi-git-hook-begin() {
    if [[ $(command git rev-parse --is-inside-work-tree 2> /dev/null) != 'true' ]]; then
        # 0以外を返すとそれ以降のフック関数は呼び出されない
        return 1
    fi

    return 0
}

# untracked フィアル表示
#
# untracked ファイル(バージョン管理されていないファイル)がある場合は
# unstaged (%u) に ? を表示
function +vi-git-untracked() {
    # zstyle formats, actionformats の2番目のメッセージのみ対象にする
    if [[ "$1" != "1" ]]; then
        return 0
    fi

    if command git status --porcelain 2> /dev/null \
        | awk '{print $1}' \
        | command grep -F '??' > /dev/null 2>&1 ; then

        # unstaged (%u) に追加
        hook_com[unstaged]+='?'
    fi
}

# push していないコミットの件数表示
#
# リモートリポジトリに push していないコミットの件数を
# pN という形式で misc (%m) に表示する
function +vi-git-push-status() {
    # zstyle formats, actionformats の2番目のメッセージのみ対象にする
    if [[ "$1" != "1" ]]; then
        return 0
    fi

    if [[ "${hook_com[branch]}" != "master" ]]; then
        # master ブランチでない場合は何もしない
        return 0
    fi

    # push していないコミット数を取得する
    local ahead
    ahead=$(command git rev-list origin/master..master 2>/dev/null \
        | wc -l \
        | tr -d ' ')

    if [[ "$ahead" -gt 0 ]]; then
        # misc (%m) に追加
        hook_com[misc]+="(p${ahead})"
    fi
}

# マージしていない件数表示
#
# master 以外のブランチにいる場合に、
# 現在のブランチ上でまだ master にマージしていないコミットの件数を
# (mN) という形式で misc (%m) に表示
function +vi-git-nomerge-branch() {
    # zstyle formats, actionformats の2番目のメッセージのみ対象にする
    if [[ "$1" != "1" ]]; then
        return 0
    fi

    if [[ "${hook_com[branch]}" == "master" ]]; then
        # master ブランチの場合は何もしない
        return 0
    fi

    local nomerged
    nomerged=$(command git rev-list master..${hook_com[branch]} 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$nomerged" -gt 0 ]] ; then
        # misc (%m) に追加
        hook_com[misc]+="(m${nomerged})"
    fi
}


# stash 件数表示
#
# stash している場合は :SN という形式で misc (%m) に表示
function +vi-git-stash-count() {
    # zstyle formats, actionformats の2番目のメッセージのみ対象にする
    if [[ "$1" != "1" ]]; then
        return 0
    fi

    local stash
    stash=$(command git stash list 2>/dev/null | wc -l | tr -d ' ')
    if [[ "${stash}" -gt 0 ]]; then
        # misc (%m) に追加
        hook_com[misc]+=":S${stash}"
    fi
}

### ------------------ ###
# prompt config
precmd () {
    ###
    # for vcs
    psvar=()
    LANG=en_US.UTF-8 vcs_info
    local -a vcs_messages
    PR_VCS=""
    if [[ -z ${vcs_info_msg_0_} ]]; then
        # vcs_info で何も取得していない場合はプロンプトを表示しない
    else
        # vcs_info で情報を取得した場合
        [[ -n "$vcs_info_msg_0_" ]] && vcs_messages+=( "%F{red}${vcs_info_msg_0_}%f" )
        [[ -n "$vcs_info_msg_1_" ]] && vcs_messages+=( "%F{green}${vcs_info_msg_1_}%f" )
        [[ -n "$vcs_info_msg_2_" ]] && vcs_messages+=( "%F{blue}${vcs_info_msg_2_}%f" )
        PR_VCS="${(j: :)vcs_messages}"
    fi

    # PERL_VERSION_STRING="pl:"$(asdf current perl 2> /dev/null | awk '{print $2}')
    RUBY_VERSION_STRING="rb:"$(asdf current ruby 2> /dev/null | awk '{print $2}')
    NODE_VERSION_STRING="nd:"$(asdf current nodejs 2> /dev/null | awk '{print $2}')
    # PYTHON_VERSION_STRING="py:"$(asdf current python 2> /dev/null | awk '{print $2}')

    PYTHON_VIRTUAL_ENV_STRING=""
    if [ -n "$VIRTUAL_ENV" ]; then
        PYTHON_VIRTUAL_ENV_STRING=":`basename \"$VIRTUAL_ENV\"`"
    fi
}

function setprompt () {
      PROMPT='%F{yellow}%<...<%~%<< ${PR_VCS} %F{blue}${RUBY_VERSION_STRING} ${NODE_VERSION_STRING}
%F{blue}%D{%H:%M:%S} %F{green}${USER}%F{white}@%F{green}%m%F{white}%(!.#.$) '
}

setprompt
unfunction setprompt
