# このリポジトリ専用のスクリプト

## スキルの移行

安定した `skills/<名前>` または `claude/skills/<名前>` を個人の `shibayu36/agent-skills` に移し、Claude Code と Codex のグローバルインストールへ切り替える。

```bash
./scripts/migrate-skill.sh copy reviewer
# agent-skills 側の差分を確認して commit・push する。
./scripts/migrate-skill.sh switch reviewer
# config-file 側の差分を確認して commit する。
```

`reviewer` を移行したいスキル名に置き換える。移動先は ghq 管理下の `shibayu36/agent-skills`。別の場所を使う場合は、両コマンドに `--destination /path/to/agent-skills` を指定する。

`copy` はコピーのみ、`switch` はインストール一覧への追加とグローバルインストールへの切り替えを行う。

## Cursorの拡張機能のインストール

```bash
./scripts/install-cursor-extensions.sh
```

リストは2つ。`cursor/extensions.txt` はCursorのマーケットプレイスにあるもの、`cursor/extensions-vsix.tsv` は無いもので、Visual Studio Marketplaceからvsixを落として入れる。

拡張を足すときはこれで判定する。ヒットすれば `extensions.txt`、しなければ `extensions-vsix.tsv`。

```bash
curl -s -X POST 'https://marketplace.cursorapi.com/_apis/public/gallery/extensionquery' \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json;api-version=3.0-preview.1' \
  -d '{"filters":[{"criteria":[{"filterType":7,"value":"<publisher>.<name>"}],"pageSize":1}],"flags":914}' |
  jq '.results[0].extensions | length'
```

`swiftlang.swift-vscode` → `llvm-vs-code-extensions.lldb-dap` のように依存で自動で入るものは書かない。

`cursor --list-extensions` は `~/.cursor/extensions/extensions.json` を読むだけで、ディレクトリが消えた過去の拡張も出てくる。リストを作り直すときは実体のあるものだけ拾う。
