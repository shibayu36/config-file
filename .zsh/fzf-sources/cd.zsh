function fzf-cd () {
    local selected_dir=$((cdr -l | awk '{ print $2 }'; ghq list --full-path) | fzf)
    if [ -n "$selected_dir" ]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N fzf-cd
