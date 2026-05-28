---
name: code-review-report
description: 手元のコードを複数reviewerエージェントで並列レビューし、指摘を優先度順に並べたレポートを作成する（修正は行わない）
argument-hint: [レビュー対象] [reviewer名]
user-invocable: true
---

以下の手順を順番に実行してください。

## ステップ1: 引数の解釈

$ARGUMENTS を以下のルールで解釈してください：
- 第一引数: レビュー対象（省略時は「ブランチのdiff、PR化されていればそのPRのdiff」）
- 第二引数: reviewer名（省略時は全reviewerを並列実行）

### レビュー対象の指定方法
- 指定なし: 現在のブランチに紐づくPRがあれば `gh pr diff <番号>`、なければ `git diff origin/main...HEAD`
  - PRの有無は `gh pr view --json number 2>/dev/null` で判定する（成功すれば番号が取れる）
- `diff`: `git diff` + `git ls-files --others --exclude-standard` で新規ファイルも取得
- `staged`: `git diff --cached`
- `branch` または `ブランチ`: `git diff origin/main...HEAD`
- `PR #123` または `pr 123`: `gh pr diff 123`
- その他: そのまま渡す

### 利用可能なreviewer名
- `reviewer` - Claude自身による詳細レビュー
- `codex-reviewer` - Codex CLIを使ったレビュー
- `simplify-reviewer` - 可読性・一貫性・保守性に特化したレビュー

reviewer名が上記のいずれにも一致しない場合は、エラーとしてユーザーに利用可能なreviewer名を案内してください。

## ステップ2: レビュー実行

- reviewer名が指定された場合: そのreviewerのエージェントを起動し、レビュー対象の情報を渡してコードレビューを実行する
- reviewer名が省略された場合: 全reviewerのエージェントを**同時に並列起動**し、レビュー対象の情報を渡してコードレビューを実行する

## ステップ3: レポート作成

すべてのレビューが完了したら、各reviewerの指摘を集約してレポートを作成する。

### 3-1: 指摘の集約とマージ

- すべてのreviewerの指摘を1つのリストに集める
- 同じ箇所（ファイル + 行番号、または同等の対象）に対する指摘は1件にマージする
  - マージ時は本文を統合し、`指摘者: reviewer-A, reviewer-B`（N人）の形で誰が指摘したかを残す
  - 完全に同じ内容でなくとも、本質的に同じ問題を指している場合はマージ対象とする

### 3-2: 優先度の付与

各指摘に Critical / High / Medium / Low の4段階で優先度を付ける。判定基準：

- **Critical**: 動作しない・データ破損・セキュリティ脆弱性など、必ず修正が必要なもの
- **High**: バグや明確な設計上の問題。リリース前に修正すべきもの
- **Medium**: 改善した方がよい点。リーダビリティ・小さな設計改善など
- **Low**: 好みの問題・nits。修正は任意

複数reviewerが同じ箇所を指摘している場合は、その時点で重要度が高い可能性が高いため、優先度を1段階上げることを検討する。

### 3-3: レポート出力

優先度順（Critical → High → Medium → Low）に並べて、標準出力に以下のフォーマットで出力する。修正は行わない。

```
# コードレビューレポート

レビュー対象: <対象の説明>
実行reviewer: <reviewer名のリスト>
指摘件数: Critical=N, High=N, Medium=N, Low=N (合計 N件)

## Critical

### 1. <タイトル: 何が問題か一文で>
- ファイル: `path/to/file.ext:123`
- 指摘者: reviewer-A, codex-reviewer (2人)
- 内容: <指摘の詳細>
- 推奨対応: <どう直すべきか>

### 2. ...

## High

...

## Medium

...

## Low

...
```

指摘が0件の優先度セクションは省略してよい。全体で0件の場合は「指摘なし」とだけ出力する。
