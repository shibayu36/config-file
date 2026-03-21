---
description: git-commit-message-generatorエージェントを利用して、commitメッセージを生成する
---

以下の手順でcommitを行ってください。

1. まず `git diff --cached --stat` でステージングされたファイルがあるか確認する
2. ステージングされたファイルがある場合 → そのままステージング済みファイルを対象にする
3. ステージングされたファイルがない場合 → 今の会話で変更したファイルを `git add` してステージングする
4. git-commit-message-generatorエージェントを利用して、commitメッセージを生成する
5. 生成したcommitメッセージをそのまま使って、git commit -m "生成したメッセージ" を実行する

なお、生成したcommitメッセージは、セッション中に共有してください。
