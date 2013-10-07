function percol-git-status-files () {
    git status --porcelain | percol | awk '{ print $2 }' | xargs git $*
}
