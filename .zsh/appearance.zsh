###
# Need this so the prompt will work.
setopt PROMPT_SUBST

###
# color prompt on
autoload -U colors
colors

###
# for vcs
autoload -Uz vcs_info
zstyle ':vcs_info:*' formats '%s:%b'
zstyle ':vcs_info:*' actionformats '%s:%b|%a'

###
# prompt config
precmd () {
  ###
  # for vcs
  psvar=()
  if [[ $ZSH_VERSION == 4.3.<8->* ]]; then
    LANG=en_US.UTF-8 vcs_info
    [[ -n "$vcs_info_msg_0_" ]] && psvar[1]="$vcs_info_msg_0_"
  fi

  ###
  # Truncate the path if it's too long.

  local promptsize=${#${(%):---(-----------------)---()--}}
  local pwdsize=${#${(%):-%~}}
  local vcssize=${#${(%):-%1(v|%1v%f |-----)}}


  if [[ "$promptsize + $pwdsize + $vcssize - 32" -gt $COLUMNS ]]; then
    PR_FILLBAR=""
  else
    PR_FILLBAR="\${(l.(($COLUMNS - ($vcssize + $promptsize + $pwdsize - 32)))..-.)}"
  fi
  # if [ -n "${WINDOW}" -a $UNAME = "Darwin" ]; then
  #   $HOME/config/bin/precmd.pl `history -n -1 | head -1`
  # fi
}

function setprompt () {
  fg[black]=$'%{\e[1;30m%}'
  fg[red]=$'%{\e[0;31m%}'
  fg[green]=$'%{\e[0;32m%}'
  fg[blue]=$'%{\e[0;34m%}'
  fg[cyan]=$'%{\e[0;36m%}'
  fg[magenta]=$'%{\e[0;35m%}'
  fg[yellow]=$'%{\e[0;33m%}'
  fg[white]=$'%{\e[m%}'
  case $HOST in
    hatter)
      PR_BC=${fg[magenta]}
      ;;
    humpty)
      PR_BC=${fg[green]}
      ;;
    cheshire)
      PR_BC=${fg[cyan]}
      ;;
    *)
      PR_BC=${fg[white]}
  esac
  PROMPT='${fg[yellow]}%<...<%~%<< %1(v|${fg[red]}%1v%f |)${PR_BC}${(e)PR_FILLBAR}
${fg[blue]}%D{%H:%M:%S} ${fg[green]}${USER}${fg[white]}@${fg[green]}%m${fg[white]}%(!.#.$) '
}

setprompt
unfunction setprompt
