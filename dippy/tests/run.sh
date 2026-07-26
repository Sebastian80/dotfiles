#!/usr/bin/env bash
# Regression matrix for ~/.dippy/config.
#
#     bash dippy/tests/run.sh
#
# Each case declares the decision it expects (allow / ask / deny). Exits
# non-zero if any case disagrees, so a rule edit that widens or narrows a
# pattern more than intended is caught rather than discovered in use.
#
# Why per-case expectations rather than printing decisions: a permission layer
# that fails open still exits 0 and still prints plausible output. The only
# thing that distinguishes "nothing matched because the rules are correct" from
# "nothing matched because the rules broke" is asserting what should match.
#
# Coverage is deliberately partial - the invariants worth defending:
#   - IDE raw file writes prompt (they bypass the Edit(.env*) deny rules,
#     and dippy MCP rules cannot see the target path)
#   - IDE semantic writes and reads stay unattended
#   - the phpstorm-debugger allow deliberately overrides deny-mcp *remove_*
#   - deny-mcp still bites on servers without a namespace-wide allow
#   - a few bash rules that would be alarming to lose silently

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASES="$HERE/cases.jsonl"

command -v dippy >/dev/null || { echo "dippy not on PATH"; exit 1; }
[ -f "$CASES" ] || { echo "cases not found: $CASES"; exit 1; }

pass=0; fail=0
while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  want=$(printf '%s' "$line" | jq -r '.want')
  lbl=$(printf '%s' "$line" | jq -r '.label')
  got=$(printf '%s' "$line" | jq -c '.payload' | dippy --claude 2>/dev/null \
        | jq -r '.hookSpecificOutput.permissionDecision // "ERR"' 2>/dev/null)
  [ -z "$got" ] && got=ERR
  if [ "$got" = "$want" ]; then
    mark=ok; pass=$((pass + 1))
  else
    mark=FAIL; fail=$((fail + 1))
  fi
  printf '%-62s -> %-5s want=%-5s %s\n' "$lbl" "$got" "$want" "$mark"
done < "$CASES"

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
