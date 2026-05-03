---
name: reply-fix-to-review-comments
description: GitHub PR のレビューコメント（インライン）に対し、直前の会話で対応した commit を紐付けて「<sha> で修正しました」という Reply をまとめて投稿する。「レビュー Reply して」「レビューコメントに返信して」「修正報告投稿して」などのリクエストで使用。コード修正そのものは扱わず、修正・commit 済みの状態から呼ぶ前提。
user_invocable: true
---

# reply-fix-to-review-comments

GitHub PR のレビューコメント（インライン）に対し、直前の会話で対応した commit を紐付けて「<sha> で修正しました」という Reply を一括投稿する。コード修正そのものは扱わず、修正・commit が済んだ状態から呼ぶ。

## 前提

- `gh` がインストール済みで `gh auth login` 済み。
- 対象は **review comments（コードに紐づくインラインコメント）のみ**。issue comments（PR 全体コメント）は対象外。
- コード修正・commit 作成・スレッドの resolve は本 Skill の対象外。
- 対応 commit は **直前の会話で扱われた commit のみ**を紐付け候補とする。会話に現れていない commit は探索しない。

## 動作フロー

1. **対象 PR を解決**し、PR URL と review comments の総件数を 1 行で提示する（暴発防止のため。Y/N 確認は取らない）。
2. `gh api repos/OWNER/REPO/pulls/NUMBER/comments --paginate` で全 review comments を取得し、`in_reply_to_id` を辿って **スレッド単位** に束ねる。
3. 各スレッドにつき、直前の会話文脈から対応 commit sha を推定する。
   - 一意に決まる → 「確定」
   - 候補なし → 「対象外」
   - 候補が複数あって絞れない → 「迷い」
4. `gh api user --jq .login` で自分のログインを取得し、各スレッドの自分の過去 Reply に「<sha> で修正しました」相当があるかをチェック。該当すれば「重複でスキップ」。
5. 「迷い」スレッドのみ、候補 sha と該当 `path:line` を提示してユーザーに確認する（投稿 / skip / sha 指定）。**確定スレッドは確認なしで進む**。
6. 確定したスレッドそれぞれの **起点コメント id**（`in_reply_to_id` が null のもの）に対して `gh api .../pulls/NUMBER/comments/COMMENT_ID/replies` で順次 POST する。失敗はサマリーに記録して次へ進む（リトライしない）。
7. 最終サマリーを出力する。

## 対象 PR の解決

優先順位：

1. 直前の会話に PR URL や PR 番号が出ている → そこから `OWNER/REPO/NUMBER` を取る。
2. 出ていなければ、現在のブランチに紐づく PR を `gh pr view --json url --jq .url` で取得する。
3. それも失敗した場合はユーザーに PR URL を尋ねる（**ディレクトリ名やパスから推測しない**）。

PR URL が `https://github.com/OWNER/REPO/pull/NUMBER` の形であれば、そこから `OWNER`・`REPO`・`NUMBER` を直接パースする。

## commit 紐付けの判定

- 紐付けの根拠は **直前の会話文脈** のみ（「この指摘を <sha> で直した」「<sha> でレビューコメント X に対応」など、会話で明示的に対応関係が示された commit）。
- 1 コメントに対し commit が複数ある場合（指摘を分割して対応したケース）も「確定」として 1 件の Reply にまとめる。
- 1 commit が複数コメントに対応する場合（同じ修正で複数指摘を解消したケース）は、各コメントに同じ Reply を投稿する。
- 以下のいずれかに該当する場合は **「迷い」** とみなしてユーザーに確認する：
  - 候補 commit が 2 つ以上で、どれが該当するか会話文脈から一意に決まらない
  - 「この指摘を A と B で対応した」のように分解されたかが文脈から不明
  - 候補 commit の変更ファイル/行が複数候補に重複していて切り分けられない

## 重複 Reply の判定

自分のログイン名と一致する過去 Reply のうち、以下を「<sha> で修正しました相当」とみなして対象スレッドを **スキップ** する：

