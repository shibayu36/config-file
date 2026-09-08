#!/bin/bash
# sync-codex-config のテスト。一時ディレクトリを CODEX_HOME に見立てて実行する (macOS 前提: stat -f, md5)。
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$SCRIPT_DIR/../../bin/sync-codex-config"

if [ ! -x "$TARGET" ]; then
    echo "ERROR: target script not found or not executable: $TARGET" >&2
    exit 1
fi

WORK="$(mktemp -d)"

PASS=0
FAIL=0
FAIL_LOG=()

BASE="$WORK/config.base.toml"
CODEX_HOME_DIR="$WORK/codex-home"
CONFIG="$CODEX_HOME_DIR/config.toml"

# 例: toml_get FILE mcp_servers circleci env CIRCLECI_TOKEN
# 文字列はそのまま、それ以外は JSON で出力する。存在しなければ "<missing>"。
toml_get() {
    python3 - "$@" <<'PY'
import json, sys, tomllib
data = tomllib.load(open(sys.argv[1], "rb"))
for part in sys.argv[2:]:
    if not isinstance(data, dict) or part not in data:
        print("<missing>"); sys.exit()
    data = data[part]
print(data if isinstance(data, str) else json.dumps(data, ensure_ascii=False, default=str))
PY
}

run_sync() {
    CODEX_HOME="$CODEX_HOME_DIR" "$TARGET" --base "$BASE" "$@"
}

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        FAIL_LOG+=("$name: expected [$expected] got [$actual]")
    fi
}

assert_contains() {
    local name="$1" haystack="$2" needle="$3"
    if printf '%s\n' "$haystack" | grep -qF -- "$needle"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        FAIL_LOG+=("$name: [$needle] not found in output")
    fi
}

assert_not_contains() {
    local name="$1" haystack="$2" needle="$3"
    if printf '%s\n' "$haystack" | grep -qF -- "$needle"; then
        FAIL=$((FAIL + 1))
        FAIL_LOG+=("$name: [$needle] unexpectedly found in output")
    else
        PASS=$((PASS + 1))
    fi
}

PROJECT="/Users/someone/path/to/InternalProject"
HOOK_KEY="/Users/someone/.codex/hooks.json:stop:0:0"

write_base() {
    cat > "$BASE" <<'EOF'
model = "gpt-base"
network_access = true

[shell_environment_policy.set]
ENABLE_TOOL_SEARCH = "true"

[mcp_servers.circleci]
command = "pnpx"
args = ["@circleci/mcp-server-circleci"]

[marketplaces.claude-plugins-official]
source = "https://example.com/plugins.git"
EOF
}

# --- 初回セットアップ: config.toml が無い状態から作成される ---
write_base
run_sync > /dev/null
assert_eq "初回: exit 0" 0 $?
assert_eq "初回: base の値が入る" "gpt-base" "$(toml_get "$CONFIG" model)"
assert_eq "初回: ネストした base の値が入る" "pnpx" "$(toml_get "$CONFIG" mcp_servers circleci command)"
assert_eq "初回: 0600 で作成される" "600" "$(stat -f %Lp "$CONFIG")"

# --- 冪等性: 変更が無ければ書き換えない ---
before="$(md5 -q "$CONFIG")"
out="$(run_sync)"
assert_eq "2回目: exit 0" 0 $?
assert_eq "2回目: 変更なしと報告する" "$CONFIG: 変更なし" "$out"
assert_eq "2回目: ファイルが書き換わらない" "$before" "$(md5 -q "$CONFIG")"

# --- Codex が追記したローカル値 (projects, 機密, 未知のテーブル) が保持される ---
cat >> "$CONFIG" <<EOF

[projects."$PROJECT"]
trust_level = "trusted"

[mcp_servers.circleci.env]
CIRCLECI_TOKEN = "secret-token"

[hooks.state."$HOOK_KEY"]
trusted_hash = "abc"
EOF
run_sync > /dev/null
assert_eq "保持: exit 0" 0 $?
assert_eq "保持: projects が残る" "trusted" "$(toml_get "$CONFIG" projects "$PROJECT" trust_level)"
assert_eq "保持: base と同じテーブル配下の機密が残る" "secret-token" "$(toml_get "$CONFIG" mcp_servers circleci env CIRCLECI_TOKEN)"
assert_eq "保持: 未知のテーブルが残る" "abc" "$(toml_get "$CONFIG" hooks state "$HOOK_KEY" trusted_hash)"

