#!/usr/bin/env bash
# crawl.sh <project-root> <question-file> [answer-file]
#
# Runs the pi crawler headless and prints where the answer landed.
#
# Exit 10 means the crawl did not run or did not finish because someone has to decide something:
# the request is on stdout and in <answer-file>.decision. The usual case is a dead PhpStorm index,
# which this script checks for BEFORE starting pi, because that costs 5 ms where asking the crawler
# costs a 15 s model round trip. Ask the user, act on the answer, run this again.
set -uo pipefail

ROOT=${1:?usage: crawl.sh <project-root> <question-file> [answer-file]}
QUESTION=${2:?usage: crawl.sh <project-root> <question-file> [answer-file]}
ANSWER=${3:-${TMPDIR:-/tmp}/crawl-$(date +%s).md}
DECISION=$ANSWER.decision
INDEX_URL=http://127.0.0.1:29175/
LAUNCHER=$HOME/.local/share/JetBrains/Toolbox/scripts/phpstorm
AGENT=$HOME/.pi/agent/agents/crawler.md

export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
rm -f "$DECISION"

[ -d "$ROOT" ] || { echo "no such project root: $ROOT" >&2; exit 2; }
[ -r "$QUESTION" ] || { echo "no such question file: $QUESTION" >&2; exit 2; }
[ -r "$AGENT" ] || { echo "no crawler agent at $AGENT" >&2; exit 2; }
[ -r "$ROOT/.pi/mcp.json" ] || { echo "$ROOT is not enabled for the crawler ($ROOT/.pi/mcp.json is missing)" >&2; exit 2; }

# The endpoint antivirus accepts connections on dead local ports, so the HTTP status decides, not
# curl's exit code: a dead IDE prints 000.
if [ "$(curl -s -o /dev/null -m 2 -w '%{http_code}' "$INDEX_URL")" = "000" ]; then
  cat > "$DECISION" <<EOF
NEEDS-DECISION: start_ide $ROOT
reason: preflight: $INDEX_URL did not answer, so the crawler would have no code tools
state: PhpStorm is not running
fix: run \`$LAUNCHER $ROOT\`, wait until $INDEX_URL answers and the index has finished, then run this again
EOF
  cat "$DECISION"
  exit 10
fi

# -nc matches the crawler agent's own inheritProjectContext: false. Without it pi loads the
# project's AGENTS.md and CLAUDE.md, and the crawler spends its first turn obeying them instead of
# answering the question.
T0=$(date +%s)
PI_DECISION_FILE=$DECISION HERDR_ENV= timeout 900 pi -p -a -ns -nc \
  --model openai-codex/gpt-5.6-terra --thinking medium -xt write,edit,bash \
  --append-system-prompt "$(sed -n '/^You are a read-only code crawler/,$p' "$AGENT")" \
  "$(cat "$QUESTION")" </dev/null > "$ANSWER" 2>&1
RC=$?
printf 'rc=%s elapsed=%ss answer=%s\n' "$RC" "$(( $(date +%s) - T0 ))" "$ANSWER"

# start_ide writes this when it cannot ask in place. The marker is also in the answer, but the
# model paraphrases it there, so the file is the one to trust.
if [ -s "$DECISION" ]; then
  echo "--- the crawl stopped and handed a decision back ---"
  cat "$DECISION"
  exit 10
fi
