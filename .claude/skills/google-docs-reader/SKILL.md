---
name: google-docs-reader
description: >
  Google DocsのURLからMarkdownを生成し、埋め込み画像をローカルファイルに抽出する。
  「Google Docsを読んで」「このドキュメント読み込んで」などのリクエストで使用。
  Bashでスクリプトを実行してMarkdownと画像ファイルを生成し、Readツールで読む。
---

# Google Docs Reader

Google DocsのURLを指定すると、軽量なMarkdownファイルと画像ファイルを生成する。

## 使い方

```bash
${SKILL_DIR}/scripts/read_gdoc.sh "GOOGLE_DOCS_URL_OR_DOC_ID" "OUTPUT_DIR"
```

- `GOOGLE_DOCS_URL_OR_DOC_ID` (必須): Google DocsのURL（例: `https://docs.google.com/document/d/DOC_ID/edit`）またはDOC_ID
- `OUTPUT_DIR` (必須): 出力先ディレクトリ（例: `tmp/`）

## ワークフロー

1. スクリプトを実行する
2. 出力されたMarkdownファイルのパスがstdoutに表示される
3. Readツールでそのパスを読む
4. 画像を確認したい場合は、`{OUTPUT_DIR}/images_{DOC_ID先頭8文字}/` 配下の画像ファイルをReadツールで読む（Claudeはマルチモーダルなので画像表示可能）

## 仕組み

1. `gws drive files export` で Google Docs を Markdown としてエクスポート
2. エクスポートされたMarkdownに含まれるbase64埋め込み画像を検出
3. base64デコードして `{OUTPUT_DIR}/images_{DOC_ID先頭8文字}/` にPNGファイルとして保存
4. Markdown内の画像参照をローカルファイルパスに置換
5. クリーンなMarkdownを `{OUTPUT_DIR}/` に出力

## 注意事項

- `gws` CLIの認証が必要（事前に設定済みであること）
- Google Docs API のエクスポートは10MB制限あり
- Googleはエクスポート時に画像をPNGに統一する（GIF/JPGをアップロードしてもPNGで返る）
