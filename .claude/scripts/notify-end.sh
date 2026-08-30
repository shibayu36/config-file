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

# transcriptの最新のassistantメッセージから通知テキストを組み立てる
build_message() {
  # CodexのStop hookはlast_assistant_messageをhook inputに直接含むため、transcriptを読まずに使う
  LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)
  if [ -n "$LAST_MSG" ]; then
    echo "$LAST_MSG" | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | cut -c1-100
    return
  fi

  TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')
  if [ ! -f "$TRANSCRIPT_PATH" ]; then
    echo "Task completed"
    return
  fi

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

  echo "${MSG:-Task completed}"
}

notify_and_handle_click() {
  MSG=$(build_message)

  open -g "raycast://extensions/raycast/raycast/confetti?emojis=${EMOJIS}"

  # 同一セッションの古い通知は新しい通知で置き換える
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
  SESSION_DIR=$(basename "$(pwd)")
  GROUP="notify-end-${APP}-${HERDR_PANE_ID:-${SESSION_ID:-$SESSION_DIR}}"

  # 通知センターに接続できない時はalerterの--timeoutが効かないため、外側からも強制終了する
  ACTIVATION_TYPE=$(timeout 30 alerter \
    --title "$TITLE" \
    --message "$MSG" \
    --sound "$SOUND" \
    --app-icon "$ICON" \
    --group "$GROUP" \
    --timeout 20 \
    --json | jq -r '.activationType // empty')

  [ "$ACTIVATION_TYPE" = "contentsClicked" ] || return

  # ターミナル起動時は__CFBundleIdentifierに起動元アプリのbundle idが入っている。
  # GUIアプリ起動時は未設定のため、APPから起動元(ChatGPTアプリ / Claude Desktop)を推定する
  if [ -n "${__CFBundleIdentifier:-}" ]; then
    BUNDLE_ID="$__CFBundleIdentifier"
  elif [ "$APP" = "codex" ]; then
    BUNDLE_ID="com.openai.codex"
  else
    BUNDLE_ID="com.anthropic.claudefordesktop"
  fi
  open -b "$BUNDLE_ID"

  # herdr内のセッションなら該当paneへフォーカスする
  if [ -n "${HERDR_PANE_ID:-}" ]; then
    herdr agent focus "$HERDR_PANE_ID"
  fi
}

# alerterはクリックまたはタイムアウトまでブロックするため、hook自体は即座に終了させる。
# NOTIFY_END_LOGにファイルパスを設定するとデバッグログを残せる
notify_and_handle_click </dev/null >>"${NOTIFY_END_LOG:-/dev/null}" 2>&1 &
