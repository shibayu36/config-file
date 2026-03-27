#!/bin/bash
set -euo pipefail

# Google DocsをMarkdownとしてエクスポートし、base64画像を抽出する

if [ $# -lt 2 ]; then
  echo "Usage: bash $0 GOOGLE_DOCS_URL_OR_ID OUTPUT_DIR" >&2
  exit 1
fi

INPUT="$1"
OUTPUT_DIR="$2"

# URLからDOC_IDを抽出。URLでなければそのままDOC_IDとして扱う
if echo "$INPUT" | grep -q '/document/d/'; then
  DOC_ID=$(echo "$INPUT" | grep -o '/document/d/[a-zA-Z0-9_-]*' | sed 's|/document/d/||')
else
  DOC_ID="$INPUT"
fi

# DOC_IDのバリデーション（JSONインジェクション防止）
if [[ ! "$DOC_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Error: DOC_IDに不正な文字が含まれています: $DOC_ID" >&2
  exit 1
fi

DOC_ID_SHORT="${DOC_ID:0:8}"
IMAGES_DIR="${OUTPUT_DIR}/images_${DOC_ID_SHORT}"
RAW_FILE="${OUTPUT_DIR}/gdoc_export_raw.md"
CLEAN_FILE="${OUTPUT_DIR}/gdoc_${DOC_ID_SHORT}.md"

# ディレクトリ作成
mkdir -p "$IMAGES_DIR"

# Markdownエクスポート
echo "Exporting document ${DOC_ID}..." >&2
PARAMS=$(jq -n --arg id "$DOC_ID" '{"fileId": $id, "mimeType": "text/markdown"}')
gws drive files export --params "$PARAMS" -o "$RAW_FILE" >&2

# 画像抽出（画像がない場合も正常終了するよう || true を付与）
grep '^\[image[0-9]*\]: <data:image/' "$RAW_FILE" | while IFS= read -r line; do
  NAME=$(echo "$line" | grep -o 'image[0-9]*' | head -1)
  # MIMEタイプから拡張子を決定（Googleは基本PNGに統一するが一応対応）
  MIME=$(echo "$line" | sed 's/.*data:image\///' | sed 's/;.*//')
  case "$MIME" in
    png)  EXT="png" ;;
    jpeg) EXT="jpg" ;;
    gif)  EXT="gif" ;;
    *)    EXT="$MIME" ;;
  esac
  # base64デコードして保存
  echo "$line" | sed 's/.*base64,//' | sed 's/>$//' | base64 -d > "${IMAGES_DIR}/${NAME}.${EXT}"
  echo "  Extracted: ${IMAGES_DIR}/${NAME}.${EXT}" >&2
done || true

# 画像参照行を置換してクリーンなMarkdownを生成
# まず画像行以外をコピーし、最後にローカルパス参照を追加（全行が画像行の場合も考慮）
grep -v '^\[image[0-9]*\]: <data:image/' "$RAW_FILE" > "$CLEAN_FILE" || true

# 抽出した画像のローカルパス参照を追記
IMAGE_COUNT=0
for img_file in "$IMAGES_DIR"/image*.*; do
  [ -f "$img_file" ] || continue
  BASENAME=$(basename "$img_file")
  NAME="${BASENAME%.*}"
  echo "[${NAME}]: images_${DOC_ID_SHORT}/${BASENAME}" >> "$CLEAN_FILE"
  IMAGE_COUNT=$((IMAGE_COUNT + 1))
done

# 一時ファイル削除
rm -f "$RAW_FILE"

# 結果サマリー
echo "---" >&2
echo "Markdown: ${CLEAN_FILE}" >&2
echo "Images: ${IMAGE_COUNT} files in ${IMAGES_DIR}/" >&2

# stdoutにはMarkdownファイルパスだけ出力（Claudeが受け取りやすいように）
echo "$CLEAN_FILE"
