function peco-cd () {
    local selected_dir=$((cdr -l | awk '{ print $2 }'; ghq list --full-path) | peco)
    if [ -n "$selected_dir" ]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N peco-cd
