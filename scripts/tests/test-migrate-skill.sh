#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd -P)
work=$(mktemp -d)
work=$(cd "$work" && pwd -P)

setup() {
  fixture="$work/$1"
  source_relative="${2:-skills}/example"
  mkdir -p "$fixture/config/scripts" "$fixture/config/$source_relative/references" "$fixture/agent skills/skills"
  cp "$repo/scripts/migrate-skill.sh" "$fixture/config/scripts/"
  cp "$repo/install-skills.sh" "$fixture/config/"
  cp "$repo/install-skills.sh" "$fixture/installer-before.sh"
  printf '%s\n' '---' 'name: example' 'description: Example skill' '---' 'Example' > "$fixture/config/$source_relative/SKILL.md"
  printf '%s\n' 'Reference' > "$fixture/config/$source_relative/references/guide.md"
  printf '%s\n' "$fixture/config/$source_relative" > "$fixture/source-path"
  git -C "$fixture/config" init --quiet --template=
  git -C "$fixture/config" add -- "$source_relative"
  git -C "$fixture/config" -c user.name=Test -c user.email=test@example.com -c core.hooksPath=/dev/null \
    commit --quiet --no-gpg-sign -m 'Add example skill'
}

run() {
  MIGRATE_SKILL_HOME="$fixture/user" PATH="$fixture/stubs:$PATH" \
    bash "$fixture/config/scripts/migrate-skill.sh" "$@" --destination "$fixture/agent skills"
}

expect_failure() {
  expected_message=$1
  shift
  if "$@" > "$work/error.log" 2>&1; then
    echo "FAIL: expected failure: $*" >&2
    exit 1
  fi
  if ! grep -Fq -- "$expected_message" "$work/error.log"; then
    cat "$work/error.log" >&2
    echo "FAIL: missing error message: $expected_message" >&2
    exit 1
  fi
}

setup copy
run copy example
diff -r "$fixture/config/skills/example" "$fixture/agent skills/skills/example"
run copy example
cmp "$fixture/installer-before.sh" "$fixture/config/install-skills.sh"
[[ -f $fixture/config/skills/example/SKILL.md ]]
bash -n "$fixture/config/install-skills.sh"
echo 'PASS: copy copies references and preserves source and installer on repeated runs'

printf '%s\n' 'Conflict' >> "$fixture/agent skills/skills/example/SKILL.md"
expect_failure '移動先の内容が異なります' run copy example
tail -1 "$fixture/agent skills/skills/example/SKILL.md" | rg -q '^Conflict$'
echo 'PASS: conflicting destination is preserved'

setup invalid
expect_failure '不正なスキル名' run copy ../example
expect_failure '元スキルが存在しない' run copy missing
printf '%s\n' '---' 'name: mismatch' '---' > "$fixture/config/skills/example/SKILL.md"
expect_failure 'name とディレクトリ名が一致しません' run copy example
[[ ! -e $fixture/agent\ skills/skills/example ]]
echo 'PASS: invalid names, missing skills, and mismatched names are rejected'

setup copy_without_installer
run copy example
unlink "$fixture/config/install-skills.sh"
run copy example
echo 'PASS: copy does not require an installer'

setup_switch() {
  setup "$1" "${2:-skills}"
  run copy example
  mkdir -p "$fixture/user/.agents/skills" "$fixture/user/.claude/skills" "$fixture/stubs"
  if [[ $source_relative == skills/example ]]; then
    ln -s "$fixture/config/$source_relative" "$fixture/user/.agents/skills/example"
  fi
  ln -s "$fixture/config/$source_relative" "$fixture/user/.claude/skills/example"
  cat > "$fixture/stubs/pnpx" <<'STUB'
#!/bin/bash
set -euo pipefail
[[ "$*" == 'skills add shibayu36/agent-skills -g -a claude-code codex -y --skill example' ]]
fixture=$(cd "$MIGRATE_SKILL_HOME/.." && pwd -P)
canonical="$MIGRATE_SKILL_HOME/.agents/skills/example"
cp -R "$fixture/agent skills/skills/example" "$canonical"
if [[ -f $fixture/fail ]]; then
  echo 'Simulated install failure' >&2
  exit 42
fi
ln -s '../../.agents/skills/example' "$MIGRATE_SKILL_HOME/.claude/skills/example"
if [[ -f $fixture/mismatch ]]; then
  printf '%s\n' 'Remote difference' >> "$canonical/SKILL.md"
fi
if [[ -f $fixture/wrong-link ]]; then
  unlink "$MIGRATE_SKILL_HOME/.claude/skills/example"
  ln -s "$(cat "$fixture/source-path")" "$MIGRATE_SKILL_HOME/.claude/skills/example"
fi
STUB
  chmod +x "$fixture/stubs/pnpx"
}

