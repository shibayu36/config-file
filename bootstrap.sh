#!/bin/bash
# Homebrewと、これが無いと作業にならないアプリ・ツールを入れる。パッケージ全体はmise bootstrapで入れる
# 使い方: ./bootstrap.sh personal|work
set -eu

profile=${1:-}
if [ "$profile" != personal ] && [ "$profile" != work ]; then
  echo "usage: $0 personal|work" >&2
  exit 1
fi

# 更新は brew upgrade で意図的に行うため、インストール済みのものは触らない
export HOMEBREW_NO_INSTALL_UPGRADE=1

if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --adoptは手動で入れた既存アプリをbrew管理下に取り込むため
brew install --cask --adopt dropbox karabiner-elements ghostty raycast font-hack-nerd-font
if [ "$profile" = personal ]; then
  brew install --cask --adopt 1password google-chrome
fi
brew install herdr

# Claude Code CLI（native install）
if [ ! -x "$HOME/.local/bin/claude" ]; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

if [ ! -x "$HOME/.local/bin/mise" ]; then
  curl https://mise.run | sh
fi

# miseのグローバル設定。これより先の配置はmise bootstrapが行う
mkdir -p ~/.config/mise
for f in config.toml config.personal.toml config.work.toml; do
  ln -sfn "$(cd "$(dirname "$0")" && pwd)/mise/$f" ~/.config/mise/$f
done
if [ ! -e ~/.config/mise/miserc.local.toml ]; then
  echo "env = [\"$profile\"]" > ~/.config/mise/miserc.local.toml
fi

echo '次のコマンドを実行して、今のシェルにbrewのPATHを通してから続ける:'
echo '  eval "$(/opt/homebrew/bin/brew shellenv)"'
