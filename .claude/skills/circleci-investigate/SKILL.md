---
name: circleci-investigate
description: >
  CircleCI上で動いたジョブ・ワークフロー・パイプラインを調査する。
  生stepログ（成功/失敗を問わない）、テスト結果、artifact一覧、リソース使用量、状態確認、
  ワークフロー内のジョブ一覧を、ジョブURL・パイプラインURL・ブランチ名+ジョブ名のいずれからでも取得できる。
  「CircleCIのログ見たい」「失敗したジョブの原因調べて」「circleci.com の URL を貼った」
  「CIのテスト結果」「artifactのDL URL」「ジョブのリソース使用量」などのリクエストで使用。
metadata:
  requires:
    bins: [python3]
---

# circleci-investigate

CircleCI のジョブ・ワークフロー・パイプラインを調査するための Skill。

## Out of scope

- 書き込み操作（rerun / cancel / approve / ロールバック実行）は扱わない
- 認証情報のセットアップ（事前に環境変数 `CIRCLECI_TOKEN` が export されている前提）
- config.yml の検証・編集、フレイキーテストの解析、実行中ジョブのリアルタイム表示

## Setup

CircleCI Personal API Token を発行し、`CIRCLECI_TOKEN` 環境変数として export する。

1. https://circleci.com/settings/user/tokens で Personal API Token を発行
2. `~/.zshrc` に `export CIRCLECI_TOKEN=...` を追記して新規シェルで有効化
   （既存 Claude Code セッションには反映されないので、有効化後に Claude Code を再起動）

## Usage

```bash
${SKILL_DIR}/scripts/circleci.py <subcommand> <input> [flags...]
```

### Input formats（全サブコマンド共通）

| 形式 | 例 |
|---|---|
| ジョブ URL | `https://app.circleci.com/pipelines/github/<org>/<project>/<pipeline_num>/workflows/<workflow_id>/jobs/<build_num>` |
| パイプライン URL | `https://app.circleci.com/pipelines/github/<org>/<project>/<pipeline_num>` |
| ブランチ + ジョブ名 | `--branch <name> --project <vcs_short>/<org>/<project> --job <job_name>` |

- ブランチ + ジョブ名形式では「そのブランチの最新パイプライン」「最初に該当ジョブ名を含む workflow」が自動選択される。選定理由（pipeline 番号 / workflow 名 / job_number）が stderr に `Resolved: ...` として出力される
- `<vcs_short>` は `gh`（GitHub）または `bb`（Bitbucket）。`github` / `bitbucket` も受理される
- `--project` の値（`gh/<org>/<project>`）は Claude が `git remote -v` などから補って渡すこと（Skill 内では推測しない）

### Subcommands

| subcommand | 出力 | 必要な input |
|---|---|---|
| `jobs`      | ワークフロー内ジョブ一覧 JSON をインライン出力 (status / started_at / stopped_at / job_number / name 等を含む)。パイプライン URL の場合は workflow ごとに集約。**単一ジョブの状態確認もこれで行う** | ジョブ URL / パイプライン URL / ブランチ+ジョブ名 |
| `pipelines` | ブランチ上の pipeline 一覧 (新しい順) を JSON でインライン出力。各 pipeline に `pipelineURL` と配下 workflow の生配列を含める。1ページのみ取得し、続きは `--page-token` で辿る。**用途**: 最新ではない過去 run を調査する / 同じブランチで並走している複数 pipeline から目的の pipelineURL を選ぶ。最新 run でいいなら他のサブコマンドが `--branch --project --job` で自動解決するのでこれは不要 | ブランチ+プロジェクト (URL 入力非対応) |
| `artifacts` | artifact 一覧 (path, url, node_index) をインライン出力 (next_page_token を辿って全件) | ジョブ URL or ブランチ+ジョブ名 |
| `steps`     | step メタ (resource_class / parallelism / 各 step・action の status / 所要時間) と 各 action の生 stdout/stderr をディレクトリ (`circleci-steps-...`) に保存し、絶対パスを stdout に出力。`--output-dir DIR` で保存先指定。**1 度の API コールで「リソース使用量の調査」と「ログの読解」の両方をカバー** (※ 実 CPU/メモリ使用率は CircleCI 公式 API では取得不可) | ジョブ URL or ブランチ+ジョブ名 |
| `tests`     | テスト結果全件 (next_page_token を辿る) を 1 ファイル (`circleci-tests-...json`) に保存し、絶対パスを stdout に出力。`--output-dir DIR` で保存先指定。フィルタは無し — 読み取り側で `jq` する | ジョブ URL or ブランチ+ジョブ名 |

### ファイル/ディレクトリ出力 (steps / tests)

#### 共通

- 保存先は `--output-dir` が無ければ `$PWD` 直下
- パーミッションは ファイル 0600 / ディレクトリ 0700 (CI ログには env 由来の secret が混じることがあるため)
- Claude が呼び出す場合は、ユーザーの CLAUDE.md ルール (例: プロジェクトの `tmp/`) に従って `--output-dir` を明示的に指定すること

#### `steps` の出力 (ディレクトリ)

- ディレクトリ名: `circleci-steps-<org>-<project>-<job_name>-<build_num>/`
  - 例: `circleci-steps-ClusterVR-ClusterONE-api_test-2661613/`
- **既存ディレクトリがあるとエラー終了**する (古い run と混ざらないようにするため)。再取得したいときは事前に削除する
- 構成:
  - `meta.json` — job 全体のメタ + `steps[].actions[]` 配列 (各 action に `log_path` で対応するログファイル名)
  - `step-NNN-<sanitized name>-<action_index>.log` — 1 action 1 ファイルの生ログ。parallelism > 1 のときは `-0`, `-1`, ... と分かれる