assert_restored() {
  [[ -f $fixture/config/$source_relative/SKILL.md ]]
  if [[ $source_relative == skills/example ]]; then
    [[ $(readlink "$fixture/user/.agents/skills/example") == "$fixture/config/$source_relative" ]]
  else
    [[ ! -e $fixture/user/.agents/skills/example && ! -L $fixture/user/.agents/skills/example ]]
  fi
  [[ $(readlink "$fixture/user/.claude/skills/example") == "$fixture/config/$source_relative" ]]
  cmp "$fixture/installer-before.sh" "$fixture/config/install-skills.sh"
}

setup_switch success
run switch example
[[ ! -e $fixture/config/skills/example ]]
git -C "$fixture/config" diff --cached --name-status > "$fixture/staged.txt"
printf 'D\tskills/example/SKILL.md\nD\tskills/example/references/guide.md\n' > "$fixture/expected-staged.txt"
diff -u "$fixture/expected-staged.txt" "$fixture/staged.txt"
[[ ! -L $fixture/user/.agents/skills/example ]]
diff -r "$fixture/agent skills/skills/example" "$fixture/user/.agents/skills/example"
[[ $(cd "$fixture/user/.claude/skills/example" && pwd -P) == "$fixture/user/.agents/skills/example" ]]
[[ $(awk '$1 == "example" { n++ } END { print n+0 }' "$fixture/config/install-skills.sh") == 1 ]]
awk '
  /^pnpx skills add shibayu36\/agent-skills / { in_block = 1; next }
  in_block && $1 == "example" { found = 1 }
  /^$/ { in_block = 0 }
  END { exit !found }
' "$fixture/config/install-skills.sh"
bash -n "$fixture/config/install-skills.sh"
expect_failure '元スキルが存在しない' run switch example
echo 'PASS: switch installs, updates the correct list, removes source, and rejects a second switch'

setup_switch edited_copy
printf '%s\n' 'Reviewed improvement' >> "$fixture/agent skills/skills/example/SKILL.md"
run switch example
tail -1 "$fixture/user/.agents/skills/example/SKILL.md" | rg -q '^Reviewed improvement$'
[[ ! -e $fixture/config/skills/example ]]
echo 'PASS: switch installs the reviewed copy even when it differs from the source'

setup_switch installer
printf '%s\n' '#!/bin/bash' > "$fixture/config/install-skills.sh"
cp "$fixture/config/install-skills.sh" "$fixture/installer-before.sh"
expect_failure '対象ブロックを更新できません' run switch example
assert_restored
echo 'PASS: invalid installer blocks switching without changing links'

setup_switch invalid_copy
printf '%s\n' '---' 'name: mismatch' '---' > "$fixture/agent skills/skills/example/SKILL.md"
expect_failure 'コピー先の SKILL.md の name とスキル名が一致しません' run switch example
assert_restored
echo 'PASS: switching rejects a renamed skill in the copy'

setup_switch failed_install
touch "$fixture/fail"
expect_failure 'Simulated install failure' run switch example
assert_restored
echo 'PASS: partial installation failure restores links and keeps source'

setup_switch mismatch
touch "$fixture/mismatch"
expect_failure '公開済みの内容とコピー先のスキルが一致しません' run switch example
assert_restored
echo 'PASS: remote content mismatch restores links and keeps source'

setup_switch wrong_link
touch "$fixture/wrong-link"
expect_failure 'Claude Code の参照先がインストール先と一致しません' run switch example
assert_restored
echo 'PASS: incorrect installed link restores original links'

setup_switch unexpected
unlink "$fixture/user/.claude/skills/example"
mkdir "$fixture/user/.claude/skills/example"
printf '%s\n' 'Preserve me' > "$fixture/user/.claude/skills/example/personal.txt"
expect_failure '元スキルへのリンクではありません' run switch example
[[ -f $fixture/user/.claude/skills/example/personal.txt ]]
[[ $(readlink "$fixture/user/.agents/skills/example") == "$fixture/config/skills/example" ]]
echo 'PASS: unexpected existing directory is preserved'

