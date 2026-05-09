---
name: git-rebase
description: git rebase を自然言語指示から非対話で実行する。commit 整理（squash / fixup / reword / drop / split / 順序入替）、upstream 取り込み、conflict 解消、stacked rebase（`--update-refs`）を扱う。「rebase して」「squash」「fixup」「reword」「split」「main 取り込んで」「conflict 解消」などのリクエストで使用。
user_invocable: true
---

# git-rebase

git rebase を自然言語の指示から非対話で実行する skill。commit 整理・fixup workflow・upstream 取込・conflict 解消支援を扱う。`rebase -i` の todo / commit message を Claude が事前生成して `GIT_SEQUENCE_EDITOR` / `GIT_EDITOR` を差し替える方式で完遂する。

対象は**ローカル branch の rebase**。push・コード修正・レビュー対応との chain は本 skill の責務外。

以下の特殊ケースでは、該当する references を読んでから手順を進める：

- **stacked branch 構成（ユーザー指示または会話文脈で stacked と分かっている時のみ）**：`references/stacked-update-refs.md`（`--update-refs` の付与・各 ref の push 判定・サマリー追記）

## 共通の動作フロー

1. **モード判定**：自然言語指示を解釈してモードを決定する（commit 整理 / fixup / upstream / reword / split / conflict 解消）。
2. **事前チェック**：以下を順に実施する。
   1. **進行中 rebase の検知**：`.git/rebase-merge` または `.git/rebase-apply` が存在すれば前回の rebase が中断したまま。ユーザーに `--continue / --abort / --skip` のどれにするか確認する。
   2. **detached HEAD の検知**：`git branch --show-current` で branch 名取得。出力が空なら detached HEAD と判定し、警告して続行確認。続行する場合は最終出力に `git branch <name>` のコマンドを添える。
   3. **dirty 判定**：`git status --porcelain` の出力で判定する。**ただしモード別に許容範囲が違う**：
      - commit 整理 / upstream 取込 / reword / split（過去 commit 対象）：dirty なら commit/stash を促して中止
      - fixup workflow / amend 系 / 最新 commit の split：差分そのものが入力なので dirty を許容（rebase 開始前に staging 状況を確認）
   4. **rebase 前 HEAD sha の保持**：`git rev-parse HEAD` で現在 sha を取得し、skill 内で保持する。成功・失敗どちらの最終出力にも含めて、`git reset --hard <sha>` で戻れるようにする。
3. **対象 sha の特定**：`git log` を見て対象 sha を確定する。曖昧なら「候補 sha が一意に決まらない時」へ。
4. **base の解決**：rebase 範囲の base を決める（モード別。単独 revision として渡す。`<sha>^` が root で死ぬ場合は `--root` に切替、後述）。
5. **merge commit の検知**（base 決定後）：`git log --merges <base>..HEAD` で rebase 範囲に merge commit があるかチェック。あれば次の文言（例）でユーザーに確認する：
   > merge commit があります。drop されて linear になりますが OK ですか / `--rebase-merges` で構造保持しますか？
   `--rebase-merges` を選んだ場合は **git が生成した todo（`label / reset / merge` 行を含む）をそのまま使う**（Claude は編集しない）。
6. **stacked 構成の判定**：以下のいずれかに該当する場合は stacked 構成として扱い、`references/stacked-update-refs.md` を読んで `--update-refs` 付与以降の手順に従う：
   - **ユーザーが明示指示した**：「stacked rebase」「下位 branch も追従させて」「`--update-refs` で」等
   - **直前の会話文脈で stacked branch 構成が前提と分かっている**：`feature-base → feature-A → feature-B` のような積み上げ運用が会話で言及されている等
   
   いずれにも該当しなければ通常 rebase で進む。