# --- 共通設定の更新が反映され、ローカル値は残る ---
perl -pi -e 's/gpt-base/gpt-updated/' "$BASE"
printf '\n[features]\njs_repl = false\n' >> "$BASE"
run_sync > /dev/null
assert_eq "更新: exit 0" 0 $?
assert_eq "更新: base の変更が反映される" "gpt-updated" "$(toml_get "$CONFIG" model)"
assert_eq "更新: base の新規テーブルが追加される" "false" "$(toml_get "$CONFIG" features js_repl)"
assert_eq "更新: projects が残る" "trusted" "$(toml_get "$CONFIG" projects "$PROJECT" trust_level)"
assert_eq "更新: 機密が残る" "secret-token" "$(toml_get "$CONFIG" mcp_servers circleci env CIRCLECI_TOKEN)"
assert_eq "更新: バックアップが作られる" "gpt-base" "$(toml_get "$CODEX_HOME_DIR/config.toml.bak" model)"
assert_eq "更新: バックアップも 0600" "600" "$(stat -f %Lp "$CODEX_HOME_DIR/config.toml.bak")"

# --- base が管理するキーをローカルで変えても base の値に戻る ---
perl -pi -e 's/gpt-updated/gpt-local-edit/' "$CONFIG"
run_sync > /dev/null
assert_eq "上書き: base の値に戻る" "gpt-updated" "$(toml_get "$CONFIG" model)"

# --- 型が衝突しても base が勝つ (base はスカラー、ローカルはテーブル) ---
printf '\n[network_access]\nnested = true\n' >> "$CONFIG"
python3 - "$CONFIG" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); p.write_text(p.read_text().replace("network_access = true\n", ""))
PY
run_sync > /dev/null
assert_eq "型衝突: exit 0" 0 $?
assert_eq "型衝突: base のスカラーが勝つ" "true" "$(toml_get "$CONFIG" network_access)"

# --- --drift: ずれが無ければ exit 0 ---
out="$(run_sync --drift)"
assert_eq "drift なし: exit 0" 0 $?
assert_eq "drift なし: 報告" "drift なし" "$out"

# --- --drift: base 管理キーの上書き・base に無いキーを報告し、値は出さない ---
perl -pi -e 's/gpt-updated/gpt-local-edit/' "$CONFIG"
perl -pi -e 's/^(command = "pnpx")$/$1\nbearer_token = "sk-secret"/' "$CONFIG"
perl -pi -e 's/^(ENABLE_TOOL_SEARCH = "true")$/$1\nEXTRA_VAR = "1"\nNODE_REPL_TRUSTED_BROWSER_CLIENT_SHA256S = "hash"/' "$CONFIG"
perl -pi -e 's|^(source = "https://example.com/plugins.git")$|$1\nlast_updated = "2026-01-01T00:00:00Z"|' "$CONFIG"
cat >> "$CONFIG" <<'EOF'

[mcp_servers.slack]
command = "/usr/local/bin/slack-mcp"

[mcp_servers.slack.env]
SLACK_TOKEN = "slack-secret"

[mcp_servers.node_repl]
command = "/Applications/ChatGPT.app/node_repl"

[marketplaces.openai-bundled]
source_type = "local"

[desktop]
mode = "queue"
EOF
before="$(md5 -q "$CONFIG")"
out="$(run_sync --drift)"
assert_eq "drift あり: exit 1" 1 $?
assert_eq "drift あり: ファイルを書き換えない" "$before" "$(md5 -q "$CONFIG")"
assert_contains "drift あり: 上書きされたキー" "$out" 'model: local="gpt-local-edit" base="gpt-updated"'
assert_contains "drift あり: base に無い MCP サーバー" "$out" "mcp_servers.slack"
assert_contains "drift あり: base に無いネストしたキー" "$out" "shell_environment_policy.set.EXTRA_VAR"
assert_contains "drift あり: base 管理テーブル直下の未知キー" "$out" "mcp_servers.circleci.bearer_token"
assert_not_contains "drift あり: base 管理テーブル直下の値は出さない" "$out" "sk-secret"
assert_not_contains "drift あり: base に無いテーブルの値は出さない" "$out" "slack-secret"
assert_not_contains "drift あり: base 管理 MCP の env は報告しない" "$out" "CIRCLECI_TOKEN"
assert_not_contains "drift あり: projects は報告しない" "$out" "projects"
assert_not_contains "drift あり: hooks は報告しない" "$out" "hooks"
assert_not_contains "drift あり: ChatGPT アプリ由来の MCP は報告しない" "$out" "node_repl"
assert_not_contains "drift あり: ChatGPT アプリ由来の env は報告しない" "$out" "NODE_REPL_TRUSTED_BROWSER_CLIENT_SHA256S"
assert_not_contains "drift あり: 自動登録の marketplace は報告しない" "$out" "openai-bundled"
assert_not_contains "drift あり: marketplace の更新日時は報告しない" "$out" "last_updated"
assert_contains "drift あり: desktop は共有対象なので報告する" "$out" "desktop"