setup_switch dangling
unlink "$fixture/user/.claude/skills/example"
ln -s "$fixture/missing" "$fixture/user/.claude/skills/example"
expect_failure 'リンク先を解決できません' run switch example
[[ $(readlink "$fixture/user/.claude/skills/example") == "$fixture/missing" ]]
echo 'PASS: dangling link reports its cause without changing the link'

setup ambiguous
mkdir -p "$fixture/config/.claude/skills"
cp -R "$fixture/config/skills/example" "$fixture/config/.claude/skills/example"
expect_failure '同名スキルが skills/ と .claude/skills/ の両方にあります' run copy example
expect_failure '同名スキルが skills/ と .claude/skills/ の両方にあります' run switch example
[[ ! -e $fixture/agent\ skills/skills/example ]]
echo 'PASS: ambiguous source is rejected without copying'

setup_switch claude_success .claude/skills
diff -r "$fixture/config/.claude/skills/example" "$fixture/agent skills/skills/example"
run switch example
[[ ! -e $fixture/config/.claude/skills/example ]]
[[ -d $fixture/user/.agents/skills/example && ! -L $fixture/user/.agents/skills/example ]]
diff -r "$fixture/agent skills/skills/example" "$fixture/user/.agents/skills/example"
[[ $(cd "$fixture/user/.claude/skills/example" && pwd -P) == "$fixture/user/.agents/skills/example" ]]
git -C "$fixture/config" diff --cached --name-status > "$fixture/staged.txt"
printf 'D\t.claude/skills/example/SKILL.md\nD\t.claude/skills/example/references/guide.md\n' > "$fixture/expected-staged.txt"
diff -u "$fixture/expected-staged.txt" "$fixture/staged.txt"
echo 'PASS: Claude-only skill is installed for both agents and its actual source deletion is staged'

for failure_mode in fail mismatch wrong-link; do
  setup_switch "claude_$failure_mode" .claude/skills
  touch "$fixture/$failure_mode"
  case $failure_mode in
    fail) expected='Simulated install failure' ;;
    mismatch) expected='公開済みの内容とコピー先のスキルが一致しません' ;;
    wrong-link) expected='Claude Code の参照先がインストール先と一致しません' ;;
  esac
  expect_failure "$expected" run switch example
  assert_restored
  echo "PASS: Claude-only skill restores its original state after $failure_mode"
done

setup_switch claude_conflict .claude/skills
mkdir "$fixture/user/.agents/skills/example"
printf '%s\n' 'Preserve me' > "$fixture/user/.agents/skills/example/personal.txt"
expect_failure 'Codex 側に同名スキルが存在します' run switch example
[[ $(cat "$fixture/user/.agents/skills/example/personal.txt") == 'Preserve me' ]]
[[ $(readlink "$fixture/user/.claude/skills/example") == "$fixture/config/.claude/skills/example" ]]
cmp "$fixture/installer-before.sh" "$fixture/config/install-skills.sh"
echo 'PASS: existing Codex skill blocks Claude-only migration without changes'

setup_switch claude_dangling_conflict .claude/skills
ln -s "$fixture/missing" "$fixture/user/.agents/skills/example"
expect_failure 'Codex 側に同名スキルが存在します' run switch example
[[ $(readlink "$fixture/user/.agents/skills/example") == "$fixture/missing" ]]
echo 'PASS: dangling Codex link also blocks Claude-only migration'

for interrupted_link in canonical claude claude_only; do
  if [[ $interrupted_link == claude_only ]]; then
    setup_switch interrupted_claude_only .claude/skills
    interrupted_link=claude
  else
    setup_switch "interrupted_$interrupted_link"
  fi
  printf '%s\n' "$interrupted_link" > "$fixture/interrupt"
  cat > "$fixture/stubs/unlink" <<'STUB'
#!/bin/bash
set -euo pipefail
fixture=$(cd "$MIGRATE_SKILL_HOME/.." && pwd -P)
/usr/bin/unlink "$@"
interrupted_link=$(cat "$fixture/interrupt")
if [[ $interrupted_link == canonical && $1 == */.agents/skills/example ]] ||
   [[ $interrupted_link == claude && $1 == */.claude/skills/example ]]; then
  kill -TERM "$PPID"
fi
STUB
  chmod +x "$fixture/stubs/unlink"
  expect_failure '元リンクを復元しました' run switch example
  assert_restored
  echo "PASS: signal immediately after unlink restores $interrupted_link link"
done
