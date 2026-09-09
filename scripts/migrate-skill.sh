#!/bin/bash
set -euo pipefail

die() {
  echo "migrate-skill: $*" >&2
  exit 1
}

usage() {
  echo "Usage: $0 copy|switch <skill-name> [--destination <agent-skills-path>]"
}

if [[ ${1:-} == --help ]]; then
  usage
  exit 0
fi
[[ $# -ge 2 ]] || { usage >&2; exit 1; }
action=$1
skill=$2
shift 2
[[ $action == copy || $action == switch ]] || die "copy または switch を指定してください"
[[ $skill =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "不正なスキル名です: $skill"

destination=''
if [[ $# -gt 0 ]]; then
  [[ $# == 2 && $1 == --destination ]] || die "不正なオプションです"
  destination=$2
fi
if [[ -z $destination ]]; then
  destination=$(ghq list -p | awk '/\/github.com\/shibayu36\/agent-skills$/')
fi
[[ -n $destination && -d $destination ]] || die "agent-skills が見つかりません。--destination で指定してください"
destination=$(cd "$destination" && pwd -P)
repo=$(cd "$(dirname "$0")/.." && pwd -P)
source_relative=''
for candidate in "skills/$skill" ".claude/skills/$skill"; do
  if [[ -e $repo/$candidate || -L $repo/$candidate ]]; then
    [[ -z $source_relative ]] || die "同名スキルが skills/ と .claude/skills/ の両方にあります"
    source_relative=$candidate
  fi
done
[[ -n $source_relative ]] || die "元スキルが存在しないため移行できません: $skill"
source_dir="$repo/$source_relative"
target_dir="$destination/skills/$skill"
installer="$repo/install-skills.sh"
install_header='pnpx skills add shibayu36/agent-skills -g -a claude-code codex -y --skill \'

[[ -d $source_dir && ! -L $source_dir ]] || die "元スキルが存在しないか、シンボリックリンクです: $source_dir"
[[ -f $source_dir/SKILL.md ]] || die "SKILL.md がありません"
declared_name=$(awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } /^name: / { sub(/^name: /, ""); print }' "$source_dir/SKILL.md")
[[ $declared_name == "$skill" ]] || die "SKILL.md の name とディレクトリ名が一致しません"
[[ -z $(find "$source_dir" -type l -print) ]] || die "スキル内のシンボリックリンクには対応していません"
[[ -d $destination/skills && ! -L $destination/skills ]] || die "移動先に実ディレクトリの skills/ が必要です"
[[ $destination != "$repo" ]] || die "移動元と移動先が同じです"
[[ ! -L $target_dir ]] || die "移動先がシンボリックリンクです"
if [[ -e $target_dir ]]; then
  [[ -d $target_dir ]] || die "移動先がディレクトリではありません"
  [[ -z $(find "$target_dir" -type l -print) ]] || die "移動先のスキル内にシンボリックリンクがあります"
fi

if [[ $action == copy ]]; then
  if [[ -d $target_dir ]]; then
    diff -r "$source_dir" "$target_dir" >/dev/null || die "移動先の内容が異なります。上書きしません"
  else
    cp -R "$source_dir" "$target_dir"
  fi
  echo "コピー完了: $target_dir"
  echo "コピー先を確認し、agent-skills 側で commit・push してください。"
  echo "公開後に switch $skill を実行してください。"
  exit 0
fi

[[ -d $target_dir ]] || die "先に copy を実行してください"
[[ -f $target_dir/SKILL.md ]] || die "コピー先に SKILL.md がありません"
declared_name=$(awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } /^name: / { sub(/^name: /, ""); print }' "$target_dir/SKILL.md")
[[ $declared_name == "$skill" ]] || die "コピー先の SKILL.md の name とスキル名が一致しません"
temp_file=$(mktemp)
awk -v skill="$skill" -v header="$install_header" '
  $0 == header { count++; in_block = 1; print; next }
  in_block {
    if ($1 == skill) found = 1
    if ($0 !~ /\\$/) {
      if (!found) { print $0 " \\"; print "  " skill } else print
      in_block = 0
      next
    }
  }
  { print }
  END { if (count != 1 || in_block) exit 1 }
' "$installer" > "$temp_file" || die "install-skills.sh の対象ブロックを更新できません"
bash -n "$temp_file"
command -v pnpx >/dev/null || die "pnpx が見つかりません"

user_root=${MIGRATE_SKILL_HOME:-$HOME}
canonical="$user_root/.agents/skills/$skill"
claude="$user_root/.claude/skills/$skill"
original_links=("$claude")
canonical_link=''
if [[ $source_relative == "skills/$skill" ]]; then
  original_links+=("$canonical")
else
  [[ ! -e $canonical && ! -L $canonical ]] || die "Codex 側に同名スキルが存在します: $canonical"
fi
for path in "${original_links[@]}"; do
  [[ -L $path ]] || die "元スキルへのリンクではありません: $path"
  resolved=$(cd "$path" && pwd -P) || die "リンク先を解決できません: $path"
  [[ $resolved == "$source_dir" ]] || die "想定外のリンク先です: $path"
done
if [[ -L $canonical ]]; then
  canonical_link=$(readlink "$canonical")
fi
claude_link=$(readlink "$claude")
recovery=$(mktemp -d)
cp "$installer" "$recovery/install-skills.sh"
canonical_changed=false
claude_removed=false
installer_changed=false

restore_links() {
  status=$?
  trap - EXIT
  if $installer_changed; then
    cat "$recovery/install-skills.sh" > "$installer" || { echo "復元失敗: $installer" >&2; exit 1; }
  fi
  if $canonical_changed; then
    if [[ -e $canonical || -L $canonical ]]; then
      mv "$canonical" "$recovery/canonical" || { echo "復元失敗: $canonical" >&2; exit 1; }
    fi
    if [[ -n $canonical_link ]]; then
      ln -s "$canonical_link" "$canonical" || { echo "復元失敗: $canonical" >&2; exit 1; }
    fi
  fi
  if $claude_removed; then
    if [[ -e $claude || -L $claude ]]; then
      mv "$claude" "$recovery/claude" || { echo "復元失敗: $claude" >&2; exit 1; }
    fi
    ln -s "$claude_link" "$claude" || { echo "復元失敗: $claude" >&2; exit 1; }
  fi
  echo "元リンクを復元しました。失敗時のインストール内容: $recovery" >&2
  exit "$status"
}

trap restore_links EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
canonical_changed=true
if [[ -n $canonical_link ]]; then
  unlink "$canonical"
fi
claude_removed=true
unlink "$claude"
pnpx skills add shibayu36/agent-skills -g -a claude-code codex -y --skill "$skill"
[[ -d $canonical && ! -L $canonical ]] || die "インストール先が実ディレクトリではありません"
[[ -z $(find "$canonical" -type l -print) ]] || die "インストール内容にシンボリックリンクがあります"
diff -r "$target_dir" "$canonical" >/dev/null || die "公開済みの内容とコピー先のスキルが一致しません"
[[ -L $claude ]] || die "Claude Code の参照先がリンクではありません"
resolved=$(cd "$claude" && pwd -P)
canonical_resolved=$(cd "$canonical" && pwd -P)
[[ $resolved == "$canonical_resolved" ]] || die "Claude Code の参照先がインストール先と一致しません"
installer_changed=true
cat "$temp_file" > "$installer"
trap - EXIT INT TERM
git -C "$repo" rm -r -- "$source_relative"
echo "移行完了: $skill"
echo "config-file 側の差分を確認して commit してください。"
