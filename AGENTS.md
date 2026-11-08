# config-file

macOSの開発環境のdotfiles・設定ファイルを一元管理するリポジトリ。

## 重要: ファイル編集のルール

設定ファイルを変更する際は、`~/` 以下のファイルを直接編集してはいけない。必ずこのリポジトリ内のファイルを編集すること。

`mise bootstrap`（`mise/config.toml` の `[dotfiles]` など）によって、このリポジトリ内のファイルから `~/` 以下へシンボリックリンクが貼られている。そのため、このリポジトリ内のファイルを編集すれば `~/` 側にも自動的に反映される。

## スクリプトの配置

`bin/` は他のリポジトリでも使う汎用コマンド用。このリポジトリ専用のスクリプトは `bin/` に置かず、`scripts/` に配置する。

## skillの配置

新しいskillは `skills/<名前>/` に作る。`mise bootstrap` で `~/.claude/skills` と `~/.agents/skills` にリンクされる。安定したskill（細かな修正が出なくなり、使って便利だと確認できたもの）は、`scripts/README.md` の手順で `shibayu36/agent-skills` に移す。

## git

commitとpushは、ユーザーに指示されたときだけ行う。変更を終えたら、commitせずに報告して指示を待つ。

commitを指示されたら、続けて `git push` まで行う。
