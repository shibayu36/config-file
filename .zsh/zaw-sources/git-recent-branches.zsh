# zaw source for git branches sorted by commit date

function zaw-src-git-recent-branches () {
    git rev-parse --git-dir >/dev/null 2>&1
    if [[ $? == 0 ]]; then
        candidates=( $(git for-each-ref --format='%(refname:short)' --sort=-committerdate refs/heads) )
    fi

    actions=(zaw-src-git-recent-branches-checkout)
    act_descriptions=("check out")
}

function zaw-src-git-recent-branches-checkout () {
    BUFFER="git checkout $1"
    zle accept-line
}

zaw-register-src -n git-recent-branches zaw-src-git-recent-branches
