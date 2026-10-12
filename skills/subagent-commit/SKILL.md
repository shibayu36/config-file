---
name: subagent-commit
description: 軽量モデルのsubagentでcommitメッセージを生成し、commitする
model: sonnet
user-invocable: true
disable-model-invocation: true
---

以下の手順でcommitを行ってください。

## 1. 状況の判断

会話の文脈から、以下のどちらかを判断する：
- **単発commit**（デフォルト）: ユーザーからcommit分割の指示がない場合
- **複数commit**: ユーザーからcommit分割計画が明示的に提示されている場合

## 2-A. 単発commitの場合

1. `git diff --cached --stat` でステージングされたファイルがあるか確認する
2. ステージングされたファイルがある場合 → そのまま対象にする
3. ステージングされたファイルがない場合 → 今の会話で変更したファイルを `git add` してステージングする
4. 「3. commitメッセージ生成subagentの起動」に従ってcommitメッセージを生成する
5. 生成したメッセージでcommitを実行する

## 2-B. 複数commitの場合

### フェーズ1: commitメッセージの並列生成
1. 各commitの対象ファイルと変更内容を整理する
2. 「3. commitメッセージ生成subagentの起動」に従い、subagentを**全commit分、並列で起動**してメッセージを同時に生成する

### フェーズ2: 順次commit実行
計画順に以下を繰り返す：
1. 対象ファイルを `git add` でステージングする
2. 生成済みのメッセージで `git commit` する
3. 成功を確認してから次へ進む。失敗した場合は処理を中断し、状況をユーザーに報告する

## 3. commitメッセージ生成subagentの起動

このSKILL.mdと同じディレクトリにある`commit-message-prompt.md`を読み、その内容と対象のcommitに含めるファイルをsubagentへの指示として渡す。subagentは軽量モデルで起動し、親の会話履歴は引き継がせない。

| ホスト | 起動方法 |
|---|---|
| Claude Code | Agentツールで`general-purpose`を起動し、`model`に`haiku`を指定する |
| Codex | `spawn_agent`で起動し、`fork_turns`に`"none"`、`model`に`gpt-6-luna`、`reasoning_effort`に`low`を指定する |

## 出力

生成したcommitメッセージをセッション中に共有する。
複数commitの場合は、各commitの番号・対象ファイル・メッセージ・結果を共有する。
