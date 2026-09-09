#!/bin/bash
# PreToolUse で Bash ツールに渡された危険コマンドをブロックする。
# クォート/バックスラッシュを除去して正規化した上で正規表現マッチするので、
# 'r''m' -rf や "su""do"、r\m のような単純なすり抜けにも対応する。
# マッチしたら exit 2 + stderr にメッセージ、どれにも該当しなければ exit 0。
#
# 既知の限界 (検出しないパターン):
# - bash -c "..." / python -c "..." 等の言語経由の間接実行
# - $IFS や $() などのシェル展開を介した動的構築 (例: rm${IFS}-rf)
# - alias / PATH 経由のリネーム
# - chmod は数値モード 777 のみ対象。記号モード (a+w など) は対象外
# - echo "rm -rf" のような引用文字列内の表現は誤検知する (受容)
input=$(cat)
if ! command=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null); then
    echo "BLOCKED: hook 入力 JSON のパースに失敗しました。" >&2
    exit 2
fi

# 例: r''m, "r"m, r\m を rm に正規化
normalized=$(printf '%s' "$command" | tr -d "'\"\\")

# git clean は -n / --dry-run を含む場合は安全な dry-run なので許可する。
# 短オプション結合形式 (-ndf, -fdn) も許可するため、ループとは分離して個別判定。
if echo "$normalized" | grep -qE '(^|[^[:alnum:]_])git[[:space:]]+clean[[:space:]](.*[[:space:]])?(-[a-zA-Z]*f|--force)' \
    && ! echo "$normalized" | grep -qE '(^|[^[:alnum:]_])git[[:space:]]+clean[[:space:]](.*[[:space:]])?(-[a-zA-Z]*n|--dry-run)'; then
    echo "BLOCKED [git clean 強制削除]: git clean -f / --force 系は禁止です。-n で dry-run してから人間に確認してください。" >&2
    exit 2
fi

names=(
    "rm 再帰削除"
    "find -delete"
    "xargs rm 再帰削除"
    "git force push"
    "git reset --hard"
    "git branch -D"
    "sudo"
    "chmod 777"
    "dd 書き込み"
    "mkfs"
    "システム停止/再起動"
)

patterns=(
    '(^|[^[:alnum:]_])rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)'
    '(^|[^[:alnum:]_])find[[:space:]].*-delete($|[[:space:]])'
    '(^|[^[:alnum:]_])xargs[[:space:]].*rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)'
    '(^|[^[:alnum:]_])git[[:space:]]+push[[:space:]](.*[[:space:]])?(--force([^-]|$)|-f($|[[:space:]]))'
    '(^|[^[:alnum:]_])git[[:space:]]+reset[[:space:]].*--hard'
    '(^|[^[:alnum:]_])git[[:space:]]+branch[[:space:]](.*[[:space:]])?-D($|[[:space:]])'
    '(^|[^[:alnum:]_])sudo([[:space:]]|$)'
    '(^|[^[:alnum:]_])chmod[[:space:]].*777'
    '(^|[^[:alnum:]_])dd[[:space:]].*of='
    '(^|[^[:alnum:]_])mkfs(\.|[[:space:]])'
    '(^|[^[:alnum:]_])(shutdown|reboot|halt|poweroff)([[:space:]]|$)'
)

messages=(
    "rm の再帰削除 (-r/-R/-rf/--recursive) は禁止です。削除対象を明示するか、対話的に確認してください。"
    "find -delete は禁止です。一括削除を伴うため、削除対象を確認した上で個別に rm してください。"
    "xargs 経由の rm 再帰削除 (-r/-R/-rf/--recursive) は禁止です。削除対象を明示するか、対話的に確認してください。"
    "git push --force / -f は禁止です。必要なら --force-with-lease を使ってください。"
    "git reset --hard は禁止です。コミット履歴の破壊を伴うため事前に人間に確認してください。"
    "git branch -D (強制削除) は禁止です。-d を使うか人間に確認してください。"
    "sudo は禁止です。権限昇格が必要な操作は人間に依頼してください。"
    "chmod 777 系は禁止です。最小権限の原則に従って必要な権限のみ付与してください。"
    "dd の書き込み (of=) は禁止です。ディスク破壊のリスクがあります。"
    "mkfs は禁止です。ファイルシステム初期化はディスク破壊のリスクがあります。"
    "shutdown / reboot / halt / poweroff は禁止です。再起動が必要なら人間に依頼してください。"
)

# 配列の要素数が揃っていることをアサート (追加漏れによるメッセージずれを防ぐ)
if [ "${#names[@]}" -ne "${#patterns[@]}" ] || [ "${#patterns[@]}" -ne "${#messages[@]}" ]; then
    echo "BLOCKED: block-dangerous-commands.sh の rule 配列の要素数が不整合です。" >&2
    exit 2
fi

for i in "${!patterns[@]}"; do
    if echo "$normalized" | grep -qE "${patterns[$i]}"; then
        echo "BLOCKED [${names[$i]}]: ${messages[$i]}" >&2
        exit 2
    fi
done

exit 0
