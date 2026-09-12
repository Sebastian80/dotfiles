#!/usr/bin/env bash
# run-trigger-eval.sh [--skill NAME] [--router-model CLAUDE-MODEL] [--samples N]
#
#   run-trigger-eval.sh --skill pi-crawler --router-model sonnet --samples 3
#
# Asks a fresh Claude session, per case in trigger-eval.json, which skill it would invoke, and
# compares that against should_trigger. It never lets the session do the work: routing is the only
# thing under test.
#
# router-model is the model of the CLAUDE session doing the routing, nothing to do with pi. No pi
# process runs here and no crawl happens; the crawler's own model is set in crawler.md and is a
# Codex one. Only Claude model names belong in that argument.
#
# Prints one line per case with want and got, so a case that passes for the wrong reason is still
# visible, and a summary with false positives and false negatives named.
set -uo pipefail

SKILL=pi-crawler
ROUTER_MODEL=sonnet  # a Claude model: haiku answers NONE even for an unmistakable positive
# Routing is not deterministic: one query answered NONE, then the same skill twice, across three
# fresh sessions. A single sample per case scores noise as if it were a verdict.
SAMPLES=3

while [ $# -gt 0 ]; do
	case $1 in
	--skill) SKILL=$2; shift 2 ;;
	--router-model) ROUTER_MODEL=$2; shift 2 ;;
	--samples) SAMPLES=$2; shift 2 ;;
	-h | --help) sed -n '2,14p' "$0"; exit 0 ;;
	*) echo "unknown argument: $1 (see --help)" >&2; exit 2 ;;
	esac
done
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
	hits=0; won=""
	for _ in $(seq "$SAMPLES"); do
		answer=$(claude -p --model "$ROUTER_MODEL" "$query

Which skill would you invoke first to handle this? Answer with the skill name only, or NONE if no
skill applies. Do not start the work." 2>/dev/null | tr '[:upper:]' '[:lower:]')
		printf '%s' "$answer" | command grep -q -- "$SKILL" && hits=$((hits + 1))
		won="$won $(printf '%s' "$answer" | head -1 | cut -c1-28)"
	done

	# Majority of the samples decides; the tally goes in the line so a 2/3 is not read as a 3/3.
	if [ $((hits * 2)) -gt "$SAMPLES" ]; then got=true; else got=false; fi
	# What won matters as much as whether this skill did. In a session with thirty skills a miss is
	# usually another skill winning, and often winning correctly, which is a wrong expectation here
	# rather than a fault in the skill.
	if [ "$got" = "$want" ]; then
		pass=$((pass + 1)); mark=ok
	else
		fail=$((fail + 1)); mark=MISS
		[ "$want" = false ] && fp+=("$query -> $won") || fn+=("$query -> won by: $won")
	fi
	printf '%-4s want=%-5s got=%-5s (%s/%s) %-46s %s\n' "$mark" "$want" "$got" "$hits" "$SAMPLES" "${query:0:46}" "[$won ]"
done

echo
echo "$SKILL routed by claude $ROUTER_MODEL, majority of $SAMPLES samples: $pass/$total pass, $fail miss"
[ ${#fp[@]} -gt 0 ] && { echo "false positives (fired when it should not):"; printf '  - %s\n' "${fp[@]}"; }
[ ${#fn[@]} -gt 0 ] && { echo "false negatives (missed when it should fire):"; printf '  - %s\n' "${fn[@]}"; }
exit 0
