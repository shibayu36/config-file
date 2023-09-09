fzf-history-widget() {
  local selected
  setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null
  selected=( $(fc -rln 1 | awk '{ cmd=$0; if (!seen[cmd]++) print $0 }' |
    FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS  --scheme=history $FZF_CTRL_R_OPTS --query=${(qqq)LBUFFER}" fzf) )
  local ret=$?
  if [ -n "$selected" ]; then
    LBUFFER="${selected}"
  fi
  zle reset-prompt
  return $ret
}
zle -N fzf-history-widget
