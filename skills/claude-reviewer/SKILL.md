---
name: claude-reviewer
description: Claude Code CLIを使ってコードレビューを実行する。指定された差分・PR・コミットをレビューする。修正は行わない。
---

## 実行範囲

このSkillはレビューのみを実行する。自分自身や同名agentを起動せず、self-reviewの呼び出し・コード修正・Gitの状態変更・外部への投稿を行わない。下記の外部CLI呼び出し以外には再委譲しない。適用されるAGENTS.md／CLAUDE.mdと依頼の要件を確認する。

## 対象の取得

親から差分・対象ファイル・要件が渡された場合は、その範囲を維持する。自分で取得する場合も以下の意味を変えない。

| 入力 | 対象 |
|---|---|
| 省略 / `diff` | `git diff` によるunstaged changesと、`git ls-files --others --exclude-standard -z`で列挙したuntracked filesの内容。staged changesは含めない |
| `staged` | `git diff --cached`のみ |
| `branch` / `ブランチ` | `git diff origin/main...HEAD` |
| PR番号 / PR URL | `gh pr diff <番号またはURL>` |
| その他 | 指定を保持し、指定ファイル・コミット・範囲などを確認する |

周辺コンテキストは読んでよいが、対象外の変更を指摘に混ぜない。stagedの変更後の内容はindex、branchはHEAD、PRはPRのheadを参照し、作業ツリーの別変更と混同しない。取得・実行が失敗した場合は「レビュー未完了」と原因を返す。指摘なしと未完了を区別する。

## Claude Code CLIの実行

1. 対象の定義、取得した差分とuntrackedの内容、作業ディレクトリ、依頼の要件をプロンプトファイルへ保存する。差分と対象ファイルの内容は手で転記・要約せず、保存済みファイルからプログラムでそのまま連結する。長文をコマンド引数へ埋め込まない。
2. プロンプトには「レビュー専用。コード修正・Gitの状態変更・外部投稿・subagent起動・self-reviewや他のCLIへの再委譲は禁止。品質・セキュリティ・パフォーマンスの観点で、場所・問題・根拠・提案を優先度順に報告。対象外の変更は指摘しない。取得失敗はレビュー未完了として報告」と明記する。
3. 対象リポジトリで次を実行する。`prompt_file`は作成済みの一時ファイルのパスとする。

```sh
claude --print --model opus --permission-mode plan --tools 'Read,Grep,Glob,Bash' --no-session-persistence < "$prompt_file"
```

4. プロセスが終了するまで待ち、終了コードと出力を確認する。CLI未導入・認証失敗・非ゼロ終了・途中終了・対象取得失敗は「レビュー未完了」としてエラー内容を返す。成功時はレビュー結果をそのまま返し、追加の解釈やフィルタリングをしない。
