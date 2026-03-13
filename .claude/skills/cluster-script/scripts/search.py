#!/usr/bin/env python3
"""Cluster Script APIの型定義ファイルからJSDocエントリ単位でキーワード検索する"""

import os
import re
import sys

from download import download, get_data_path

MAX_RESULTS = 30


def ensure_file(path):
    """ファイルが存在しなければダウンロードする"""
    if os.path.exists(path):
        return
    print("index.d.ts not found. Downloading...", file=sys.stderr)
    download(path)


# トップレベル宣言の開始を検出する正規表現
CONTEXT_START_RE = re.compile(
    r"^(interface|declare\s+class|declare\s+enum)\s+(\w+)"
)


def parse_entries(lines):
    """index.d.tsの行リストからJSDocエントリを抽出する"""
    entries = []
    context = None  # 現在のinterface/class/enum名
    jsdoc_lines = []
    jsdoc_start_line = 0
    in_jsdoc = False
    sig_lines = []

    for i, line in enumerate(lines):
        line_num = i + 1
        stripped = line.rstrip()

        # トップレベルのコンテキスト追跡（インデントなし）
        if not line.startswith(" "):
            m = CONTEXT_START_RE.match(stripped)
            if m:
                # 直前にバッファリングしたJSDocがあればトップレベルエントリとして保存
                if jsdoc_lines:
                    _flush_entry(entries, context, jsdoc_lines, sig_lines, jsdoc_start_line)
                    jsdoc_lines = []
                    sig_lines = []
                    in_jsdoc = False
                context = m.group(2)
                continue
            if stripped == "}":
                # コンテキスト終了前にバッファ中のエントリをフラッシュ
                if jsdoc_lines:
                    _flush_entry(entries, context, jsdoc_lines, sig_lines, jsdoc_start_line)
                    jsdoc_lines = []
                    sig_lines = []
                    in_jsdoc = False
                context = None
                continue

        # JSDocブロックの検出（////...のようなコメント区切り行を除外）
        if "/**" in stripped and not stripped.lstrip().startswith("////"):
            # 前のバッファが残っていればフラッシュ
            if jsdoc_lines:
                _flush_entry(entries, context, jsdoc_lines, sig_lines, jsdoc_start_line)
                sig_lines = []

            jsdoc_lines = [stripped]
            jsdoc_start_line = line_num
            # 1行JSDoc: /** ... */
            if "*/" in stripped and stripped.index("*/") > stripped.index("/**"):
                in_jsdoc = False
            else:
                in_jsdoc = True
            continue

        if in_jsdoc:
            jsdoc_lines.append(stripped)
            if "*/" in stripped:
                in_jsdoc = False
            continue

        # JSDoc直後のシグネチャ行
        if jsdoc_lines and not in_jsdoc:
            if stripped and not stripped.startswith("/**"):
                sig_lines.append(stripped)
                # 次の空行/JSDoc開始/}が来るまでシグネチャ行として継続
                continue
            else:
                # 空行やJSDocの開始 → エントリをフラッシュ
                _flush_entry(entries, context, jsdoc_lines, sig_lines, jsdoc_start_line)
                jsdoc_lines = []
                sig_lines = []
                # 新しいJSDocの開始かチェック
                if "/**" in stripped:
                    jsdoc_lines = [stripped]
                    jsdoc_start_line = line_num
                    if "*/" in stripped and stripped.index("*/") > stripped.index("/**"):
                        in_jsdoc = False
                    else:
                        in_jsdoc = True
                continue

    # 末尾の残り
    if jsdoc_lines:
        _flush_entry(entries, context, jsdoc_lines, sig_lines, jsdoc_start_line)

    return entries


def _flush_entry(entries, context, jsdoc_lines, sig_lines, start_line):
    """バッファからエントリを生成してリストに追加する"""
    if not jsdoc_lines:
        return
    jsdoc_text = "\n".join(jsdoc_lines)
    sig_text = "\n".join(sig_lines)
    full_text = jsdoc_text + "\n" + sig_text if sig_text else jsdoc_text

    entries.append({
        "context": context,
        "jsdoc": jsdoc_text,
        "signature": sig_text,
        "full_text": full_text,
        "line": start_line,
    })


def search_entries(entries, keyword):
    """エントリリストからキーワードにマッチするものを返す"""
    keyword_lower = keyword.lower()
    results = []
    for entry in entries:
        search_target = entry["full_text"].lower()
        if entry["context"]:
            search_target += " " + entry["context"].lower()
        if keyword_lower in search_target:
            results.append(entry)
    return results[:MAX_RESULTS]


def format_results(results, keyword):
    """検索結果をテキスト形式で出力する"""
    if not results:
        return f"No results found for '{keyword}'"

    parts = []
    for entry in results:
        ctx = entry["context"] or "(top-level)"
        header = f"--- {ctx} (line {entry['line']}) ---"
        body = entry["full_text"]
        parts.append(f"{header}\n{body}")

    count_msg = f"Found {len(results)} result(s) for '{keyword}'"
    if len(results) == MAX_RESULTS:
        count_msg += f" (showing first {MAX_RESULTS}, try a more specific keyword)"
    return count_msg + "\n\n" + "\n\n".join(parts)


def main():
    if len(sys.argv) < 2:
        print("Usage: search.py <keyword>", file=sys.stderr)
        sys.exit(1)

    keyword = sys.argv[1]
    data_path = get_data_path()
    ensure_file(data_path)

    with open(data_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    entries = parse_entries(lines)
    results = search_entries(entries, keyword)
    print(format_results(results, keyword))


if __name__ == "__main__":
    main()
