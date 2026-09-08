---
name: self-review
description: Claude Code／Codexで複数reviewerによるセルフレビューを行う。外部CLI担当には対象の差分・ファイル内容・要件を送り、全レビュー完了後に妥当な指摘を逐次修正する。
argument-hint: "[レビュー対象] [reviewer名]"
user-invocable: true
---

## 1. 入力と実行環境の解釈

呼び出し時のユーザー入力・会話中の対象と要件を読む。`$ARGUMENTS`が展開されていれば使ってよいが、未展開の文字列や空値だけで対象を決めない。

入力は `[レビュー対象] [reviewer名]`。省略時の対象は`diff`。既知のreviewer名だけが渡された場合は対象を省略した単独指定とする。`PR #123 reviewer`のようにPR指定内の空白は対象の一部として保つ。末尾の既知名、`*-reviewer`、明示されたreviewer指定を担当名として取り出し、残りの対象・要件は自由文を含めて保持する。未知の担当名が明示された場合は対象の自由文に読み替えない。

実行環境は現在のホスト（Claude CodeかCodexか）で判定する。インストール済みCLIや対象リポジトリ内の設定ファイルの有無で判定しない。

| ホスト | 省略時に実行する4担当 | モデル |
|---|---|---|
| Claude Code | reviewer、simplify-reviewer、code-comment-reviewer、codex-reviewer | 通常3担当はOpus、codex-reviewerはSonnet（外部Codexはgpt-6-astra／high） |
| Codex | reviewer、simplify-reviewer、code-comment-reviewer、claude-reviewer | 通常3担当はgpt-6-astra／high、claude-reviewerはgpt-6-astra／low（外部ClaudeはOpus） |

reviewer指定時はそのホストの表にある1担当だけを実行する。対象ホストで使えない名前や未知の名前は、利用可能な4担当を案内して終了する。別のreviewerへ自動代替しない。

## 2. 対象の確定

| 入力 | 対象 |
|---|---|
| 省略 / `diff` | `git diff`のunstaged changes＋`git ls-files --others --exclude-standard -z`で列挙したuntracked filesの内容。staged changesは含めない |
| `staged` | `git diff --cached`のみ |
| `branch` / `ブランチ` | `git diff origin/main...HEAD` |
| PR番号 / PR URL | `gh pr diff <番号またはURL>` |
| その他 | 指定内容を保持して渡す |

対象の定義・差分・対象ファイル・要件・作業ディレクトリを全担当へ同じ内容で渡す。差分とファイル内容はレビュー開始時点のものを一時ディレクトリへ保存する。untrackedの列挙だけでなく内容も含め、長文はファイルで共有し、内容を手で転記しない。レビュー用の一時資料は対象差分にも今回の修正分にも含めない。対象と無関係な変更は含めない。ファイル全体を読む場合、stagedはindex、branchはHEAD、PRはPRのheadの内容を用い、作業ツリーの別変更と区別する。取得失敗は未完了として終了する。

## 3. レビューの実行

Claude Codeでは同名のsubagentを選び、frontmatterの`skills:`で事前読み込みされたSkillを実行させる。Codexでは`config.toml`の`[agents.<名前>]`から`config_file`で明示登録された同名TOMLのcustom agentを選び、`developer_instructions`で対応するSkillを読ませる。モデルと推論設定はagent定義を使う。

全担当に「レビューのみ。コード修正・Gitの状態変更・外部投稿・self-reviewの再呼び出し・再委譲は禁止。外部CLI担当のみ、Skillに指定された反対側CLIを1回起動する」と伝える。自分の担当Skillや参照資料が未読なら、読んでからレビューさせる。

外部CLI担当の実行には、確定した対象の差分・ファイル内容・要件を反対側CLIのサービスへ送ることが含まれる。同じ送信先・対象範囲について会話中ですでに得た許可は再確認しない。実行環境の承認要求が必要な場合は、ユーザーの依頼・送信先・送る対象範囲を具体的に記載する。実行環境の承認機構は迂回しない。

レビューは並列起動する。このSkillのレビュー並列実行は、通常の逐次作業ルールに対する例外として承認されている。同時実行枠が不足する場合は実行中の担当の終了を待って残りを起動し、全担当の終了と結果を待つ。部分結果だけで修正を始めない。

起動失敗・CLI未導入・認証失敗・実行エラー・途中終了はレビュー未完了とする。開始済みの担当の結果を回収し、完了／未完了と原因を報告して終了する。指摘なしと失敗を区別し、1担当でも未完了なら自動修正へ進まない。

## 4. 修正

全担当が成功した後、このSKILL.mdのディレクトリを基準に`../fix-review-comments/SKILL.md`を読み、全結果に適用する。親が指摘の妥当性を評価して逐次修正し、変更に応じた手動確認と自動テストを行う。

修正直前の作業ツリーの内容（untrackedを含む）と修正後を比較できるよう保存し、今回の修正分を特定する。元からある対象外の未コミット変更を修正分に混ぜない。レビュー中の外部変更が判明したら、同じ対象をレビューできていない旨を報告して停止する。

## 5. 修正後のコメントチェック

修正がなければ終了する。修正があった場合のみ、元の対象と今回の修正分をcode-comment-reviewerへ渡して1回レビューさせる。元の対象は修正後の内容と対応づけ、解消済みの問題を古い差分だけから再指摘させない。stagedやbranchでも今回のunstagedの修正を漏らさない。

成功時は親が妥当なコメント指摘だけを逐次修正し、必要な動作確認をする。失敗時はコメントチェック未完了と報告する。どちらもここから再レビューへ戻らない。最後に各担当の完了状況、対応した指摘・対応しなかった理由、検証結果を報告する。
