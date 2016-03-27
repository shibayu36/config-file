autoload -U modify-current-argument
autoload -U split-shell-arguments

peco-complete-mackerel-host-ip () {
    local apikey=$1
    local apikey_name=$2

    local mode_append_only=0
    local REPLY
    local reply

    local filter='peco'

    split-shell-arguments
    if [ $(($REPLY % 2)) -eq 0 ]; then
        # query by word under cursor
        query_arg="--query=$reply[$REPLY]"
    elif [ -n "${LBUFFER##* }" ]; then
        # query by word jsut before cursor
        query_arg="--query=${LBUFFER##* }"
    else
        # no word detected
        query_arg='--query='
        mode_append_only=1
    fi

    res=$(MACKEREL_APIKEY=${apikey:-$MACKEREL_APIKEY} MACKEREL_APIKEY_NAME=${apikey_name:-$MACKEREL_APIKEY_NAME} mkr-hosts-tsv | eval $filter "$query_arg")
    if [ -z "$res" ]; then
        zle reset-prompt
        return 1
    fi

    ip=$(echo "$res" | cut -f1)
    host=$(echo "$res" | cut -f2)

    if [ $mode_append_only = 1 ]; then
        LBUFFER+="$ip"
    else
        modify-current-argument "$ip"
    fi

    BUFFER+=" # $host"

    zle reset-prompt
}
zle -N peco-complete-mackerel-host-ip
