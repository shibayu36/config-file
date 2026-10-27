---
name: code-review-report
description: Claude Code／Codexで複数reviewerによる並列レビューを行い、指摘を優先度順に並べたレポートを作成する（修正は行わない）。他人のPRのレビューにも使う。外部CLI担当には対象の差分・ファイル内容・要件を送る。
argument-hint: "[レビュー対象] [reviewer名]"
user-invocable: true
---

## 1. 入力と実行環境の解釈

呼び出し時のユーザー入力・会話中の対象と要件を読む。`$ARGUMENTS`が展開されていれば使ってよいが、未展開の文字列や空値だけで対象を決めない。

入力は `[レビュー対象] [reviewer名]`。既知のreviewer名だけが渡された場合は対象を省略した単独指定とする。`PR #123 reviewer`のようにPR指定内の空白は対象の一部として保つ。末尾の既知名、`*-reviewer`、明示されたreviewer指定を担当名として取り出し、残りの対象・要件は自由文を含めて保持する。未知の担当名が明示された場合は対象の自由文に読み替えない。

実行環境は現在のホスト（Claude CodeかCodexか）で判定する。インストール済みCLIや対象リポジトリ内の設定ファイルの有無で判定しない。

| ホスト | 省略時に実行する4担当 | モデル |
|---|---|---|
| Claude Code | reviewer、simplify-reviewer、code-comment-reviewer、codex-reviewer | 通常3担当はOpus、codex-reviewerはSonnet（外部Codexはgpt-6-astra／high） |
| Codex | reviewer、simplify-reviewer、code-comment-reviewer、claude-reviewer | 通常3担当はgpt-6-astra／high、claude-reviewerはgpt-6-astra／low（外部ClaudeはOpus） |

reviewer指定時はそのホストの表にある1担当だけを実行する。対象ホストで使えない名前や未知の名前は、利用可能な4担当を案内して終了する。別のreviewerへ自動代替しない。

## 2. 対象の確定

| 入力 | 対象 |
|---|---|
| 省略 | 現在のブランチに紐づくPRがあれば`gh pr diff <番号>`、なければ`branch`と同じ。PRの有無は`gh pr view --json number`の成否で判定する |
| `diff` | `git diff`のunstaged changes＋`git ls-files --others --exclude-standard -z`で列挙したuntracked filesの内容。staged changesは含めない |
| `staged` | `git diff --cached`のみ |
| `branch` / `ブランチ` | `git diff origin/main...HEAD` |
| PR番号 / PR URL | `gh pr diff <番号またはURL>` |
| その他 | 指定内容を保持して渡す |

対象の定義・差分・対象ファイル・要件・作業ディレクトリを全担当へ同じ内容で渡す。差分とファイル内容はレビュー開始時点のものを一時ディレクトリへ保存する。untrackedの列挙だけでなく内容も含め、長文はファイルで共有し、内容を手で転記しない。レビュー用の一時資料は対象差分に含めない。対象と無関係な変更は含めない。ファイル全体を読む場合、stagedはindex、branchはHEAD、PRはPRのheadの内容を用い、作業ツリーの別変更と区別する。取得失敗は未完了として終了する。

## 3. レビューの実行

Claude Codeでは同名のsubagentを選び、frontmatterの`skills:`で事前読み込みされたSkillを実行させる。Codexでは`config.toml`の`[agents.<名前>]`から`config_file`で明示登録された同名TOMLのcustom agentを選び、`developer_instructions`で対応するSkillを読ませる。モデルと推論設定はagent定義を使う。

全担当に「レビューのみ。コード修正・Gitの状態変更・外部投稿・code-review-report／self-reviewの再呼び出し・再委譲は禁止。外部CLI担当のみ、Skillに指定された反対側CLIを1回起動する」と伝える。自分の担当Skillや参照資料が未読なら、読んでからレビューさせる。

外部CLI担当の実行には、確定した対象の差分・ファイル内容・要件を反対側CLIのサービスへ送ることが含まれる。同じ送信先・対象範囲について会話中ですでに得た許可は再確認しない。実行環境の承認要求が必要な場合は、ユーザーの依頼・送信先・送る対象範囲を具体的に記載する。実行環境の承認機構は迂回しない。

レビューは並列起動する。このSkillのレビュー並列実行は、通常の逐次作業ルールに対する例外として承認されている。同時実行枠が不足する場合は実行中の担当の終了を待って残りを起動し、全担当の終了と結果を待つ。部分結果だけでレポートを作らない。

起動失敗・CLI未導入・認証失敗・実行エラー・途中終了はレビュー未完了とする。開始済みの担当の結果を回収し、指摘なしと失敗を区別する。1担当でも未完了なら、完了した担当の結果だけでレポートを作り、未完了の担当と原因をレポートに明記する。外部CLI担当（codex-reviewer／claude-reviewer）の未完了は「未完了reviewer」行ではなく、レポート末尾の注意として書く。

## 4. レポート作成

### 4-1. 指摘の集約とマージ

- すべての担当の指摘を1つのリストに集める
- 同じ箇所（ファイル + 行番号、または同等の対象）に対する指摘は1件にマージする
  - マージ時は本文を統合し、`指摘者: reviewer-A, reviewer-B`（N人）の形で誰が指摘したかを残す
  - 完全に同じ内容でなくとも、本質的に同じ問題を指している場合はマージ対象とする

### 4-2. 優先度の付与

各指摘に Critical / High / Medium / Low の4段階で優先度を付ける。判定基準：

- **Critical**: 動作しない・データ破損・セキュリティ脆弱性など、必ず修正が必要なもの
- **High**: バグや明確な設計上の問題。リリース前に修正すべきもの
- **Medium**: 改善した方がよい点。リーダビリティ・小さな設計改善など
- **Low**: 好みの問題・nits。修正は任意

複数の担当が同じ箇所を指摘している場合は、その時点で重要度が高い可能性が高いため、優先度を1段階上げることを検討する。

### 4-3. レポート出力

優先度順（Critical → High → Medium → Low）に並べて、以下のフォーマットで出力する。修正は行わない。

```
# コードレビューレポート

レビュー対象: <対象の説明>
実行reviewer: <担当名のリスト>
未完了reviewer: <外部CLI担当以外の担当名と原因。なければこの行は省略>
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

注意: <外部CLI担当名>は未完了（原因: <原因>）。この担当の指摘はレポートに含まれていない。外部CLI担当が完了していればこの行は省略
```

指摘が0件の優先度セクションは省略してよい。全担当が完了し、全体で0件の場合は「指摘なし」とだけ出力する。外部CLI担当だけが未完了で、全体で0件の場合は「指摘なし」の後に注意を付ける。
