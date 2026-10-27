#!/bin/bash
# Obsidianの仕事のメモに何か書かれていれば、5分間残る通知を出す。クリックするとObsidianで開く
set -euo pipefail

memo_file="$HOME/obsidian/仕事/仕事のメモ.md"
log_file="$HOME/Library/Logs/notify-work-memo.log"

exec >>"$log_file" 2>&1
echo "=== $(date '+%Y-%m-%d %H:%M:%S')"

[ -f "$memo_file" ] || exit 0

# 長さは切り詰めない。表示しきれない分は通知側で省略される
message="$(grep -v '^[[:space:]]*$' "$memo_file" || true)"
[ -n "$message" ] || exit 0

# launchdから起動されるとPATHにHomebrewが含まれないため、絶対パスで呼ぶ。
# メモの中身は-で始まりうるが、alerterは-で始まる値を値なしと解釈するため、--messageは=でつなぐ。
# 通知センターに接続できない時はalerterの--timeoutが効かないため、外側からも強制終了する
activation_type="$(/opt/homebrew/bin/timeout 330 /opt/homebrew/bin/alerter \
  --title "仕事のメモ" \
  --message="$message" \
  --sound Glass \
  --app-icon /Applications/Obsidian.app/Contents/Resources/icon.icns \
  --group notify-work-memo \
  --timeout 300 \
  --json | jq -r '.activationType // empty')"

[ "$activation_type" = "contentsClicked" ] || exit 0

open "obsidian://open?path=$(jq -rn --arg p "$memo_file" '$p | @uri')"
