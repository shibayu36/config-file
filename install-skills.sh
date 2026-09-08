#!/bin/bash
# 列挙したスキルを、pnpx skillsでClaude CodeとCodexへグローバルインストールする。
# 社内orgのスキルは含めない。追加する際は取得元とスキル名を明示する。
# バージョンは固定していないため、再実行時には配布元の内容が反映される。手元での編集内容は復元しない。
set -eu

pnpx skills add googleworkspace/cli -g -a claude-code codex -y --skill \
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

pnpx skills add vercel-labs/skills -g -a claude-code codex -y --skill \
  find-skills

pnpx skills add shibayu36/agent-skills -g -a claude-code codex -y --skill \
  github-pr-review-operation \
  gws-docs-to-markdown \
  circleci-investigate \
  git-rebase \
  cluster-creator-kit-script \
  search-cluster-creators-guide

pnpx skills add mizchi/skills -g -a claude-code codex -y --skill \
  empirical-prompt-tuning

pnpx skills add shokai/agent-skills -g -a claude-code codex -y --skill \
  codex-consultation

pnpx skills add yoshiko-pg/difit -g -a claude-code codex -y --skill \
  difit-review
