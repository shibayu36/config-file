---
name: reply-fix-to-review-comments
description: GitHub PR のレビューコメント（インライン）に対し、直前の会話で対応した commit を紐付けて「<commit URL> で修正しました」という Reply をまとめて投稿する。「レビュー Reply して」「レビューコメントに返信して」「修正報告投稿して」などのリクエストで使用。コード修正そのものは扱わず、修正・commit 済みの状態から呼ぶ前提。
user_invocable: true
---

# reply-fix-to-review-comments

GitHub PR のレビューコメント（インライン）に対し、直前の会話で対応した commit を紐付けて「<commit URL> で修正しました」という Reply を一括投稿する。コード修正そのものは扱わず、修正・commit が済んだ状態から呼ぶ。

## 前提

- `gh` がインストール済みで `gh auth login` 済み。
- 対象は **review comments（コードに紐づくインラインコメント）のみ**。issue comments（PR 全体コメント）は対象外。
- コード修正・commit 作成・スレッドの resolve は本 Skill の対象外。
- 対応 commit は **直前の会話で扱われた commit のみ**を紐付け候補とする。会話に現れていない commit は探索しない。

## 動作フロー

1. **対象 PR を解決**し、PR URL と review comments の総件数を 1 行で提示する（暴発防止のため。Y/N 確認は取らない）。
2. `gh api repos/OWNER/REPO/pulls/NUMBER/comments --paginate` で全 review comments を取得し、`in_reply_to_id` を辿って **スレッド単位** に束ねる。
3. `gh api user --jq .login` で自分のログイン名を取得する。
   - 起点コメントの作成者が自分、かつスレッド内の全コメントの作成者が自分のみのスレッドは「自分の補足コメント」として対象外にする（他者が 1 件でも返信していれば対象に含める）。詳細は「自分の補足スレッドの除外」を参照。
4. 残ったスレッドについて、直前の会話文脈から対応 commit sha を推定する。
   - 一意に決まる → 「確定」
   - 候補なし → 「対象外」
   - 候補が複数あって絞れない → 「迷い」
5. 各スレッドの自分の過去 Reply に修正報告（commit URL でも短縮 sha でも）が含まれていないかチェック。該当すれば「重複でスキップ」。
6. 「迷い」スレッドのみ、候補 sha と該当 `path:line` を提示してユーザーに確認する（投稿 / skip / sha 指定）。**確定スレッドは確認なしで進む**。
7. 確定したスレッドそれぞれの **起点コメント id**（`in_reply_to_id` が null のもの）に対して `gh api .../pulls/NUMBER/comments/COMMENT_ID/replies` で順次 POST する。失敗はサマリーに記録して次へ進む（リトライしない）。
8. 最終サマリーを出力する。

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

## 自分の補足スレッドの除外

スレッド単位で次の両方を満たす場合、「自分の補足コメント」として対象外にする:

- 起点コメント（`in_reply_to_id` が null）の作成者が `gh api user --jq .login` と一致。
- スレッド内の全コメント（起点 + 返信）の作成者が自分のみ。

他者が 1 件でも返信していれば通常通り Reply 対象に含める（議論に commit 報告で答える価値があるため）。

判定タイミングは commit 紐付け判定の前。

## 重複 Reply の判定

自分のログイン名と一致する過去 Reply に修正報告が含まれているスレッドを **スキップ** する。

該当する Reply 例:

- `https://github.com/OWNER/REPO/commit/abc1234 で修正しました`（skill 自身の形式）
- `abc1234 で修正しました` / `abc1234 で対応` / `abc1234 で直しました`
- `fixed in abc1234` / `addressed in abc1234`

判定基準: hex 文字列（URL 内・単体問わず、短縮 sha・完全 sha も同一視）と上記キーワードの共起。明示パターンに該当しなくても、明らかに同じ sha への修正報告と読めるならスキップしてよい（自然言語判断）。

議論コメント等で修正報告でなければ、通常通り Reply 対象とする。

## Reply 本文のフォーマット

- 単一 commit: `https://github.com/OWNER/REPO/commit/<sha> で修正しました`
- 複数 commit: `https://github.com/OWNER/REPO/commit/<sha1>, https://github.com/OWNER/REPO/commit/<sha2> で修正しました`
  - 並び順は **時系列昇順**（古い順）
  - 区切りは半角カンマ＋スペース `, `
  - sha の桁数は問わない（短縮 sha でも完全 sha でも可）。GitHub renderer が URL を短縮 sha 表示に自動で折り畳むため、見た目は揃う。
  - URL 形式にする理由: GitHub の自動 sha リンク化はレンダリングキャッシュや push 到達タイミングによってリンクされない場合があるため、明示的な commit URL で確実にリンクさせる。

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
  -f body="https://github.com/OWNER/REPO/commit/<sha> で修正しました"
```

- `COMMENT_ID` は **スレッドの起点コメント id**（`in_reply_to_id` が null のもの）。中間の reply id は使わない。
- 本文中の `<sha>` は実際の sha（短縮/完全どちらも可）に置き換える（例: `https://github.com/OWNER/REPO/commit/abc1234 で修正しました`）。

## 設計上の注意点

- **冪等性**: 同一スレッドに複数 sha が紐づく場合でも Reply は 1 件にまとめる。複数 Reply に分割しない。
- **resolved 情報は取得しない**: REST API では取得不可かつ要件上 resolve 区別なしのため、GraphQL での問い合わせは行わない。
- **PR 確認**: 対象 PR と件数を 1 行提示するのみで、Y/N 確認は取らない。確実な紐付けは確認なしで連続投稿する。
- **責務境界**: コード修正そのものは対象外。`fix-review-comments` 等で修正・commit 済みの状態から呼ぶこと。

## 最終サマリーの形式

実行後、以下の 2 セクションだけを箇条書きで出力する。重複でスキップ・自分の補足コメント等の判定済み項目はサマリーに出さない（必要なら実行ログで個別に確認すれば足りる）。

```markdown
## Reply 投稿サマリー

### 対応したもの

指摘の要旨と対応 commit のメッセージを並べる（ダブルチェック用）。

- 指摘: <冒頭 1〜2 行>
  - `<sha>` <commit subject>
  - （複数 commit ある場合は追加で並べる）

### 迷ったけど対応を見送ったもの

- `<path>:<line>`: <理由（候補なし／候補が絞れず skip／投稿失敗 など）>
```

該当エントリがないセクションは省略してよい。
