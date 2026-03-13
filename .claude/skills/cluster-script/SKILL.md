---
name: cluster-script
description: >
  Cluster Script APIの型定義（index.d.ts）からAPIリファレンスを検索・取得する。
  「cluster scriptの〜メソッド」「〜のAPI」「ItemHandleの使い方」「PlayerHandleのメソッド」
  「〜のシグネチャ」「〜の引数」などのリクエストで使用。
  Bashでスクリプトを実行してAPI定義を検索し、JSDocコメント付きで提示する。
---

# Cluster Script API Search

Cluster Script APIの型定義ファイル（index.d.ts）からAPI情報を検索するスキル。

## 利用可能なスクリプト

スクリプトのパスは `${SKILL_DIR}/scripts/` 配下にある。

### search.py - API検索
```bash
python3 ${SKILL_DIR}/scripts/search.py "キーワード"
```
キーワードでAPI定義を検索し、マッチしたエントリ（JSDocコメント + シグネチャ）をテキスト形式で出力する。
最大30件まで。ファイルが未ダウンロードの場合は自動でダウンロードする。

### download.py - 型定義ファイルの更新
```bash
python3 ${SKILL_DIR}/scripts/download.py
```
最新のindex.d.tsをダウンロードして保存する。型定義を最新に更新したい場合に手動実行する。

## ワークフロー

1. ユーザーの質問からキーワードを抽出（日英両方、2〜3パターン）
2. `search.py` で各パターンを検索
3. 結果からJSDocとシグネチャを整理して提示

## キーワード最適化ルール

1. **メソッド名を直接検索**: setPosition, getRotation, send 等
2. **日本語でも検索**: 「位置」「回転」「移動」等（JSDocが日本語のため有効）
3. **interface/classで絞り込み**: ItemHandle, PlayerHandle, ClusterScript, Vector3 等のコンテキスト名も検索対象
4. **関連用語で横断検索**: 「アニメーション」「衝突」「マテリアル」等

## Creators Guideスキルとの使い分け

| 観点 | search-cluster-creators-guide | cluster-script |
|---|---|---|
| 対象 | Creators Guide記事（手順・解説） | Script API型定義（リファレンス） |
| 用途 | 「〜のやり方」「〜を設定する方法」 | 「〜メソッドの引数」「〜のAPI仕様」 |
