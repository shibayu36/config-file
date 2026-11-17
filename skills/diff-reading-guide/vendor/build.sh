#!/bin/bash
# entry.ts を1つのJSファイル highlight.mjs にまとめ、同梱物のライセンス表記を LICENSE に書き出す。
# 依存はこのリポジトリに残さず、一時ディレクトリで取得する。言語を足す時は entry.ts と GRAMMARS を直す。
set -euo pipefail

SHIKI_VERSION=4.6.0
GRAMMARS="go typescript tsx javascript json sql python yaml proto"
THEME=github-light

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$work"
bun init -y >/dev/null
bun add "shiki@$SHIKI_VERSION" tm-grammars tm-themes >/dev/null
cp "$here/entry.ts" .
bun build entry.ts --target=node --format=esm --minify --outfile="$here/highlight.mjs"

# tm-grammars・tm-themes の NOTICE から、Files: の行に対象のファイルを含む節だけを抜き出す
extract_notice() {
  local notice="$1"; shift
  local pattern
  pattern="$(printf '%s.json|' "$@")"
  awk -v pat="(^|[ ,])(${pattern%|})(,|$)" '
    /^=+$/ { if (keep) printf "%s", buf; buf = $0 "\n"; keep = 0; next }
    { buf = buf $0 "\n"; if ($0 ~ /^Files:/ && $0 ~ pat) keep = 1 }
    END { if (keep) printf "%s", buf }
  ' "$notice"
}

{
  echo "highlight.mjs bundles the following third-party software."
  echo
  for pkg in shiki @shikijs/core @shikijs/engine-javascript @shikijs/langs @shikijs/themes @shikijs/types @shikijs/primitive @shikijs/vscode-textmate oniguruma-to-es regex regex-recursion regex-utilities; do
    dir="node_modules/$pkg"
    [ -d "$dir" ] || continue
    echo "========================================================================"
    echo "$pkg $(jq -r .version "$dir/package.json") ($(jq -r .license "$dir/package.json"))"
    echo "------------------------------------------------------------------------"
    cat "$dir"/LICENSE* 2>/dev/null || echo "(LICENSE file not included in the package)"
    echo
  done
  echo "========================================================================"
  echo "Grammars and theme (from tm-grammars / tm-themes NOTICE)"
  # shellcheck disable=SC2086
  extract_notice node_modules/tm-grammars/NOTICE $GRAMMARS
  extract_notice node_modules/tm-themes/NOTICE "$THEME"
  echo "========================================================================"
  echo "Files:   yaml.json"
  echo "Source:  https://github.com/textmate/yaml.tmbundle (README.mdown, License)"
  echo "------------------------------------------------------------------------"
  echo "Permission to copy, use, modify, sell and distribute this"
  echo "software is granted. This software is provided \"as is\" without"
  echo "express or implied warranty, and with no claim as to its"
  echo "suitability for any purpose."
} > "$here/LICENSE"

echo "built: $here/highlight.mjs ($(wc -c < "$here/highlight.mjs") bytes)"