7. **push 済み判定**（後述「push 済みブランチの扱い」）。
8. **todo 案の提示**：rebase で組む todo（または等価な操作プラン）を 1 行ずつユーザーに提示する。
9. **rebase 前 HEAD sha の出力**：着手直前にユーザーに見える形で 1 行表示する。
10. **非対話で rebase を実行**：走った git コマンドは隠さずユーザーに見える形で実行する。
11. **結果サマリーの出力**（後述「最終サマリーの形式」）。

Y/N 確認を取るのは以下の時のみ：

- push 済みブランチへの rebase
- 候補 sha が一意に決まらない時
- merge commit が rebase 範囲に含まれる時
- conflict 発生時
- その他 destructive な分岐があると skill が判断した時

todo 案の表示は確認なしで提示してそのまま実行する。

## 単純ケースの最適化（rebase -i を使わない）

「最新 commit の HEAD 操作」で済むケースは `rebase -i` を回さずショートカットを使う。常に `rebase -i` を通すよりも速く・安全。

| ケース | コマンド |
|---|---|
| 最新 commit の reword | `git commit --amend -m "<新メッセージ>"` |
| 最新 commit に修正を追記（message 維持） | `git add ... && git commit --amend --no-edit` |
| 最新 commit の drop | `git reset --soft HEAD^`（内容を残す）or `git reset --hard HEAD^`（破棄） |
| 最新 commit を split | `git reset HEAD^` で unstaged に戻し、分割して再 commit |

これらでも事前チェック（進行中 rebase / detached HEAD / rebase 前 HEAD sha）は実施する。amend は HEAD の sha を変えるため、push 済み判定も別途実施。

## 非対話化の基本パターン

git は `GIT_SEQUENCE_EDITOR` / `GIT_EDITOR` の値を `/bin/sh -c "<EDITOR>" <EDITOR> <todofile>` の形でシェル経由起動し、編集対象ファイルパスを末尾引数として渡す。これを利用して事前に書いた一時ファイルで上書きする。

### 一時ファイルの作り方

todo / message 用の一時ファイルを作って対応する。ユーザーの一時ファイル配置方針があればそれに従う。

以降の例では作成済み一時ファイルのパスを `$TODO_FILE`（todo 用） / `$MSG_FILE`（commit message 用）というプレースホルダーで表す。

```bash
cat > "$TODO_FILE" <<'EOF'
pick abc1234 first commit subject
squash def5678 typo fix
squash ghi9012 minor refactor
EOF

GIT_SEQUENCE_EDITOR='sh -c '\''cp "'$TODO_FILE'" "$1"'\'' --' \
  git rebase -i <base>
```

- 動詞は `pick / reword / edit / squash / fixup / drop` のみ。**タイポを含む todo は git に拒否されて即 abort になる**ので、todo 生成時は厳密に書く。
- 動作原理：git が編集対象パスを末尾引数として追加し、`cp <一時ファイル> <git の todo パス>` 相当が走る。

### todo 差し替えと commit message 差し替えを併用する（squash で新メッセージを与える例）

```bash
# $TODO_FILE と $MSG_FILE に内容を書いた前提

GIT_SEQUENCE_EDITOR='sh -c '\''cp "'$TODO_FILE'" "$1"'\'' --' \
GIT_EDITOR='sh -c '\''cp "'$MSG_FILE'" "$1"'\'' --' \
  git rebase -i <base>
```

**squash 時の COMMIT_EDITMSG**：git は「複数 commit の連結 message」を事前に書く。`cp` で上書きすると **完全に置き換わる**。これを意識して使い分ける：

- 「メッセージは最初のを使って」 → `git log -1 --format=%B <first_sha>` で取得して `MSG_FILE` に書く
- 「git に任せて連結 message のままで」 → `GIT_EDITOR` 自体を渡さないか、`GIT_EDITOR=true` を使う
- 「両方の意図を残してまとめて」 → 各 commit の subject を残し、本文は重複を排して結合してから書く（命令形・体言止めなど元 message のスタイルに合わせる）

### message のみ差し替える（reword 単独で squash しない場合）

