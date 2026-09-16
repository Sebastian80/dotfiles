#!/usr/bin/env bash
# Regression matrix for index-lookup-ide-gate.sh.
#
#     bash claude/.claude/hooks/tests/run-index-lookup-ide-gate-tests.sh
#
# Each case names the port state it needs and the verdict it expects:
#   block      exit 2 and a BLOCK message on stderr, nothing on stdout (Skill tool path)
#   deny:TEXT  exit 0 and {"decision":"block"} JSON whose reason contains TEXT (typed command path)
#   started    exit 0, no output, and the launcher was called with the case's cwd
#   pass       exit 0 and no output at all
# The port is simulated, so the run does not depend on PhpStorm: "open" is a throwaway local HTTP
# server, "closed" is a port nothing listens on. The dialog and the launcher are stubs: "dialog" is
# yes (the stub exits 0), no (exits 1) or none (no display); "launcher" is ok or fail. A case that
# must not show a dialog uses dialog "no", so a dialog shown by mistake turns into a deny and fails.
# A gate that fails open prints plausible output and exits 0, so every verdict is asserted.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../index-lookup-ide-gate.sh"
CASES="$HERE/index-lookup-ide-gate-cases.jsonl"
TMP=$(mktemp -d)

OPEN_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
CLOSED_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
python3 -m http.server "$OPEN_PORT" --bind 127.0.0.1 >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null; rm -rf "$TMP"' EXIT
until curl -s -m 1 -o /dev/null "http://127.0.0.1:$OPEN_PORT/"; do sleep 0.2; done
if curl -s -m 1 -o /dev/null "http://127.0.0.1:$CLOSED_PORT/"; then
  echo "setup error: the closed port $CLOSED_PORT answers"; exit 1
fi

printf '#!/bin/sh\nexit 0\n' > "$TMP/dialog-yes"
printf '#!/bin/sh\nexit 1\n' > "$TMP/dialog-no"
printf '#!/bin/sh\necho "$1" > "%s/launched"\nexit 0\n' "$TMP" > "$TMP/launcher-ok"
printf '#!/bin/sh\necho "$1" > "%s/launched"\nexit 1\n' "$TMP" > "$TMP/launcher-fail"
chmod +x "$TMP"/dialog-* "$TMP"/launcher-*

pass=0; fail=0
while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  field() { printf '%s' "$line" | jq -r "$1"; }
  label=$(field '.label'); want=$(field '.want'); cwd=$(field '.input.cwd // empty')
  port=$([ "$(field '.port')" = open ] && echo "$OPEN_PORT" || echo "$CLOSED_PORT")
  dialog=$(field '.dialog // "no"'); launcher=$(field '.launcher // "fail"')
  rm -f "$TMP/launched"
  if [ "$dialog" = none ]; then display_env=(env -u DISPLAY -u WAYLAND_DISPLAY); dialog_cmd="$TMP/dialog-no"
  else display_env=(env DISPLAY=:test); dialog_cmd="$TMP/dialog-$dialog"; fi
  out=$(field '.input | tojson' | "${display_env[@]}" IDE_INDEX_PORT="$port" IDE_GATE_DIALOG="$dialog_cmd" \
        IDE_GATE_LAUNCHER="$TMP/launcher-$launcher" bash "$HOOK" 2>"$TMP/err")
  code=$?
  err=$(cat "$TMP/err")
  reason=$(printf '%s' "$out" | jq -r 'select(.decision == "block") | .reason' 2>/dev/null)
  if [ "$code" -eq 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q '^BLOCK: PhpStorm is not running'; then
    got=block
  elif [ "$code" -eq 0 ] && [ -n "$reason" ]; then
    got="deny:$reason"
  elif [ "$code" -eq 0 ] && [ -z "$out" ] && [ -z "$err" ] && [ -f "$TMP/launched" ]; then
    got="started:$(cat "$TMP/launched")"
  elif [ "$code" -eq 0 ] && [ -z "$out" ] && [ -z "$err" ]; then
    got=pass
  else
    got="unexpected(exit=$code out=$out err=$err)"
  fi
  case "$want" in
    deny:*)  [[ "$got" == deny:*"${want#deny:}"* ]] && ok=1 || ok=0 ;;
    started) [ "$got" = "started:$cwd" ] && ok=1 || ok=0 ;;
    *)       [ "$got" = "$want" ] && ok=1 || ok=0 ;;
  esac
  if [ "$ok" = 1 ]; then mark=ok; pass=$((pass + 1)); else mark=FAIL; fail=$((fail + 1)); fi
  printf '%-62s -> %-12.12s want=%-24s %s\n' "$label" "$got" "$want" "$mark"
done < "$CASES"

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
