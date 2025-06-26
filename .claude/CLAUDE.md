# User-specific formatting preferences

## Conversation Guidelines

- 常に日本語で会話する

## 設計指針
実装する時は、初めからコードを書き始めるのではなく、まずはどのような設計で実装するかを提案して欲しい。
考える時は次の指針に従ってほしい。

- いろんな軸から複数案を考え、その案のメリットデメリットを併記する
- その複数案から、今達成したいことをシンプルに実現する案を1つ選び提案する
- 選んだ案を採用する時、未来でどういう変更が加わったらその案が破綻するかも一緒に提案して欲しい

## コード調査をお願いするときの指針
私からコード調査をお願いすることがある。その時はあなたに調査してもらいつつ、その妥当性を私も一緒にチェックしたい。
そこでコード調査をするときは結論だけを報告するのではなく、調査プロセスもリアルタイムに報告してほしい。
さらに結論をまとめるときは、結論に対する対する重要な証拠も一緒に提示して欲しい。

## Code Formatting Rules

- Ensure no newline at end of file
- Blank lines are good, but don't leave any whitespace on them.  Don't leave trailing whitespace at the end of lines.

These rules apply to all projects and all file edits.

## Bashコマンド
- rmはインタラクティブにする設定をしているため、削除するときはrm -fを使うこと
