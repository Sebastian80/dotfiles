#!/usr/bin/env bash
#
# qa-run.sh - run a verification command and record what actually happened.
#
# Usage:
#   qa-run.sh <TICKET-KEY> <CRITERION-ID> -- <command...>
#   qa-run.sh -h
#
# The command runs with its output visible. Its exit code and the tail of its
# output are appended to the ticket's ledger, so the ledger can only ever hold
# runs that really executed. Full output is kept beside the ledger.
#
# The command's exit code is passed through, so a failing verification fails the
# caller too. A red run is still a recorded observation: the gate cares that the
# criterion was accounted for, not that it was green.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEDGER="$HERE/qa-ledger.py"
TAIL_LINES="${QA_RUN_TAIL_LINES:-20}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 4 ]]; then
	sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
	exit 0
fi

KEY="$1"
CRITERION="$2"
shift 2
[[ "${1:-}" == "--" ]] && shift

STATE_DIR="${QA_REVIEW_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/qa-review}"
LOG_DIR="$STATE_DIR/$KEY.runs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/${CRITERION}-${STAMP}.log"

printf '\n=== qa-run %s criterion %s: %s\n' "$KEY" "$CRITERION" "$*"
"$@" 2>&1 | tee "$LOG"
CODE="${PIPESTATUS[0]}"

TAIL="$(tail -n "$TAIL_LINES" "$LOG" | tr -s '[:space:]' ' ' | cut -c1-500)"

"$LEDGER" observe "$KEY" \
	--criterion "$CRITERION" \
	--command "$*" \
	--exit-code "$CODE" \
	--output-tail "$TAIL" >/dev/null

# Record anything the review wrote, so the scope gate has something to compare.
if git rev-parse --show-toplevel >/dev/null 2>&1; then
	while IFS= read -r changed; do
		[[ -n "$changed" ]] && "$LEDGER" note-write "$KEY" --file "$changed" >/dev/null
	done < <(git status --porcelain -uall | awk '{print $NF}')
fi

printf '=== recorded: criterion %s, exit %s, log %s\n' "$CRITERION" "$CODE" "$LOG"
exit "$CODE"
