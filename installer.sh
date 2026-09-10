#!/bin/bash
set -eu

# homebrew
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 更新は brew upgrade で意図的に行うため、ここでは不足分のインストールだけを行う
brew bundle install --no-upgrade --file="$(cd "$(dirname "$0")" && pwd)/Brewfile"

# asdf plugins
asdf_plugin_add() {
  local name=$1
  shift
  if asdf plugin list | grep -qx "$name"; then
    return
  fi
  asdf plugin add "$name" "$@"
}
asdf_plugin_add ruby https://github.com/asdf-vm/asdf-ruby.git
asdf_plugin_add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf_plugin_add perl
asdf_plugin_add python
