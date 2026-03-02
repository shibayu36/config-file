#!/usr/bin/env python3
"""Cluster Creators Guide の記事ページをパースしてMarkdown形式でテキスト出力する"""

import sys
import urllib.error
import urllib.request
from html.parser import HTMLParser


class ArticleParser(HTMLParser):
    def __init__(self):
        super().__init__()
        # 出力データ
        self.title = ""
        self.date = ""
        self.category = ""
        self.sections = []

        # パーサー内部状態
        self._in_header = False
        self._in_entry_content = False
        self._in_title = False
        self._in_date = False
        self._in_cat_name = False
        self._current_tag = None
        self._current_text = ""
        self._skip_toc = False
        self._toc_depth = 0
        self._in_link = False
        self._link_href = ""
        self._link_text = ""
        self._in_pre = False
        self._pre_text = ""
        self._pre_lang = ""

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        classes = attrs_dict.get("class") or ""

        if tag == "header" and "article-header" in classes:
            self._in_header = True
            return

        if tag == "h1" and "entry-title" in classes:
            self._in_title = True
            return

        if tag == "time" and "entry-date" in classes:
            self._in_date = True
            return

        # カテゴリはheader内の最初のもののみ取得
        if tag == "span" and "cat-name" in classes and self._in_header and not self.category:
            self._in_cat_name = True
            return

        # 目次をスキップ
        if attrs_dict.get("id") == "ez-toc-container":
            self._skip_toc = True
            self._toc_depth = 1
            return

        if self._skip_toc:
            self._toc_depth += 1
            return

        if tag == "section" and "entry-content" in classes:
            self._in_entry_content = True
            return

        if not self._in_entry_content:
            return

        # <pre>内のタグはすべて無視（テキストのみ収集）
        if self._in_pre:
            return

        if tag == "pre":
            self._flush_text()
            self._in_pre = True
            self._pre_text = ""
            self._pre_lang = attrs_dict.get("data-lang") or ""
            return

        if tag in ("h2", "h3", "h4"):
            self._flush_text()
            self._current_tag = tag

        if tag == "p":
            self._flush_text()
            self._current_tag = "p"

        if tag == "li":
            self._flush_text()
            self._current_tag = "li"

        if tag == "img":
            alt = attrs_dict.get("alt", "")
            if alt:
                self.sections.append(f"[画像: {alt}]")

        if tag == "a" and self._current_tag:
            self._in_link = True
            self._link_href = attrs_dict.get("href", "")
            self._link_text = ""

        if tag == "br":
            self._current_text += "\n"

    def handle_endtag(self, tag):
        if tag == "header" and self._in_header:
            self._in_header = False
            return

        if tag == "h1" and self._in_title:
            self._in_title = False
            return

        if tag == "time" and self._in_date:
            self._in_date = False
            return

        if tag == "span" and self._in_cat_name:
            self._in_cat_name = False
            return

        if self._skip_toc:
            self._toc_depth -= 1
            if self._toc_depth <= 0:
                self._skip_toc = False
            return

        if tag == "section" and self._in_entry_content:
            self._flush_text()
            self._in_entry_content = False
            return

        if not self._in_entry_content:
            return

        if tag == "pre" and self._in_pre:
            code = self._pre_text.strip()
            if code:
                lang = self._pre_lang.lower()
                self.sections.append(f"\n```{lang}\n{code}\n```")
            self._in_pre = False
            self._pre_text = ""
            self._pre_lang = ""
            return

        if tag == "a" and self._in_link:
            # リンクテキストとURLをMarkdown形式で現在のテキストに追加
            link_text = self._link_text.strip()
            if link_text and self._link_href:
                self._current_text += f"[{link_text}]({self._link_href})"
            elif link_text:
                self._current_text += link_text
            self._in_link = False
            self._link_href = ""
            self._link_text = ""
            return

        if tag in ("h2", "h3", "h4", "p", "li"):
            self._flush_text()
            self._current_tag = None

    def handle_data(self, data):
        if self._in_title:
            self.title += data.strip()
            return
        if self._in_date:
            self.date = data.strip()
            return
        if self._in_cat_name:
            self.category = data.strip()
            return

        if self._skip_toc:
            return

        if not self._in_entry_content:
            return

        if self._in_pre:
            self._pre_text += data
            return

        if self._in_link:
            self._link_text += data
            return

        if self._current_tag:
            self._current_text += data

    def _flush_text(self):
        text = self._current_text.strip()
        # 目次プラグイン(ez-toc)の開閉ボタンのラベル "Toggle" が混入するため除去
        text = text.replace("Toggle", "")
        if not text:
            self._current_text = ""
            return

        tag = self._current_tag
        if tag == "h2":
            self.sections.append(f"\n## {text}")
        elif tag == "h3":
            self.sections.append(f"\n### {text}")
        elif tag == "h4":
            self.sections.append(f"\n#### {text}")
        elif tag == "li":
            self.sections.append(f"- {text}")
        else:
            self.sections.append(text)

        self._current_text = ""

    def to_markdown(self):
        lines = []
        if self.title:
            lines.append(f"# {self.title}")
        if self.date or self.category:
            meta = []
            if self.date:
                meta.append(self.date)
            if self.category:
                meta.append(self.category)
            lines.append(" | ".join(meta))
        lines.append("")
        lines.extend(self.sections)
        return "\n".join(lines)


def fetch_article(url):
    if not url.startswith("https://creator.cluster.mu/"):
        print(f"Error: unsupported domain: {url}", file=sys.stderr)
        sys.exit(1)

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

    parser = ArticleParser()
    parser.feed(html)
    return parser.to_markdown()


def main():
    if len(sys.argv) < 2:
        print("Usage: fetch_article.py <url>", file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]
    markdown = fetch_article(url)
    print(markdown)


if __name__ == "__main__":
    main()