todo 側は触らず、message だけ差し替えればよい。

```bash
GIT_SEQUENCE_EDITOR=true \
GIT_EDITOR='sh -c '\''cp "'$MSG_FILE'" "$1"'\'' --' \
  git rebase -i <base>
```

ただし todo に対象 commit を `reword` として書きたい場合は todo 側も差し替える必要がある（その場合は前項の併用パターン）。

### autosquash の todo をそのまま採用

```bash
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash <base>
```

`true` は「何もせず exit 0」なので、git が autosquash で組んだ todo がそのまま使われる。

**注意**：base 直後の commit 以降は対象外でも rebase の対象として再適用される（empty commit drop / hook の発火など副作用が起きうる）。`<target_sha>^` を base にする方針で巻き込み範囲を最小化する。

### `<target_sha>^` が root commit で死ぬ問題

```bash
if git rev-parse --verify "${TARGET_SHA}^" >/dev/null 2>&1; then
  BASE_ARG="${TARGET_SHA}^"
else
  BASE_ARG="--root"
fi
```

`--root` を base にすると最初の commit から rebase できる。**base が必要な全モード（commit 整理 / fixup / reword / split）でこの判定を必ず挟む**。

### `git rebase --continue` 時の GIT_EDITOR 再付与（最重要落とし穴）

rebase は途中で停止（conflict / `edit` 動詞）すると環境変数が切れる。`--continue` を呼ぶ時は **再度 `GIT_EDITOR` を渡す**こと。

```bash
# 元 message を維持して続行
GIT_EDITOR=true git rebase --continue

# 新 message に書き換えて続行
GIT_EDITOR='sh -c '\''cp "'$MSG_FILE'" "$1"'\'' --' git rebase --continue
```

これを忘れると conflict 解消後にエディタが開いて skill が止まる。

## モード別の手順

### 1. commit 整理（squash / fixup / drop / 順序入替）

- 対象範囲を特定し、base を **単独 revision** として決める（範囲表記 `HEAD~3..HEAD` ではなく `HEAD~3` のような形）。`<最古対象 sha>^` を `BASE_ARG` ロジックに通す。
- todo 案をユーザーに 1 行ずつ提示し、「todo 差し替え」で実行する。
- squash で message 統合が必要なら「todo + message 差し替え併用」を使う。

### 2. fixup workflow

1. 対象 commit sha を特定する（`BASE_ARG` ロジックで `<target_sha>^` か `--root` を決める）。
2. **事前予告**：todo 自体は autosquash が git 内部で動的に組むので事前提示は不要。代わりに「`<target_sha>` (`<subject>`) に `<対象 path 一覧>` の差分を fixup します」を 1 行でユーザーに見せてから次に進む（共通フロー ステップ 7「todo 案の提示」のモード固有版）。
3. fixup 対象の差分を確認し、必要な path を `git add <paths>` で stage する（未 stage のままだと `git commit --fixup` が「nothing added」で失敗するため）。部分 staging を壊さないよう、対象 path をユーザーに確認してから add する。
4. `git commit --fixup=<target_sha>` で fixup commit を作る。
5. **commit 失敗時の挙動**：commit 作成が失敗した場合は **rebase に進まずその時点で停止**し、エラー出力をそのままユーザーに見せる。原因切り分けと対応は「作業の注意点 / commit 失敗の原因切り分け」を参照。
6. 成功したら `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash <BASE_ARG>` で実行する。

### 3. upstream 取り込み

- `git symbolic-ref --short refs/remotes/origin/HEAD` で base を解決する（`--short` 付きで `origin/main` のような短形を直接得る）。
- 失敗時 fallback：(a) ユーザーに base 名を確認 (b) `git remote set-head origin --auto` を提案して再試行。
- ユーザーが「develop に rebase して」「master 取り込んで」と明示した場合はそれを優先する。
- `git fetch origin` → `git rebase <resolved>`（`<resolved>` は既に `origin/main` のような短形なので、頭に `origin/` を重ねない）。
- conflict が起きたら「conflict 解消」へ。

