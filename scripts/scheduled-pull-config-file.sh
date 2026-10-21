#!/bin/bash
# config-fileをupstreamに追従させる。
# 未commitの変更とupstreamの変更が同じファイルに及ぶ場合は、symlink先の設定ファイルにconflictマーカーが入るのを避けるため、pullせず通知だけする
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
log_file="$HOME/Library/Logs/scheduled-pull-config-file.log"
# 公開リポジトリなので、SSH鍵が使えない状態でもfetchできるHTTPSを使う
upstream_url="https://github.com/shibayu36/config-file.git"

exec >>"$log_file" 2>&1
echo "=== $(date '+%Y-%m-%d %H:%M:%S')"

notify() {
  osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title "config-file pull"' -e 'end run' "$1"
}

trap 'notify "エラーで失敗しました。$log_file を確認してください"' ERR

# ユーザー設定の読み込みに失敗する環境でも動くよう、グローバル設定は読まない（fetchとmergeには不要）
export GIT_CONFIG_GLOBAL=/dev/null

cd "$repo_dir"

branch="$(git branch --show-current)"
if [ "$branch" != "master" ]; then
  echo "masterではないのでスキップ"
  exit 0
fi

# スリープ復帰直後はネットワークが繋がっていないことがあるため、リトライする
for i in 1 2 3; do
  git fetch "$upstream_url" +refs/heads/master:refs/remotes/origin/master && break
  if [ "$i" -eq 3 ]; then
    notify "fetchに失敗しました。$log_file を確認してください"
    exit 1
  fi
  sleep 20
done

if git merge-base --is-ancestor origin/master HEAD; then
  echo "取り込むupstreamの変更がないのでスキップ"
  exit 0
fi

if ! git merge-base --is-ancestor HEAD origin/master; then
  echo "ローカルとupstreamが分岐しており、fast-forwardできない"
  notify "ローカルとupstreamが分岐しているためpullしませんでした"
  exit 0
fi

# renameを検出するとrename元のパスが出ず、ローカルの変更との重なりを見逃すため--no-renamesにする
upstream_changed="$(git diff --no-renames --name-only HEAD origin/master | sort -u)"
local_changed="$({ git diff --no-renames --name-only HEAD; git ls-files --others --exclude-standard; } | sort -u)"
overlapped="$(comm -12 <(echo "$upstream_changed") <(echo "$local_changed"))"
if [ -n "$overlapped" ]; then
  echo "未commitの変更とupstreamの変更が重なっている:"
  echo "$overlapped"
  notify "未commitの変更とconflictするためpullしませんでした: $(echo "$overlapped" | tr '\n' ' ')"
  exit 0
fi

git merge --ff-only --autostash origin/master

# autostashの適用がconflictしてもmergeは成功扱いになるため、未解決のconflictが残っていないか確かめる
conflicted="$(git diff --name-only --diff-filter=U)"
if [ -n "$conflicted" ]; then
  echo "autostashの適用でconflictした:"
  echo "$conflicted"
  notify "autostashの適用でconflictしました。git stash listを確認してください"
  exit 1
fi
