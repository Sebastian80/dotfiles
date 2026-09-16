#!/usr/bin/env bash
# Regression matrix for phpstorm-readonly-gate.sh.
#
# Run after ANY change to the hook:
#     bash claude/.claude/hooks/tests/run-phpstorm-readonly-gate-tests.sh
#
# Cases are labelled by expected verdict: "[TP] ..." must exit 2 (block),
# everything else must exit 0 (allow). Exits non-zero if any case disagrees.
# A gate that fails open still exits 0 with plausible output; asserting the
# verdict per case is what catches that.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../phpstorm-readonly-gate.sh"
CASES="$HERE/phpstorm-readonly-gate-cases.jsonl"

[ -f "$HOOK" ]  || { echo "hook not found: $HOOK"; exit 1; }
[ -f "$CASES" ] || { echo "cases not found: $CASES"; exit 1; }

pass=0; fail=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  lbl=$(printf '%s' "$line" | jq -r '.label')
  case "$lbl" in
    "[TP]"*) want=block ;;
    *)       want=allow ;;
  esac
  printf '%s' "$line" | jq -c '{tool_name: "mcp__phpstorm__execute_tool", tool_input: .tool_input}' \
    | bash "$HOOK" >/dev/null 2>&1
  rc=$?
  case "$rc" in
    0) verdict=allow ;;
    2) verdict=block ;;
    *) verdict="exit$rc" ;;
  esac
  if [ "$verdict" = "$want" ]; then
    mark=ok; pass=$((pass + 1))
  else
    mark=FAIL; fail=$((fail + 1))
  fi
  printf '%-52s -> %-6s want=%-6s %s\n' "$lbl" "$verdict" "$want" "$mark"
done < "$CASES"

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