# --- --dry-run は書き込まず、変更されるキーだけを表示する ---
perl -pi -e 's/gpt-updated/gpt-dry/' "$BASE"
before="$(md5 -q "$CONFIG")"
out="$(run_sync --dry-run)"
assert_eq "dry-run: exit 0" 0 $?
assert_contains "dry-run: 変更されるキー" "$out" 'model: local="gpt-local-edit" base="gpt-dry"'
assert_not_contains "dry-run: ローカルの機密を出さない" "$out" "secret"
assert_eq "dry-run: ファイルが書き換わらない" "$before" "$(md5 -q "$CONFIG")"

# --- 壊れた config.toml は上書きしない ---
cp "$CONFIG" "$WORK/valid.toml"
printf 'broken = [\n' >> "$CONFIG"
run_sync > /dev/null 2>&1
assert_eq "壊れたTOML: 非0で終了する" 1 $?
assert_eq "壊れたTOML: ファイルを触らない" 0 "$(grep -q '^broken = \[$' "$CONFIG"; echo $?)"
cp "$WORK/valid.toml" "$CONFIG"

# --- 共通設定が無い・config.toml が無い場合はエラー ---
out="$(run_sync --base "$WORK/nonexistent.toml" 2>&1)"
assert_eq "base 無し: 非0で終了する" 1 $?
assert_contains "base 無し: 理由を表示する" "$out" "共通設定が見つかりません"
mv "$CONFIG" "$WORK/moved.toml"
out="$(run_sync --drift 2>&1)"
assert_eq "config 無しの drift: 非0で終了する" 1 $?
assert_contains "config 無しの drift: 理由を表示する" "$out" "先に sync を実行してください"
mv "$WORK/moved.toml" "$CONFIG"

# --- シンボリックリンクは置き換えないが、--drift は読み取りだけなので動く ---
mv "$CONFIG" "$WORK/linked.toml"
ln -s "$WORK/linked.toml" "$CONFIG"
run_sync > /dev/null 2>&1
assert_eq "symlink: 非0で終了する" 1 $?
assert_eq "symlink: リンクのまま残る" 0 "$([ -L "$CONFIG" ]; echo $?)"
out="$(run_sync --drift 2>&1)"
assert_eq "symlink: --drift は drift ありとして exit 1" 1 $?
assert_contains "symlink: --drift が報告を出す" "$out" "# 次の sync で base の値になるキー"
assert_not_contains "symlink: --drift がリンクを拒否しない" "$out" "シンボリックリンク"

# --- 生成した TOML の往復変換 ---
rm -f "$CONFIG"
cat > "$BASE" <<'EOF'
notify = ["/path/with space/app", "turn-ended"]
ratio = 1.5

[tui.model_availability_nux]
"gpt-5.5" = 2
gpt-6 = 4

[[servers]]
name = "a"
[[servers]]
name = "b"

[multi]
text = "line1\nline2\ttab \"quoted\""
"key\nwith newline" = 1
EOF
run_sync > /dev/null
assert_eq "往復: exit 0" 0 $?
assert_eq "往復: ドット入りキー" "2" "$(toml_get "$CONFIG" tui model_availability_nux "gpt-5.5")"
assert_eq "往復: 配列" '["/path/with space/app", "turn-ended"]' "$(toml_get "$CONFIG" notify)"
assert_eq "往復: float" "1.5" "$(toml_get "$CONFIG" ratio)"
assert_eq "往復: テーブル配列" '[{"name": "a"}, {"name": "b"}]' "$(toml_get "$CONFIG" servers)"
assert_eq "往復: エスケープ入り文字列" "$(printf 'line1\nline2\ttab "quoted"')" "$(toml_get "$CONFIG" multi text)"
assert_eq "往復: 改行入りキー" "1" "$(toml_get "$CONFIG" multi "$(printf 'key\nwith newline')")"

echo "PASS: $PASS, FAIL: $FAIL"
if [ "$FAIL" -ne 0 ]; then
    for line in "${FAIL_LOG[@]}"; do
        echo "  FAIL $line"
    done
fi
[ "$FAIL" -eq 0 ]
