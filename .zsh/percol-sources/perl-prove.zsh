function percol-perl-prove () {
    local selected_file=$(git ls-files t/ | percol)
    BUFFER="carton exec -- prove ${selected_file}"
    CURSOR=$#BUFFER
    zle clear-screen
}
zle -N percol-perl-prove