- 解析の典型フロー: まず `meta.json` を Read してどの step を見るか決める → 該当する `.log` だけ Read する (大きなジョブで巨大ログを全件 Read しなくて済む)
- jq 例:
  - 失敗 step 抽出: `jq '.steps[] | select(.actions[].status == "failed")' <dir>/meta.json`
  - 遅い step トップ 5: `jq '[.steps[] | {name, ms: ([.actions[].run_time_millis] | add)}] | sort_by(-.ms) | .[0:5]' <dir>/meta.json`
  - 失敗 action のログパス一覧: `jq -r '.steps[].actions[] | select(.status == "failed") | .log_path' <dir>/meta.json`

#### `tests` の出力 (ファイル)

- ファイル名: `circleci-tests-<org>-<project>-<job_name>-<build_num>.json`
  - 例: `circleci-tests-ClusterVR-ClusterONE-api_test-2661613.json`
- 保存後は `jq` で抽出する
  - 失敗テスト抽出例: `jq '.items[] | select(.result == "failure")' <path>`
  - 結果別カウント例: `jq '[.items[].result] | group_by(.) | map({result: .[0], count: length})' <path>`

## Examples

```bash
SKILL_DIR=/Users/shibayu36/.claude/skills/circleci-investigate

# 1. ジョブ URL から状態確認 (jobs の出力から該当ジョブを抽出)
"$SKILL_DIR/scripts/circleci.py" jobs \
  'https://app.circleci.com/pipelines/github/ClusterVR/ClusterONE/255552/workflows/b02f666d.../jobs/2661609' \
  | jq '.items[] | select(.job_number == 2661609)'

# 2. ジョブ URL から step メタ + 全 step の生ログを保存 → 失敗 step だけ抽出
DIR=$("$SKILL_DIR/scripts/circleci.py" steps \
  'https://app.circleci.com/pipelines/github/ClusterVR/ClusterONE/255552/workflows/b02f666d.../jobs/2661609' \
  --output-dir /Users/shibayu36/development/config-file/tmp)
jq '.steps[] | select(.actions[].status == "failed")' "$DIR/meta.json"

# 3. ブランチ + ジョブ名で最新 run の steps を保存 → 遅い step トップ 5
DIR=$("$SKILL_DIR/scripts/circleci.py" steps \
  --branch 'feature/server/shibayu36/linter-cache' \
  --project 'gh/ClusterVR/ClusterONE' \
  --job 'api_lint' \
  --output-dir ./tmp)
jq '[.steps[] | {name, ms: ([.actions[].run_time_millis] | add)}] | sort_by(-.ms) | .[0:5]' "$DIR/meta.json"

# 4. 失敗テスト一覧 (tests を保存 → jq で抽出)
TESTS_FILE=$("$SKILL_DIR/scripts/circleci.py" tests \
  --branch dev/server --project gh/ClusterVR/ClusterONE --job api_test \
  --output-dir ./tmp)
jq '.items[] | select(.result == "failure")' "$TESTS_FILE"

# 5. パイプライン URL から workflow ごとの全ジョブ一覧
"$SKILL_DIR/scripts/circleci.py" jobs \
  'https://app.circleci.com/pipelines/github/ClusterVR/ClusterONE/255552'

# 6. リソース使用量だけが知りたい場合も steps で取れる (meta.json に集約)
DIR=$("$SKILL_DIR/scripts/circleci.py" steps \
  'https://app.circleci.com/pipelines/github/ClusterVR/ClusterONE/255552/workflows/b02f666d.../jobs/2661609' \
  --output-dir ./tmp)
jq '{parallelism, executor, resource_class, build_time_millis}' "$DIR/meta.json"

# 7. ブランチの pipeline 一覧 (新しい順、各 pipeline に配下 workflow を含む)
"$SKILL_DIR/scripts/circleci.py" pipelines \
  --branch 'feature/server/shibayu36/linter-cache' \
  --project 'gh/ClusterVR/ClusterONE'

# 8. pipelines の出力から pipelineURL を取り出して jobs サブコマンドに繋ぐ
PIPELINE_URL=$("$SKILL_DIR/scripts/circleci.py" pipelines \
  --branch dev/server --project gh/ClusterVR/ClusterONE \
  | jq -r '.items[0].pipelineURL')
"$SKILL_DIR/scripts/circleci.py" jobs "$PIPELINE_URL"

# 9. pipelines の続きを取得 (next_page_token を渡す)
"$SKILL_DIR/scripts/circleci.py" pipelines \
  --branch dev/server --project gh/ClusterVR/ClusterONE \
  --page-token '<next_page_token>'
```

## トラブルシューティング

- `Error: CIRCLECI_TOKEN is not set ...` → Setup 手順を実施。Claude Code の再起動が必要
- `Error: CircleCI API v2 returned HTTP 404 ...` → 入力 URL のジョブ番号が違う、もしくはトークン保有者にアクセス権がない
- `Error: No pipeline found for branch '...' in <slug>` → ブランチ名のタイポ or プロジェクトが間違っている可能性
- `Error: Job '<name>' not found in any workflow of the latest pipeline ...` → ジョブ名のタイポ、または対象 run でそのジョブが skip された可能性
- `Error: URL input and --branch/--project/--job are mutually exclusive` → URL 指定とフラグ指定は併用不可
- `Error: Output directory already exists: ...` → `steps` の出力先ディレクトリが既存。古い snapshot を削除してから再実行

## 実装メモ

- API は v2 を基本に使うが、step ごとの stdout/stderr は v2 にエンドポイントが無いため legacy v1.1 を使う
- `output_url` は presigned S3 URL なので Circle-Token ヘッダ不要
- 認証トークンは `Circle-Token` ヘッダでのみ送り、エラーメッセージや stdout/stderr に含めない
