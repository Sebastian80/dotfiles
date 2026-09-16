#!/usr/bin/env bash
# Tests for bin/phpstorm-background when PhpStorm already runs (a fake index MCP server).
#
#     bash claude/.claude/hooks/tests/run-phpstorm-background-tests.sh
#
# The cold-start branch drives real windows and is verified by hand; these cases cover the branch
# that must never touch the JetBrains launcher, whose "This Window / New Window" dialog would block.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HERE/../../../../bin/bin/phpstorm-background"
TMP=$(mktemp -d)
PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
echo '{"open": []}' > "$TMP/state.json"
python3 "$HERE/fake-index-mcp.py" "$PORT" "$TMP/state.json" "$TMP/calls.log" &
SERVER=$!
trap 'kill $SERVER 2>/dev/null; rm -rf "$TMP"' EXIT
until curl -s -m 1 -o /dev/null "http://127.0.0.1:$PORT/"; do sleep 0.2; done
printf '#!/bin/sh\necho launched >> "%s/launcher.log"\n' "$TMP" > "$TMP/launcher"; chmod +x "$TMP/launcher"
mkdir -p "$TMP/proj" "$TMP/other"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; pass=$((pass + 1)); else echo "FAIL $1: got [$2] want [$3]"; fail=$((fail + 1)); fi; }
run() {
  : > "$TMP/calls.log"; rm -f "$TMP/launcher.log"
  IDE_INDEX_PORT=$PORT PHPSTORM_LAUNCHER="$TMP/launcher" TIMEOUT=5 bash "$BIN" "$1" >/dev/null 2>&1
}
opened() { grep -c "^ide_open_project" "$TMP/calls.log"; }
launched() { [ -f "$TMP/launcher.log" ] && echo yes || echo no; }

echo "{\"open\": [\"$TMP/other\"]}" > "$TMP/state.json"
run "$TMP/proj"; code=$?
check "running, project closed: exit 0"            "$code" 0
check "running, project closed: opens via MCP"     "$(opened)" 1
check "running, project closed: no launcher"       "$(launched)" no

run "$TMP/proj"; code=$?
check "running, project open: exit 0"              "$code" 0
check "running, project open: no open call"        "$(opened)" 0

mkdir -p "$TMP/proj/src/Sub"
run "$TMP/proj/src/Sub"; code=$?
check "subdirectory of an open project: exit 0"    "$code" 0
check "subdirectory of an open project: no open"   "$(opened)" 0

echo "{\"open\": [\"$TMP/other\", \"/tmp/third\"]}" > "$TMP/state.json"
run "$TMP/proj"; code=$?
check "two other projects open: exit 0"            "$code" 0
check "two other projects open: project is open"  "$(jq --arg p "$TMP/proj" '.open | index($p) != null' "$TMP/state.json")" true
check "two other projects open: retried with project_path" "$(grep -c '^ide_open_project .*project_path' "$TMP/calls.log")" 1

echo '{"open": [], "open_fails": true}' > "$TMP/state.json"
run "$TMP/proj"; code=$?
check "running, open fails: exit 1"                "$code" 1
check "running, open fails: no launcher"           "$(launched)" no

echo; echo "pass=$pass fail=$fail"; [ "$fail" -eq 0 ]
