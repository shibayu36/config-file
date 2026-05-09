# stacked branch と `--update-refs`

stacked branch 構成（同じ commit chain に複数の branch がぶら下がる：`main → feature-base → feature-A → feature-B(HEAD)`）で rebase した時に、`--update-refs` で下位 ref を自動追従させる手順をまとめる。**ユーザーが明示指示した場合、または直前の会話文脈で stacked と分かっている場合にロードする**（自動検知はしない）。

## 目次

- 対象 ref（`STACKED_REFS`）の確定
- `--update-refs` の付与
- 確認時のユーザー提示
- push 済み判定（stacked 拡張）
- 最終サマリーへの追加項目

## 対象 ref（`STACKED_REFS`）の確定

以後の手順は変数 `STACKED_REFS`（追従更新する下位 branch ref のスペース区切りリスト）を前提にする。確定方法：

- **ユーザーが対象 ref を明示指定した場合**：そのまま使う（例：「`feature-A` と `feature-base` も追従させて」→ `STACKED_REFS="feature-A feature-base"`）
- **明示指定がない場合**：候補 ref をユーザーに提示して選んでもらう
  ```bash
  # 自分以外の branch 一覧（候補）
  git for-each-ref --format='%(refname:short)' refs/heads/ \
    | grep -vx "$(git branch --show-current)"
  ```
  会話文脈で stacked と分かっていても、対象 ref まで一意に絞れない場合は必ず確認する（暗黙の決定はしない）。

## `--update-refs` の付与

```bash
REBASE_OPTS="--update-refs"

GIT_SEQUENCE_EDITOR="..." git rebase -i $REBASE_OPTS <base>
```

`rebase.updateRefs=true` を設定済みのユーザーには冗長だが、二重指定によるエラーは出ない（無害）。

## 実行前のユーザー提示（Y/N 確認は取らない）

```
以下の下位 branch を --update-refs で追従更新します:
  - feature-base
  - feature-A
```

## push 済み判定（stacked 拡張）

SKILL.md の「push 済みブランチの扱い」は HEAD の branch だけを判定するが、stacked 時は **`--update-refs` で更新される各 branch ref ごと**に push 済み判定を行う：

```bash
for ref in $STACKED_REFS; do
  upstream=$(git rev-parse --symbolic-full-name "${ref}@{u}" 2>/dev/null) || continue
  # その branch が push 済み（upstream が存在）なら rebase 後に force push が必要
  echo "$ref: needs force push (upstream: $upstream)"
done
```

- HEAD の branch とは別に、各下位 branch も push 済みかをチェックする。
- 1 つでも push 済みがあれば「下位 branch も含めて force push が必要です」とユーザーに告げる（HEAD の Y/N 確認に集約してよい。下位ごとの Y/N は取らない）。
- 続行されたら、最終出力に **更新された全 ref それぞれの force push コマンド**を列挙する：

  ```bash
  git push --force-with-lease origin feature-B   # HEAD
  git push --force-with-lease origin feature-A
  git push --force-with-lease origin feature-base
  ```

## 最終サマリーへの追加項目

通常のサマリー（SKILL.md「最終サマリーの形式」参照）に加えて、以下を追記する：

- **結果**ブロック：「更新された下位 branch: feature-A, feature-base」を追加
- **次のアクション**ブロック：stacked 用の force push コマンド一覧を追加（上記の bash ブロックの形式）

ユーザーが「戻して」等を要求した時は、stacked の下位 branch は `--update-refs` で連動更新されているため、HEAD を戻しても下位 ref は自動では戻らない。下位 ref も巻き戻すかユーザーに確認する（skill 側で自動巻き戻しはしない）。
