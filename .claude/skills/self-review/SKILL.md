---
name: self-review
description: 手元のコードをreviewerエージェントでセルフレビューし、指摘に基づいて自動修正するループ
argument-hint: [レビュー対象] [reviewer名]
user-invocable: true
---

以下の手順を順番に実行してください。

## ステップ1: 引数の解釈

$ARGUMENTS を以下のルールで解釈してください：
- 第一引数: レビュー対象（省略時は `diff` = 現在のunstaged changes + untracked files）
- 第二引数: reviewer名（省略時は全reviewerを並列実行）

### レビュー対象の指定方法
- 指定なし / `diff`: `git diff` + `git ls-files --others --exclude-standard` で新規ファイルも取得
- `staged`: `git diff --cached`
- `branch` または `ブランチ`: `git diff origin/main...HEAD`
- `PR #123` または `pr 123`: `gh pr diff 123`
- その他: そのまま渡す

### 利用可能なreviewer名
- `reviewer` - Claude自身による詳細レビュー
- `codex-reviewer` - Codex CLIを使ったレビュー
- `simplify-reviewer` - 可読性・一貫性・保守性に特化したレビュー
- `code-comment-reviewer` - コードコメントに特化したレビュー（不要・有害なコメントの削除提案）

reviewer名が上記のいずれにも一致しない場合は、エラーとしてユーザーに利用可能なreviewer名を案内してください。

## ステップ2: レビュー実行

- reviewer名が指定された場合: そのreviewerのエージェントを起動し、レビュー対象の情報を渡してコードレビューを実行する
- reviewer名が省略された場合: 全reviewerのエージェントを**同時に並列起動**し、レビュー対象の情報を渡してコードレビューを実行する

## ステップ3: レビュー修正

すべてのレビューが完了したら、/fix-review-comments スキルを実行して、レビュー指摘に対応してください。

## ステップ4: 修正後のコメントチェック

ステップ3で1件以上の修正を行った場合、修正によって新たに規約違反のコメントが混入していないかを確認する。ステップ3で何も修正しなかった場合、このステップはスキップする。

1. code-comment-reviewer エージェントを起動し、ステップ1のレビュー対象にステップ3での修正分（未コミットの変更）を含めた差分をレビューさせる
2. 指摘があれば妥当性を評価し、妥当なもののみ修正する

このステップは1回のみ実行し、修正後に再度レビューへ戻るループはしない。
