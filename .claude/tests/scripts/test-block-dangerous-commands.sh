#!/bin/bash
# block-dangerous-commands.sh のテスト。
# JSON を stdin から渡し、exit code が期待値と一致するかを確認する。
# ブロック = exit 2、許可 = exit 0。
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$SCRIPT_DIR/../../scripts/block-dangerous-commands.sh"

if [ ! -x "$TARGET" ]; then
    echo "ERROR: target script not found or not executable: $TARGET" >&2
    exit 1
fi

PASS=0
FAIL=0
FAIL_LOG=()

# コマンドを実行し stderr を変数に、exit code を $actual_exit に取得する。
# stdout は捨て、stderr は SENTINEL の前まで、終了コードは SENTINEL の後ろから抽出する。
SENTINEL='===EXIT==='
run_target() {
    local input="$1"
    local result
    result=$(printf '%s' "$input" | { "$TARGET" 2>&1 >/dev/null; printf '\n%s:%s' "$SENTINEL" "$?"; })
    actual_stderr="${result%$'\n'$SENTINEL:*}"
    actual_exit="${result##*$SENTINEL:}"
}

run_case() {
    local name="$1"
    local cmd="$2"
    local expected="$3"

    local input
    input=$(jq -n --arg c "$cmd" '{tool_input:{command:$c}}')
    local actual_stderr actual_exit
    run_target "$input"

    if [ "$actual_exit" = "$expected" ]; then
        printf "PASS: %s\n" "$name"
        PASS=$((PASS + 1))
    else
        printf "FAIL: %s (expected=%s actual=%s cmd=%q)\n" "$name" "$expected" "$actual_exit" "$cmd"
        if [ -n "$actual_stderr" ]; then
            printf "      stderr: %s\n" "$actual_stderr"
        fi
        FAIL=$((FAIL + 1))
        FAIL_LOG+=("$name")
    fi
}

# 不正な JSON を直接渡すケース (stdin に JSON 以外を流す)
run_invalid_json_case() {
    local name="$1"
    local raw="$2"
    local expected="$3"

    local actual_stderr actual_exit
    run_target "$raw"

    if [ "$actual_exit" = "$expected" ]; then
        printf "PASS: %s\n" "$name"
        PASS=$((PASS + 1))
    else
        printf "FAIL: %s (expected=%s actual=%s)\n" "$name" "$expected" "$actual_exit"
        if [ -n "$actual_stderr" ]; then
            printf "      stderr: %s\n" "$actual_stderr"
        fi
        FAIL=$((FAIL + 1))
        FAIL_LOG+=("$name")
    fi
}

echo "=== ブロックされるべきケース (expected exit 2) ==="
run_case "rm -rf"                       "rm -rf /tmp/foo"                       2
run_case "rm -fr"                       "rm -fr /tmp/foo"                       2
run_case "rm -r -f (split flags)"       "rm -r -f /tmp/foo"                     2
run_case "rm -R"                        "rm -R /tmp/foo"                        2
run_case "rm --recursive"               "rm --recursive /tmp/foo"               2
run_case "rm bypass single quote"       "'r''m' -rf /tmp/foo"                   2
run_case "rm bypass double quote"       "\"r\"m -rf /tmp/foo"                   2
run_case "rm bypass backslash"          "r\\m -rf /tmp/foo"                     2
run_case "rm absolute path"             "/bin/rm -rf /tmp/foo"                  2
run_case "git push --force"             "git push --force"                      2
run_case "git push -f"                  "git push -f origin master"             2
run_case "git push --force end"         "git push origin master --force"        2
run_case "git reset --hard"             "git reset --hard HEAD~1"               2
run_case "git clean -fd"                "git clean -fd"                         2
run_case "git clean -fdx"               "git clean -fdx"                        2
run_case "git clean -df"                "git clean -df"                         2
run_case "git clean --force"            "git clean --force"                     2
run_case "git branch -D"                "git branch -D feature"                 2
run_case "sudo apt"                     "sudo apt update"                       2
run_case "sudo bypass double quote"     "su\"\"do apt update"                   2
run_case "sudo absolute path"           "/usr/bin/sudo apt update"              2
run_case "chmod 777"                    "chmod 777 file"                        2
run_case "chmod -R 777"                 "chmod -R 777 /tmp"                     2
run_case "dd write"                     "dd if=/dev/zero of=/dev/sda"           2
run_case "dd of= first"                 "dd of=/dev/null if=/dev/zero count=1"  2
run_case "mkfs.ext4"                    "mkfs.ext4 /dev/sda1"                   2
run_case "mkfs"                         "mkfs /dev/sda"                         2
run_case "shutdown -h now"              "shutdown -h now"                       2
run_case "reboot"                       "reboot"                                2
run_case "halt"                         "halt"                                  2
run_case "poweroff"                     "poweroff"                              2

echo ""
echo "=== 許可されるべきケース (expected exit 0) ==="
run_case "rm -i"                        "rm -i file"                            0
run_case "rm plain"                     "rm file"                               0
run_case "rm -f no recursive"           "rm -f file"                            0
run_case "git push plain"               "git push origin master"                0
run_case "git push --force-with-lease"  "git push --force-with-lease"           0
run_case "git push --force-with-lease args" "git push --force-with-lease origin feature" 0
run_case "git reset soft"               "git reset HEAD~1"                      0
run_case "git reset --soft"             "git reset --soft HEAD~1"               0
run_case "git clean -n"                 "git clean -n"                          0
run_case "git clean -X"                 "git clean -X"                          0
run_case "git clean -ndf"               "git clean -ndf"                        0
run_case "git clean -fdn"               "git clean -fdn"                        0
run_case "git clean -fd -n"             "git clean -fd -n"                      0
run_case "git clean --dry-run --force"  "git clean --dry-run --force"           0
run_case "git branch -d lower"          "git branch -d feature"                 0
run_case "git rebase"                   "git rebase --abort"                    0
run_case "chmod 755"                    "chmod 755 file"                        0
run_case "dd readonly"                  "dd if=/dev/zero count=1"               0
run_case "sudoers (no exec)"            "cat /etc/sudoers"                      0
run_case "rebase (not reboot)"          "git rebase main"                       0

echo ""
echo "=== JSON 不正入力 (安全側にブロック expected exit 2) ==="
run_invalid_json_case "broken json"     "this is not json"                      2
run_invalid_json_case "empty input"     ""                                      0  # jq -r で // "" が効くので exit 0、コマンド空でブロック対象外

echo ""
echo "=== 集計 ==="
printf "PASS: %d, FAIL: %d\n" "$PASS" "$FAIL"

if [ "$FAIL" -ne 0 ]; then
    echo "Failed cases:"
    for n in "${FAIL_LOG[@]}"; do
        echo "  - $n"
    done
    exit 1
fi
exit 0
