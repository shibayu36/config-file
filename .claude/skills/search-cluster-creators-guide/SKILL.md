---
name: search-cluster-creators-guide
description: >
  Cluster Creators Guide（creator.cluster.mu）からクリエイター向け情報を検索・調査する。
  「clusterの〜について調べて」「〜の使い方」「〜する方法」「〜を探して」などのリクエストで使用。
  Bashでスクリプトを実行してサイト検索・記事取得を行い、関連情報を抽出して提示する。
---

# Search Cluster Creators Guide

Cluster Creators Guideから情報を検索・調査するスキル。

## 利用可能なスクリプト

スクリプトのパスは `${SKILL_DIR}/scripts/` 配下にある。

### search.py - 記事検索
```bash
python3 ${SKILL_DIR}/scripts/search.py "キーワード"
```
キーワードで検索し、記事一覧をJSON形式で出力する（タイトル・URL・日付・カテゴリ・概要）。

### fetch_article.py - 記事本文取得
```bash
python3 ${SKILL_DIR}/scripts/fetch_article.py "記事URL"
```
記事URLから本文をMarkdown形式で出力する（見出し・段落・リスト・リンク・コードブロック）。

## ワークフロー

ユーザーの入力を分析し、検索モードか調査モードかを判定する。

### 検索モード
単純なキーワード、「〜を探して」「〜の記事」に該当する場合。

1. キーワードを2〜3パターン生成（後述の最適化ルール参照）
2. `search.py` で各パターンを検索
3. 結果一覧をタイトル・URL・日付・カテゴリ付きで表示

### 調査モード
「〜のやり方」「〜したい」「〜する方法」「〜について教えて」に該当する場合。

1. ユーザーの質問を検索キーワードに分解
2. `search.py` で検索
3. 関連性の高い記事を最大3件選定
4. `fetch_article.py` で各記事の本文を取得
5. 本文からユーザーの質問に関連する部分を抽出して提示
6. 参考記事のpermalinkを添える

## キーワード最適化ルール

1. **技術用語は日英両方で検索**: 「トリガー」「Trigger」
2. **cluster固有用語を活用**: ワールドクラフト、クラフトアイテム、CCK、Scriptable Item、Player Local UI等
3. **目的を機能名に変換**: 「音を鳴らしたい」→「オーディオ BGM」
4. **短いキーワードを優先**: WordPress全文検索は短い方がヒットしやすい
5. **AND検索を活用**: 複数の観点を組み合わせて絞り込む（スペース区切り）
