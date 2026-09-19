#!/bin/bash
set -euo pipefail

die() {
  echo "install-cursor-extensions: $*" >&2
  exit 1
}

repo=$(cd "$(dirname "$0")/.." && pwd -P)
extension_list=$repo/cursor/extensions.txt
vsix_list=$repo/cursor/extensions-vsix.tsv
download_dir=$repo/tmp/cursor-vsix
marketplace=https://marketplace.visualstudio.com/_apis/public/gallery/publishers

command -v cursor >/dev/null 2>&1 ||
  die "cursor コマンドがありません。Cursor の Command Palette で Shell Command: Install 'cursor' command を実行してください"
[[ -f $extension_list ]] || die "$extension_list がありません"
[[ -f $vsix_list ]] || die "$vsix_list がありません"

failed=''
record_failure() {
  failed="${failed}  $1"$'\n'
}

echo "==> マーケットプレイスからインストール"
while read -r id || [[ -n $id ]]; do
  [[ -z $id || $id == \#* ]] && continue
  echo "--- $id"
  cursor --install-extension "$id" </dev/null || record_failure "$id"
done <"$extension_list"

echo "==> vsix をダウンロードしてインストール"
mkdir -p "$download_dir"
while IFS=$'\t' read -r publisher name version || [[ -n $publisher ]]; do
  [[ -z $publisher || $publisher == \#* ]] && continue
  id=$publisher.$name@$version
  vsix=$download_dir/$publisher.$name-$version.vsix
  echo "--- $id"
  if [[ ! -f $vsix ]]; then
    # vspackage は gzip で返るため --compressed で展開させる
    if ! curl -fsSL --compressed -o "$vsix" "$marketplace/$publisher/vsextensions/$name/$version/vspackage"; then
      rm -f "$vsix"
      record_failure "$id (ダウンロード失敗)"
      continue
    fi
  fi
  cursor --install-extension "$vsix" </dev/null || record_failure "$id"
done <"$vsix_list"

if [[ -n $failed ]]; then
  echo
  printf '以下のインストールに失敗しました:\n%s' "$failed" >&2
  exit 1
fi

echo
echo "すべてインストールしました。ダウンロードした vsix は $download_dir に残しています"
