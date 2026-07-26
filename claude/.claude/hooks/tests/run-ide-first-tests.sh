#!/usr/bin/env bash
# Regression matrix for ide-first.sh.
#
# Run after ANY change to the hook:
#     bash claude/.claude/hooks/tests/run-ide-first-tests.sh
#
# Cases are labelled by expected verdict: "[TP] ..." must exit 2 (block),
# everything else must exit 0 (allow). Exits non-zero if any case disagrees.
#
# Why this exists: a refactor of the hook once made it silently allow every
# command while still exiting 0 — a hook that fails open looks identical to a
# hook that found nothing to block. Asserting the expected verdict per case is
# the only thing that catches that.
#
# Note the hook only engages when the IDE index server is reachable and cwd is
# under ~/workspace. With the IDE closed every case returns allow and the run is
# vacuous — the script says so rather than reporting a false pass.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../ide-first.sh"
CASES="$HERE/ide-first-cases.jsonl"

[ -f "$HOOK" ]  || { echo "hook not found: $HOOK"; exit 1; }
[ -f "$CASES" ] || { echo "cases not found: $CASES"; exit 1; }

if ! curl -s -m 1 -o /dev/null "http://127.0.0.1:${IDE_INDEX_PORT:-29175}/"; then
  echo "SKIP: IDE index server unreachable — the hook exits early, so every case"
  echo "      would pass vacuously. Start the IDE and re-run."
  exit 0
fi

pass=0; fail=0
while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  lbl=$(printf '%s' "$line" | jq -r '.label')
  printf '%s' "$line" | jq -c 'del(.label)' | bash "$HOOK" >/dev/null 2>&1
  [ $? -eq 2 ] && verdict=BLOCK || verdict=allow
  case "$lbl" in "[TP]"*) want=BLOCK ;; *) want=allow ;; esac
  if [ "$verdict" = "$want" ]; then
    mark=ok; pass=$((pass + 1))
  else
    mark=FAIL; fail=$((fail + 1))
  fi
  printf '%-50s -> %-6s want=%-6s %s\n' "$lbl" "$verdict" "$want" "$mark"
done < "$CASES"

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
