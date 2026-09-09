#!/bin/bash
# Claude Code が cd した先で direnv の環境変数を CLAUDE_ENV_FILE に追記し、
# 後続の Bash ツール実行に引き継ぐ。
# 未 allow の .envrc は direnv が中身を評価しないため、ユーザー定義の値はリークしない。

if ! command -v direnv >/dev/null 2>&1; then
  exit 0
fi

direnv export bash >> "$CLAUDE_ENV_FILE" 2>/dev/null || true
