#!/bin/bash
# mise bootstrapの最後に毎回実行されるので、各処理は何度実行しても同じ結果になるように書く
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"

# skillはサブディレクトリを持ち、symlink-eachだとファイル単位のリンクになるため、ディレクトリごとリンクする
mkdir -p ~/.claude/skills ~/.agents/skills
for item in "$repo_dir"/claude/skills/*; do
  ln -sfn "$item" ~/.claude/skills/"$(basename "$item")"
done
for item in "$repo_dir"/skills/*; do
  ln -sfn "$item" ~/.claude/skills/"$(basename "$item")"
  ln -sfn "$item" ~/.agents/skills/"$(basename "$item")"
done

# config.toml は Codex がローカル固有の値を書き込むためリンクせず、共通設定をマージする
"$repo_dir"/bin/sync-codex-config

[ -f ~/.claude/hooks/herdr-agent-state.sh ] || herdr integration install claude
herdr plugin list | grep -F 'shibayu36.equalize-panes' >/dev/null || herdr plugin install shibayu36/herdr-equalize-panes --yes
