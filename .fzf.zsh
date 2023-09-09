# Setup fzf
# ---------
if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/opt/homebrew/opt/fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/opt/homebrew/opt/fzf/shell/key-bindings.zsh"

export FZF_DEFAULT_OPTS='--height 90% --layout=reverse'

# CTRL-R - Paste the selected command from history into the command line
fzf-history-widget() {
  local selected num
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
zle     -N            fzf-history-widget
bindkey -M emacs '^R' fzf-history-widget
