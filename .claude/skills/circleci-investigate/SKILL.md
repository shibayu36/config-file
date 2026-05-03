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
| `status`    | ジョブ状態 JSON をインライン出力 | ジョブ URL or ブランチ+ジョブ名 |
| `jobs`      | ワークフロー内ジョブ一覧 JSON をインライン出力。パイプライン URL の場合は workflow ごとに集約 | ジョブ URL / パイプライン URL / ブランチ+ジョブ名 |
| `artifacts` | artifact 一覧 (path, url, node_index) をインライン出力 (next_page_token を辿って全件) | ジョブ URL or ブランチ+ジョブ名 |
| `usage`     | 割り当て resource_class / parallelism / step ごとの所要時間をインライン出力 (※ 実 CPU/メモリ使用率は CircleCI の公式 API では取得不可) | ジョブ URL or ブランチ+ジョブ名 |
| `steplog`   | 全 step の生 stdout/stderr を 1 ファイル (`circleci-steplog-...log`) に保存し、絶対パスを stdout に出力。`--output-dir DIR` で保存先指定 | ジョブ URL or ブランチ+ジョブ名 |
| `tests`     | テスト結果全件 (next_page_token を辿る) を 1 ファイル (`circleci-tests-...json`) に保存し、絶対パスを stdout に出力。`--output-dir DIR` で保存先指定。フィルタは無し — 読み取り側で `jq` する | ジョブ URL or ブランチ+ジョブ名 |

### ファイル出力 (steplog / tests)

- ファイル名: `circleci-<subcmd>-<org>-<project>-<job_name>-<build_num>.<ext>`
  - 例: `circleci-steplog-ClusterVR-ClusterONE-api_lint-2661609.log`
  - 例: `circleci-tests-ClusterVR-ClusterONE-api_test-2661613.json`
- 保存先は `--output-dir` が無ければ `$PWD` 直下
- パーミッションは 0600 (CI ログには env 由来の secret が混じることがあるため)
- Claude が呼び出す場合は、ユーザーの CLAUDE.md ルール (例: プロジェクトの `tmp/`) に従って `--output-dir` を明示的に指定すること
- 保存後は Read tool / `jq` でファイルを読んで分析する
  - 失敗テスト抽出例: `jq '.items[] | select(.result == "failure")' <path>`
  - 結果別カウント例: `jq '[.items[].result] | group_by(.) | map({result: .[0], count: length})' <path>`

## Examples

```bash
SKILL_DIR=/Users/shibayu36/.claude/skills/circleci-investigate

# 1. ジョブ URL から状態確認
"$SKILL_DIR/scripts/circleci.py" status \
  'https://app.circleci.com/pipelines/github/ClusterVR/ClusterONE/255552/workflows/b02f666d.../jobs/2661609'

# 2. ジョブ URL から step ログを保存
"$SKILL_DIR/scripts/circleci.py" steplog \
  'https://app.circleci.com/pipelines/github/ClusterVR/ClusterONE/255552/workflows/b02f666d.../jobs/2661609' \
  --output-dir /Users/shibayu36/development/config-file/tmp

# 3. ブランチ + ジョブ名で最新 run の step ログを保存
"$SKILL_DIR/scripts/circleci.py" steplog \
  --branch 'feature/server/shibayu36/linter-cache' \
  --project 'gh/ClusterVR/ClusterONE' \
  --job 'api_lint' \
  --output-dir ./tmp

# 4. 失敗テスト一覧 (tests を保存 → jq で抽出)
TESTS_FILE=$("$SKILL_DIR/scripts/circleci.py" tests \
  --branch dev/server --project gh/ClusterVR/ClusterONE --job api_test \
  --output-dir ./tmp)
jq '.items[] | select(.result == "failure")' "$TESTS_FILE"

# 5. パイプライン URL から workflow ごとの全ジョブ一覧
"$SKILL_DIR/scripts/circleci.py" jobs \
  'https://app.circleci.com/pipelines/github/ClusterVR/ClusterONE/255552'

# 6. リソース使用量
"$SKILL_DIR/scripts/circleci.py" usage \
  'https://app.circleci.com/pipelines/github/ClusterVR/ClusterONE/255552/workflows/b02f666d.../jobs/2661609'
```

## トラブルシューティング

- `Error: CIRCLECI_TOKEN is not set ...` → Setup 手順を実施。Claude Code の再起動が必要
- `Error: CircleCI API v2 returned HTTP 404 ...` → 入力 URL のジョブ番号が違う、もしくはトークン保有者にアクセス権がない
- `Error: No pipeline found for branch '...' in <slug>` → ブランチ名のタイポ or プロジェクトが間違っている可能性
- `Error: Job '<name>' not found in any workflow of the latest pipeline ...` → ジョブ名のタイポ、または対象 run でそのジョブが skip された可能性
- `Error: URL input and --branch/--project/--job are mutually exclusive` → URL 指定とフラグ指定は併用不可

## 実装メモ

- API は v2 を基本に使うが、step ごとの stdout/stderr は v2 にエンドポイントが無いため legacy v1.1 を使う
- `output_url` は presigned S3 URL なので Circle-Token ヘッダ不要
- 認証トークンは `Circle-Token` ヘッダでのみ送り、エラーメッセージや stdout/stderr に含めない
