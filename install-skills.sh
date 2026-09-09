#!/bin/bash
# 列挙したスキルを、pnpx skillsでClaude CodeとCodexへグローバルインストールする。
# 社内orgのスキルは含めない。追加する際は取得元とスキル名を明示する。
# shibayu36 のスキルは最新を取得し、それ以外はコミットSHA-1で固定する。手元での編集内容は復元しない。
set -eu

pnpx skills add googleworkspace/cli#a3768d0e82ad83cca2da97724e46bea4ff0e6dbd -g -a claude-code codex -y --skill \
  gws-calendar \
  gws-calendar-agenda \
  gws-calendar-insert \
  gws-docs \
  gws-docs-write \
  gws-drive \
  gws-drive-upload \
  gws-forms \
  gws-gmail-read \
  gws-shared \
  gws-sheets \
  gws-sheets-read \
  gws-slides

pnpx skills add vercel-labs/skills#80feb48868972d518436f26711509bc78595b5cb -g -a claude-code codex -y --skill \
  find-skills

pnpx skills add shibayu36/agent-skills -g -a claude-code codex -y --skill \
  github-pr-review-operation \
  gws-docs-to-markdown \
  circleci-investigate \
  git-rebase \
  cluster-creator-kit-script \
  search-cluster-creators-guide

pnpx skills add mizchi/skills#7a0d72866a0bb3e9ac3e2768c328b09ba2bc40c4 -g -a claude-code codex -y --skill \
  empirical-prompt-tuning

pnpx skills add shokai/agent-skills#92bbd7e6b8914248f956fd0139f167a7620da75c -g -a claude-code codex -y --skill \
  codex-consultation

pnpx skills add yoshiko-pg/difit#82a765c037ec28fe7fe90ab2f1e4b5748032b4fa -g -a claude-code codex -y --skill \
  difit-review
