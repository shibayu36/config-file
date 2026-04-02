#!/bin/bash
# cd && git/gitro の複合コマンドをブロックするPreToolUseフック
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

if echo "$command" | grep -qE 'cd\s+\S+\s*(&&|;)\s*(git|gitro)'; then
    echo "cd と git/gitro の複合コマンドは分割して実行してください。別々のBashツール呼び出しに分けてください。" >&2
    exit 2
fi

exit 0
