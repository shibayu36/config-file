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
