#!/bin/bash

# 第1引数で通知元アプリを指定（claude / codex）。省略時はclaude
APP="${1:-claude}"
case "$APP" in
  codex)
    TITLE="Codex"
    SOUND="Submarine"
    EMOJIS="🤖🤖⚡⚡"
    ICON="https://avatars.githubusercontent.com/u/14957082?v=4"
    ;;
  *)
    TITLE="Claude Code"
    SOUND="Glass"
    EMOJIS="💻💻🔥🔥"
    ICON="https://cdn.prod.website-files.com/6889473510b50328dbb70ae6/68c33859cc6cd903686c66a2_apple-touch-icon.png"
    ;;
esac

# 標準入力からhookのInputデータを読み取り
INPUT=$(cat)

# 現在のセッションディレクトリ名を取得（hooksはsessionと同じディレクトリで実行される）
SESSION_DIR=$(basename "$(pwd)")

# transcript_pathを抽出
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')

# transcript_pathが存在する場合、最新のassistantメッセージから通知テキストを取得
if [ -f "$TRANSCRIPT_PATH" ]; then
    # Stop hook発火時にはtranscript書き込みが完了していないことがあるため、sleepで待機
    sleep 1

    # contentのtypeに応じて通知テキストを取得
    #   text → .text
    #   tool_use → Bash: .input.description / AskUserQuestion: .input.questions[0].question
    #              Write/Edit: "Edit: " + file_path
    #   それ以外 → スキップ
    MSG=$(tail -30 "$TRANSCRIPT_PATH" | \
          jq -r '
            select(.message.role == "assistant") |
            .message.content[0] |
            if .type == "text" then
              .text
            elif .type == "tool_use" then
              if .name == "Bash" then (.input.description // empty)
              elif .name == "AskUserQuestion" then (.input.questions[0].question // empty)
              elif .name == "Write" then "Edit: " + (.input.file_path // empty)
              elif .name == "Edit" then "Edit: " + (.input.file_path // empty)
              else empty
              end
            else
              empty
            end
          ' 2>/dev/null | tail -1 | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | cut -c1-100)

    MSG=${MSG:-"Task completed"}
else
    MSG="Task completed"
fi

open -g "raycast://extensions/raycast/raycast/confetti?emojis=${EMOJIS}"
terminal-notifier -title "$TITLE" \
    -message "$MSG" \
    -sound "$SOUND" \
    -contentImage "$ICON" \
    -activate "com.mitchellh.ghostty"