### 4. reword

- ユーザーが新メッセージを明示指定 → 指定通り採用、確認なし。
- 指定がない（「いい感じに直して」「内容に合わせて」など）→ `git show <sha>` の diff から変更目的を 1 行で要約し、リポジトリの直近 commit message のスタイル（命令形 / 体言止め等）に揃えた案を提案、ユーザー承認後に適用する。
- 最新 commit のみが対象なら「単純ケースの最適化」の `git commit --amend` を使う。
- それ以外は todo で対象 commit を `reword` にし、「todo + message 差し替え併用」で実行する。

### 5. split

最新 commit のみが対象なら「単純ケースの最適化」のショートカット（`git reset HEAD^`）を使う。それ以外は以下の手順を踏む：

1. 対象 commit を `edit` に書いた todo を「todo 差し替え」で適用 → rebase が `edit` 行で停止する。
2. `git reset HEAD^` で対象 commit を unstaged に戻す。
3. **分割方針をユーザーに確認**する（ファイル単位 / hunk 単位 / ロジック vs テスト など）。指示が既にある場合は省略可。
4. 各分割について `git add <files>` → `git commit -m "<message>"` を繰り返す。message が必要で曖昧な場合は reword と同じ提案フローで案を作る。
5. `GIT_EDITOR=true git rebase --continue` で残りを再開する（GIT_EDITOR 再付与を忘れない）。

## conflict 解消

- **デフォルトは 1 ファイルずつ**：「両側の意図要約 → 解決案 diff → 承認 → 適用 → 次のファイル」を繰り返す。
- ユーザーが「まとめて」「一括で」「全部いい感じに」等を指示した時のみ、全 conflict の解決案 diff を一気に提示し 1 度の承認で全適用に切り替える。
- 解消ごとに `git add <file>` → 全部解消したら `GIT_EDITOR=true git rebase --continue`。
- ユーザーが abort を選んだら `git rebase --abort` を実行し、rebase 前 HEAD sha と reflog 案内を表示する。

## push 済みブランチの扱い

- `git rev-parse @{u}` で upstream sha を取得する（upstream が未設定なら push 済みではないとみなす）。
- **書き換え対象 sha のうち最古のもの**が `@{u}` の祖先かを `git merge-base --is-ancestor <oldest_rewritten_sha> @{u}` でチェックする。0 を返したら祖先（push 済みを書き換える）、1 を返したら祖先ではない（push 済みではない）。
- 「最古の書き換え対象 sha」はモード別に異なる：
  - commit 整理 / reword：`<base>..HEAD` の最古 commit
  - fixup workflow：`<target_sha>`
  - upstream 取込：通常 `<base>..HEAD` 全体（push 済み部分は普通含まれないが、再 push のケースでは含まれうる）
- 含まれる → 「push 済みなので force push が必要です。続行しますか？」を Y/N 確認する。
- 続行されたら rebase 実行、最終出力に `git push --force-with-lease` を添えて終了する。
- **skill 自身は push しない**。
- stacked 構成（共通フロー ステップ 6 で検知）の場合、各下位 ref ごとの push 判定が必要。`references/stacked-update-refs.md` の「push 済み判定（stacked 拡張）」を参照する。

## 候補 sha が一意に決まらない時

- 「auth まわり」「最近の」など曖昧な指示で候補が複数ある時、候補一覧（sha + subject）を提示してユーザーに選択を求める。
- 暗黙の決定（最も新しい候補を選ぶ等）はしない。

## 復旧（rebase 失敗・中断時）

- 最終出力には**事前チェックで保持した「rebase 前 HEAD sha」を必ず含める**（成功時も失敗時も）。
- 復旧コマンド：

  ```bash
  git rebase --abort                # rebase 進行中ならまずこれ
  git reset --hard <rebase 前 HEAD sha>  # それでも戻したい場合
  ```
