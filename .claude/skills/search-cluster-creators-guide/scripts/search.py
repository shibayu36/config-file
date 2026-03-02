#!/usr/bin/env python3
"""Cluster Creators Guide の検索結果ページをパースして記事一覧をJSON出力する"""

import json
import sys
import urllib.error
import urllib.request
import urllib.parse
from html.parser import HTMLParser


class SearchResultParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.articles = []
        self._current = None
        self._in_article = False
        self._in_entry_title = False
        self._in_time = False
        self._in_cat_name = False
        # <div class="description"> の中の <p> のテキストだけを取得するため2段階のフラグが必要
        self._in_description = False
        self._in_description_p = False

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        classes = attrs_dict.get("class") or ""

        if tag == "article" and "post-list" in classes:
            self._in_article = True
            self._current = {"title": "", "url": "", "date": "", "category": "", "description": ""}

        if not self._in_article or self._current is None:
            return

        if tag == "a" and "post-list__link" in classes:
            self._current["url"] = attrs_dict.get("href", "")

        if tag == "h1" and "entry-title" in classes:
            self._in_entry_title = True

        if tag == "time" and "time__date" in classes:
            self._in_time = True

        if tag == "span" and "osusume-label" in classes and "cat-name" in classes:
            self._in_cat_name = True

        if tag == "div" and "description" in classes:
            self._in_description = True

        if self._in_description and tag == "p":
            self._in_description_p = True

    def handle_endtag(self, tag):
        if tag == "article" and self._in_article:
            if self._current and self._current["title"]:
                self.articles.append(self._current)
            self._current = None
            self._in_article = False

        if tag == "h1":
            self._in_entry_title = False
        if tag == "time":
            self._in_time = False
        if tag == "span":
            self._in_cat_name = False
        if tag == "div":
            self._in_description = False
        if tag == "p" and self._in_description_p:
            self._in_description_p = False

    def handle_data(self, data):
        if self._current is None:
            return

        text = data.strip()
        if not text:
            return

        if self._in_entry_title:
            self._current["title"] += text
        elif self._in_time:
            self._current["date"] = text
        elif self._in_cat_name:
            self._current["category"] = text
        elif self._in_description_p:
            self._current["description"] += text


def search(keyword):
    url = f"https://creator.cluster.mu/?s={urllib.parse.quote(keyword)}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            html = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        print(f"HTTP Error: {e.code} {e.reason}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"Connection Error: {e.reason}", file=sys.stderr)
        sys.exit(1)

    parser = SearchResultParser()
    parser.feed(html)
    return parser.articles


def main():
    if len(sys.argv) < 2:
        print("Usage: search.py <keyword>", file=sys.stderr)
        sys.exit(1)

    keyword = sys.argv[1]
    results = search(keyword)
    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
