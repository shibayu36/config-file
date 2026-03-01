---
description: 手元のコードをreviewerエージェントでセルフレビューし、指摘に基づいて自動修正するループ
argument-hint: <reviewer名> [レビュー対象]
---

以下の手順を順番に実行してください。

## ステップ1: 引数の解釈

$ARGUMENTS を以下のルールで解釈してください：
- 最初の単語: reviewer名（エージェント名）
- 残りの部分: レビュー対象（省略時は「branch」= origin/mainとの差分）

利用可能なreviewer名:
- `reviewer` - Claude自身による詳細レビュー
- `codex-reviewer` - Codex CLIを使ったレビュー

reviewer名が上記のいずれにも一致しない場合は、エラーとしてユーザーに利用可能なreviewer名を案内してください。

## ステップ2: レビュー実行

ステップ1で特定したreviewer名に対応するエージェントを起動し、レビュー対象の情報を渡してコードレビューを実行してください。

## ステップ3: レビュー修正

レビューが完了したら、/fix-review-comments スキルを実行して、レビュー指摘に対応してください。
