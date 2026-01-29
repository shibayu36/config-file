function fzf-cd () {
    # git worktree (git wt) で作成したディレクトリは候補から除外
    local selected_dir=$((cdr -l | awk '{ print $2 }'; ghq list --full-path) | grep -v '/.worktrees/' | fzf)
    if [ -n "$selected_dir" ]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N fzf-cd
