#!/bin/bash
# PreToolUse で Bashツールのコマンドをパターンで block する汎用スクリプト
# マッチしたら exit 2 + stderr にメッセージ、どれにも該当しなければ exit 0
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# cd と git/gitro の複合コマンドをブロック
if echo "$command" | grep -qE 'cd\s+\S+\s*(&&|;)\s*(git|gitro)'; then
    echo "cd と git/gitro の複合コマンドは分割して実行してください。別々のBashツール呼び出しに分けてください。" >&2
    exit 2
fi

# git -C / gitro -C をブロック
if echo "$command" | grep -qE '\b(git|gitro)\s+-C\b'; then
    echo "git -C / gitro -C は使わないでください。対象ディレクトリに移動した上で別々のBashツール呼び出しに分けてください。" >&2
    exit 2
fi

exit 0