- 7 桁以上の hex 文字列（短縮 sha or 完全 sha）を含み、かつ次の表現のいずれかと共起：
  - 「で修正しました」「で対応」「で直しました」
  - 「fixed in」「addressed in」
- 完全 sha と短縮 sha は同一視する。
- 上記の明示パターンに該当しなくても、**明らかに同じ sha への修正報告と読める** 場合はスキップして良い（自然言語判断）。

過去 Reply が議論コメント等で「<sha> で修正しました相当」でなければ、通常通り Reply 対象とする。

## Reply 本文のフォーマット

- 単一 commit: `<sha> で修正しました`
- 複数 commit: `<sha1>, <sha2> で修正しました`
  - 並び順は **時系列昇順**（古い順）
  - 区切りは半角カンマ＋スペース `, `
  - sha は **7 桁短縮 sha**

resolve 済みスレッドかどうかは区別しない（resolved にも投稿する）。

## gh CLI コマンドリファレンス

### 1. 対象 PR を解決
```bash
gh pr view --json url,number,headRefOid --jq '{url, number, head: .headRefOid}'
```

PR URL や番号が会話に出ていればそれを使う。出ていない時のみカレントブランチから解決する。

### 2. review comments を取得（全件）
```bash
gh api "repos/OWNER/REPO/pulls/NUMBER/comments" --paginate \
  --jq '.[] | {id, in_reply_to_id, user: .user.login, path, line, body, created_at}'
```

- `--paginate` 必須。大規模 PR で取りこぼさないため。
- `in_reply_to_id` が `null` のコメントが **スレッドの起点**。それ以外は同スレッドへの返信。

### 3. 自分のログイン名を取得
```bash
gh api user --jq .login
```

重複 Reply 判定で使う。

### 4. Reply を投稿
```bash
gh api "repos/OWNER/REPO/pulls/NUMBER/comments/COMMENT_ID/replies" \
  --method POST \
  -f body="<sha> で修正しました"
```

- `COMMENT_ID` は **スレッドの起点コメント id**（`in_reply_to_id` が null のもの）。中間の reply id は使わない。
- 本文中の `<sha>` は実際の短縮 sha に置き換える（例: `abc1234 で修正しました`）。

## 設計上の注意点

- **冪等性**: 同一スレッドに複数 sha が紐づく場合でも Reply は 1 件にまとめる。複数 Reply に分割しない。
- **resolved 情報は取得しない**: REST API では取得不可かつ要件上 resolve 区別なしのため、GraphQL での問い合わせは行わない。
- **PR 確認**: 対象 PR と件数を 1 行提示するのみで、Y/N 確認は取らない。確実な紐付けは確認なしで連続投稿する。
- **責務境界**: コード修正そのものは対象外。`fix-review-comments` 等で修正・commit 済みの状態から呼ぶこと。

## 最終サマリーの形式

実行後、以下のテンプレートでサマリーを出力する。各エントリには `path:line` と `comment_id` を必ず含めること（投稿の追跡可能性のため）。

```markdown
## Reply 投稿サマリー

対象 PR: <URL>

### 対応した（Reply 投稿済み）

#### <path>:<line> (comment_id=<id>)
- 指摘要旨: <冒頭 1〜2 行>
- 投稿 Reply: `<sha> で修正しました`

### ユーザー確認後に投稿

#### <path>:<line> (comment_id=<id>)
- 指摘要旨: ...
- 候補 sha: <sha1>, <sha2>
- ユーザー判断: <sha1> を採用
- 投稿 Reply: `<sha1> で修正しました`

### 重複でスキップ

#### <path>:<line> (comment_id=<id>)
- 既存 Reply: 「<sha> で修正しました」相当を検出（投稿者: <login>, <created_at>）

### 対象外（commit 未紐付け）

#### <path>:<line> (comment_id=<id>)
- 指摘要旨: ...
- 理由: 直前の会話に対応 commit が見当たらない

### ユーザー判断でスキップ

（あれば）

### エラー

（あれば: comment_id と stderr 抜粋）
```

該当エントリがないセクションは省略してよい。
