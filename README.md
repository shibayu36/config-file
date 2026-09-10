- ~/development/config-fileにclone
- ./installer.shを実行（HomebrewとBrewfileの内容、asdfのpluginを入れる）
- ./auto-config.shを実行

## Brewfile
- 新しいMacでも必ず入れたいものだけをBrewfileに書く。アドホックにbrew installしたものは書かなくてよい
- `brew bundle check --file=Brewfile --no-upgrade` で、Brewfileの項目が揃っているか確認できる（Brewfileにないものは無視される）
- `brew bundle cleanup --file=Brewfile --dry-run` で、Brewfileにないインストール済みのものを一覧できる。`--dry-run` なしで実行すると実際に削除されるので注意
- Brewfileに載せたcaskをbrewを介さず手動でインストール済みの場合、`brew install --cask --adopt <cask>` で既存アプリをbrew管理下に取り込める

## 外部スキルのインストール
- Node.jsとpnpmを用意し、./install-skills.shを実行する
- shibayu36のスキルは最新を取得し、それ以外はinstall-skills.sh内のコミットSHA-1で固定する。更新する際は対象のowner/repo#SHA-1の40桁のSHA-1を書き換える

## AI共通設定の配置
- AI共通設定はcodex/・claude/に置き、ホーム側の~/.codex/（CODEX_HOME指定時はそのディレクトリ）・~/.claude/から参照する
- リポジトリ直下の.codex/・.claude/はプロジェクト設定として自動検出されるため、共通設定の保管場所として再導入しない。hookや設定の重複読み込みを防ぐため、旧名の互換リンクも作らない
- ルートのAGENTS.md・CLAUDE.mdはリポジトリ固有の指示として残す
- claude/settings.local.json・claude/tmp/・codex/config.tomlなどのローカルデータはGit管理せず、グローバル設定にもマージしない

## Codexの設定
- 共通設定はcodex/config.base.tomlで管理する。~/.codex/config.tomlはCodexがローカル固有の値（[projects.*]やトークン）を書き込むためGit管理しない
- codex/config.base.tomlを変更したらsync-codex-configを実行すると、ローカル固有の値を残したまま~/.codex/config.tomlへ反映される（auto-config.shからも呼ばれる）
  - 書き換え時は~/.codex/config.toml全体を生成し直すため、手書きのコメントや並び順は失われる。直前の内容は~/.codex/config.toml.bakに残る
- sync-codex-config --dry-runで、書き込まずに変更されるキーを確認できる
- sync-codex-config --driftで、~/.codex/config.toml側だけで変えた共通設定と、共通設定に無いキー（[projects.*]、MCPのenv、CodexやChatGPTアプリが自動で書き換えるキーを除く。除外リストはbin/sync-codex-configのLOCAL_ONLY_PATHS。キー名のみで値は表示しない）を報告する。TUIの/modelなどで変えた設定を共通設定へ写し忘れていないかの確認用
