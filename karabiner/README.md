# karabiner

Karabiner-Elements の設定。

## karabiner.json にコメントを書かないこと

パーサ自体は `//` や `/* */` を受け付けるが（`karabiner_cli --lint-complex-modifications` で確認）、Karabiner-Elements は設定変更のたびに JSON を再シリアライズするため、GUI を触った時点でコメントが消える。ルールの背景はこのファイルに書く。

## ルールの背景

### IME・キー入力

- **control-英数の無効化 / control-かなの無効化** — Ctrl+英数、Ctrl+かなを握り潰す。
- **Change ¥ to Alt+¥ / Change Alt+¥ to ¥** — Ghostty 以外で ¥ キーとバックスラッシュを入れ替える。Ghostty では素の挙動のままにしたいので除外している。
- **In Ghostty, switch to Eisu before sending Ctrl-t** — Ghostty で Ctrl+T を送る前に英数キーを打つ。IME が日本語入力状態のままだとプレフィックスキーが期待通りに届かないため。

### アプリ起動

- **open Google Chrome by Option+c / Cursor by Option+v / Obsidian by Option+n / Finder by Option+a**

### Emacs 風キーバインドの補完

macOS 標準の Emacs 風バインド（Ctrl+N/P/B/F など）が効かないアプリで、矢印キーに読み替える。

- **Slack / Chrome / Spark / ChatGPT Atlas / Finder: Ctrl+N => Down Arrow, Ctrl+P => Up Arrow**
- **Cluster: Ctrl+H => Backspace**
- **ChatGPT: Ctrl+B => Left Arrow** — 下記参照。

### ChatGPT: Ctrl+B => Left Arrow

ChatGPT.app（bundle id は `com.openai.chat` ではなく **`com.openai.codex`**）では、チャット入力欄で Ctrl+B がサイドバーの開閉に奪われる。

このショートカットは**アプリの設定画面にもメニューバーにも存在しない**。`app.asar` を追ったところ、`toggleSidebar` 専用のハンドラが入力欄のエディタのローカルキーマップに直付けされており、Cmd と Ctrl のどちらでも発火する実装になっていた。OS のショートカット機構を通らないため、アプリ側から無効化する手段がない。

発火するのは入力欄にフォーカスがある時だけなので、アプリ全体で Ctrl+B を左矢印に置き換えても副作用はない（入力欄の外では元々 `moveBackward:` として左移動する）。

将来アプリの bundle id が変わるとルールが無言で効かなくなるので、効かなくなったらまずそこを疑う。

## その他

- **Command+1 to Command+F1** — Cmd+1 を Cmd+F1 に読み替える（全アプリ対象）。
