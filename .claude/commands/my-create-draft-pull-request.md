---
description: GitHubのDraft PullRequestを作成する
allowed-tools: Bash(git push:*), Bash(open:*)
---

次の手順でGitHubのDraft PullRequestを作成してください。

1. git pushがまだであればgit push -uでpushする
2. PullRequestを作るための情報を収集する
    - mainのブランチとの差分をgit diffで確認
    - `.github/pull_request_template.md`があれば参照する
    - 直近のマージされた自分のPullRequestをghコマンドで5件取得し、具体的な書き方を確認。もし件数が5件未満なら、他の人のPullRequestも取得する
          - 言語（日本語・英語・その他）
          - メッセージの構造（1行形式 vs 複数行形式）
          - プレフィックスの使用（feat:, fix:, docs: など）
          - 文体や敬語の使用パターン
          - 文字数の傾向
          - その他の特徴的なパターン
    - 情報が不足していたら、わたしに聞いてください
3. 取得した情報をもとにPullRequestを作成する。わたしをアサインする(@meを使う)。
    - PRの説明は「なぜこの変更をしたか（背景・動機）」と「変更の概要（高レベルな要約）」を中心に書く
    - diffを見ればわかる詳細（変更したファイル名、フィールド名、メソッド名の一覧など）はリストアップしない
    - レビュアーがdiffを読む前に知っておくべきコンテキスト（設計判断の理由、影響範囲、注意点など）があれば書く
4. openコマンドでPullRequestのURLを開く
