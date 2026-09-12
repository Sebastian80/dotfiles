#!/usr/bin/env bash
# run-trigger-eval.sh [skill-name] [model]
#
# Asks a fresh Claude session, per case in trigger-eval.json, which skill it would invoke, and
# compares that against should_trigger. It never lets the session do the work: routing is the only
# thing under test.
#
# Prints one line per case with want and got, so a case that passes for the wrong reason is still
# visible, and a summary with false positives and false negatives named.
set -uo pipefail

SKILL=${1:-pi-crawler}
MODEL=${2:-sonnet}   # haiku answers NONE even for an unmistakable positive: it does not route to skills here
CASES=$(dirname "$0")/trigger-eval.json
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

[ -r "$CASES" ] || { echo "no cases at $CASES" >&2; exit 2; }

pass=0; fail=0; fp=(); fn=()
total=$(jq length "$CASES")

for i in $(seq 0 $((total - 1))); do
	query=$(jq -r ".[$i].query" "$CASES")
	want=$(jq -r ".[$i].should_trigger" "$CASES")

	# Ask which skill it WOULD invoke. Telling it not to do the work makes "NONE" a coherent answer
	# about the work rather than about routing, and every positive then reads as a miss.
	answer=$(claude -p --model "$MODEL" "$query

Which skill would you invoke first to handle this? Answer with the skill name only, or NONE if no
skill applies. Do not start the work." 2>/dev/null | tr '[:upper:]' '[:lower:]')

	if printf '%s' "$answer" | command grep -q -- "$SKILL"; then got=true; else got=false; fi
	# What won matters as much as whether this skill did. In a session with thirty skills a miss is
	# usually another skill winning, and often winning correctly, which is a wrong expectation here
	# rather than a fault in the skill.
	won=$(printf '%s' "$answer" | head -1 | cut -c1-40)
	if [ "$got" = "$want" ]; then
		pass=$((pass + 1)); mark=ok
	else
		fail=$((fail + 1)); mark=MISS
		[ "$want" = false ] && fp+=("$query -> $won") || fn+=("$query -> won by: $won")
	fi
	printf '%-4s want=%-5s got=%-5s %-52s %s\n' "$mark" "$want" "$got" "${query:0:52}" "[$won]"
done

echo
echo "$SKILL on $MODEL: $pass/$total pass, $fail miss"
[ ${#fp[@]} -gt 0 ] && { echo "false positives (fired when it should not):"; printf '  - %s\n' "${fp[@]}"; }
[ ${#fn[@]} -gt 0 ] && { echo "false negatives (missed when it should fire):"; printf '  - %s\n' "${fn[@]}"; }
exit 0