- 最後の砦：`git reflog` で過去の HEAD を辿り、戻したい状態の sha を見つけて `git reset --hard <sha>`。

## 作業の注意点

- **destructive 操作はユーザー確認**：rebase は破壊的操作なので、Y/N 確認を取るタイミングは「共通の動作フロー」末尾のリストに集約。失敗時の `git rebase --abort` も自動実行せずユーザーに確認する（自動 abort で意図せず作業を破棄しない）。
- **commit 失敗の原因切り分け**：rebase 中・fixup workflow 中・amend 中の commit 作成失敗には複数の原因がある。skill は **どの原因でも勝手に回避せず、エラー出力と原因の見立てをユーザーに伝えて指示を仰ぐ**。
  - **pre-commit / commit-msg hook 失敗**：hook 起因。`--no-verify` を skill が勝手に付けない。「hook を直してリトライ」「`--no-verify` で進めて」のいずれかをユーザーが選ぶまで skill は何もしない。
  - **index / working tree 不整合**：未解決 conflict や index lock 等。状況を提示して、`git status` の確認をユーザーに促す。
  - rebase 前 HEAD sha は事前チェックで保持済みなので、いずれの場合も追加の `git reset` は不要（rebase 中なら `git rebase --abort` で着手前に戻せる）。
- **rebase 中の hook 挙動の注意**：git バージョン・バックエンド（apply / merge）によって hook の発火タイミングが違う。途中で hook が発火して止まった場合の continue/abort はユーザー判断。
- **empty commit**：`rebase -i` のデフォルトでは保持される（`pick` のまま）。drop したい場合はユーザーが明示する。
- **実行コマンドの可視化**：走った git コマンドは隠さずユーザーに見える形で実行する。

## 最終サマリーの形式

```markdown
## git-rebase 実行サマリー

### 実行内容
- モード: <commit整理 / fixup / upstream取込 / reword / split / conflict解消>
- 対象範囲: <下記「対象範囲の書式」参照>

### 結果
- rebase 前 HEAD sha: `<sha>` <subject>
- rebase 後 HEAD sha: `<sha>` <subject>
- 変わった commit 数: N

### 続けて必要な操作（あれば）
- push 済みだった場合: `git push --force-with-lease`
- レビュー Reply を続ける場合: rebase で sha が変わったため、新しい sha 基準で `reply-fix-to-review-comments` を呼んでください

### 復旧する場合
- `git reset --hard <rebase 前 HEAD sha>`
```

stacked 構成（共通フロー ステップ 6 で検知）の場合は、上のサマリーに「更新された下位 branch」「下位 ref ごとの force push」「復旧時の連動更新の注意」を追記する。詳細は `references/stacked-update-refs.md` の「最終サマリーへの追加項目」を参照。

### 「対象範囲」の書式

`git log --oneline <base>..HEAD` 相当の短縮 1 行リストを使う。具体例：

- **通常ケース**（base が単独 sha）：
  ```
  abc1234 first commit
  def5678 fix typo
  ghi9012 minor refactor
  ```
- **root ケース**（base が `--root`）：先頭に「(root)」と書き、対象 commit を全件並べる：
  ```
  (root) abc1234 initial commit
  def5678 follow-up
  ```
- **fixup workflow** の場合は target commit と fixup commit の組を 1 行で書く：
  ```
  fixup `<new_sha>` (`fixup! <target subject>`) → squashed into `<target_sha>` (`<target subject>`)
  ```

**複合ケース**（fixup × root, split × root など書式が複数該当する場合）は、**該当する書式を全て併記**する（優先順位はつけない）。読み手が「root 起点であった事実」と「どの commit に何を fixup したか」を両方すぐ取れるようにする。

失敗・中断時のサマリーには**「rebase 前 HEAD sha」と復旧コマンドを必ず含める**。
