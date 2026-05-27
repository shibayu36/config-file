#!/usr/bin/env python3
"""Cluster Script APIの型定義ファイル(index.d.ts)をダウンロードして保存する"""

import argparse
import os
import sys
import urllib.error
import urllib.request

URL = "https://docs.cluster.mu/script/index.d.ts"
FILENAME = "cluster-script-index.d.ts"


def get_data_path():
    """スクリプトの位置から保存先パスを算出する (search.pyの自動DLキャッシュ用)"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # scripts/ -> cluster-script/ -> skills/ -> .claude/
    skill_dir = os.path.dirname(script_dir)
    skills_dir = os.path.dirname(skill_dir)
    claude_dir = os.path.dirname(skills_dir)
    return os.path.join(claude_dir, "tmp", FILENAME)


def download(dest_path):
    """index.d.tsをダウンロードして保存する"""
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)

    req = urllib.request.Request(URL, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            content = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        print(f"HTTP Error: {e.code} {e.reason}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"Connection Error: {e.reason}", file=sys.stderr)
        sys.exit(1)

    with open(dest_path, "w", encoding="utf-8") as f:
        f.write(content)

    line_count = content.count("\n")
    print(f"Downloaded to {dest_path} ({line_count} lines)", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Download Cluster Script API type definitions (index.d.ts)"
    )
    parser.add_argument(
        "--output-dir", default="", help="output directory (default: $PWD)"
    )
    args = parser.parse_args()

    out_dir = args.output_dir or os.getcwd()
    dest_path = os.path.join(out_dir, FILENAME)
    download(dest_path)


if __name__ == "__main__":
    main()
