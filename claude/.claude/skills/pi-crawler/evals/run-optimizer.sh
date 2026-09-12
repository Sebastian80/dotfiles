#!/usr/bin/env bash
# run-optimizer.sh <skill-dir> <eval-set> <results-dir>
#
# The official optimizer scores a candidate by whether Claude invokes a hashed CLONE of the skill.
# An installed skill of the same name wins that choice every time, so every positive scores 0.00 and
# the run measures nothing. This hides the real skill for the duration and always puts it back.
set -uo pipefail
SKILL=${1:?skill dir}; EVAL=${2:?eval set}; OUT=${3:?results dir}
N=$HOME/.claude/plugins/cache/claude-plugins-official/skill-creator/f2cc019c16eb/skills/skill-creator
HIDDEN=$SKILL.hidden-for-eval
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

restore() { [ -d "$HIDDEN" ] && mv "$HIDDEN" "$SKILL" && echo "restored $SKILL"; }
trap restore EXIT INT TERM

# The eval set usually lives inside the skill, which is about to be renamed: take a copy first.
mkdir -p "$OUT"
cp "$EVAL" "$OUT/eval-set.json" || exit 1
EVAL=$OUT/eval-set.json

mv "$SKILL" "$HIDDEN" || exit 1
echo "hid $(basename "$SKILL") for the duration of the run"
cd /home/sebastian/workspace/hmkg || exit 1
PYTHONPATH="$N" python3 -m scripts.run_loop \
  --eval-set "$EVAL" --skill-path "$HIDDEN" \
  --model claude-opus-5 --max-iterations 5 --runs-per-query 3 --timeout 60 \
  --results-dir "$OUT" --report "$OUT/report.html" --verbose > "$OUT/run.log" 2>&1
echo "optimizer exit=$?"
