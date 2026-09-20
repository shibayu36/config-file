#!/bin/bash
# Brewfileの内容とasdfのplugin、Rustを入れる。Homebrew自体はbootstrap.shで入れる
set -eu

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

# Rust。toolchainはasdfではなくrustupで管理する
# --no-modify-pathはPATHを.zshenvで管理しているため。付けないとrustupが~/.zshenvを書き換える
if [ ! -x "$HOME/.cargo/bin/rustup" ]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
