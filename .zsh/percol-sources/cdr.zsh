function percol-cdr () {
    local selected_dir=$(cdr -l | awk '{ print $2 }' | percol)
    if [ -n "$selected_dir" ]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N percol-cdr
