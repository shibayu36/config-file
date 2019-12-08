function peco-git-ls-files () {
    git ls-files | peco --query "$LBUFFER"
}

function peco-open-code-by-git-ls-files () {
    code $(peco-git-ls-files)
}
zle -N peco-open-code-by-git-ls-files
