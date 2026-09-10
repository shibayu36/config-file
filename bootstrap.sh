#!/bin/bash
# Homebrewと、これが無いと作業にならないアプリ・ツールを入れる。Brewfile全体はinstaller.shで入れる
set -eu

# 更新は brew upgrade で意図的に行うため、インストール済みのものは触らない
export HOMEBREW_NO_INSTALL_UPGRADE=1

if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --adoptは手動で入れた既存アプリをbrew管理下に取り込むため
brew install --cask --adopt 1password google-chrome karabiner-elements ghostty raycast font-hack-nerd-font
# pythonはauto-config.shが呼ぶsync-codex-configがpython3 3.11以上を必要とするため
brew install herdr python

# Claude Code CLI（native install）
if [ ! -x "$HOME/.local/bin/claude" ]; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

echo '次のコマンドを実行して、今のシェルにbrewのPATHを通してから続ける:'
echo '  eval "$(/opt/homebrew/bin/brew shellenv)"'
