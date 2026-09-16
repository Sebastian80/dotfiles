#!/usr/bin/env bash
# Regression matrix for index-lookup-ide-gate.sh.
#
#     bash claude/.claude/hooks/tests/run-index-lookup-ide-gate-tests.sh
#
# Each case names the port state it needs and the verdict it expects:
#   block    exit 2 and a BLOCK message on stderr, nothing on stdout
#   context  exit 0 and additionalContext JSON on stdout
#   pass     exit 0 and no output at all
# The port is simulated, so the run does not depend on PhpStorm: "open" is a
# throwaway local HTTP server, "closed" is a port nothing listens on. A gate that
# fails open prints plausible output and exits 0, so every verdict is asserted.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../index-lookup-ide-gate.sh"
CASES="$HERE/index-lookup-ide-gate-cases.jsonl"

OPEN_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
CLOSED_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
python3 -m http.server "$OPEN_PORT" --bind 127.0.0.1 >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
until curl -s -m 1 -o /dev/null "http://127.0.0.1:$OPEN_PORT/"; do sleep 0.2; done
if curl -s -m 1 -o /dev/null "http://127.0.0.1:$CLOSED_PORT/"; then
  echo "setup error: the closed port $CLOSED_PORT answers"; exit 1
fi

pass=0; fail=0
while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  label=$(printf '%s' "$line" | jq -r '.label')
  want=$(printf '%s' "$line" | jq -r '.want')
  port=$([ "$(printf '%s' "$line" | jq -r '.port')" = open ] && echo "$OPEN_PORT" || echo "$CLOSED_PORT")
  out=$(printf '%s' "$line" | jq -c '.input' | IDE_INDEX_PORT=$port bash "$HOOK" 2>/tmp/ide-gate-test-err.$$)
  code=$?
  err=$(cat /tmp/ide-gate-test-err.$$); rm -f /tmp/ide-gate-test-err.$$
  if [ "$code" -eq 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q '^BLOCK: PhpStorm is not running'; then
    got=block
  elif [ "$code" -eq 0 ] && printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit" and (.hookSpecificOutput.additionalContext | test("PhpStorm is not running"))' >/dev/null 2>&1; then
    got=context
  elif [ "$code" -eq 0 ] && [ -z "$out" ] && [ -z "$err" ]; then
    got=pass
  else
    got="unexpected(exit=$code)"
  fi
  if [ "$got" = "$want" ]; then mark=ok; pass=$((pass + 1)); else mark=FAIL; fail=$((fail + 1)); fi
  printf '%-62s -> %-8s want=%-8s %s\n' "$label" "$got" "$want" "$mark"
done < "$CASES"

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
