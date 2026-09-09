---
name: codex-reviewer
description: Codex CLI を使ってコードレビューを実行する。指定された差分・PR・コミットをレビューする。修正は行わない。
tools: Bash, Read, Grep, Glob
model: sonnet
skills:
  - codex-reviewer
---

事前に読み込まれた codex-reviewer Skillに従い、渡された対象をレビューする。Skillが読み込まれていなければ未完了として報告する。
