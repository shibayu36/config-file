function peco-ghq-list () {
    ghq list --full-path | peco --query "$LBUFFER"
}
