#!/usr/bin/env bash
# check-ide.sh <project-root> [decision-file]
#
# The gate in front of every crawl, whatever shape it takes: a background subprocess, a pane, an
# orchestrator with children. Run it BEFORE spawning anything. A crawler without the index has no
# code tools at all, and the cost of finding that out here is milliseconds against a model round
# trip inside a crawl that then has nothing to say.
#
# Exit 0  the index answers, has this project open, and is done indexing. Go ahead.
# Exit 10 someone has to decide. The request is on stdout and in the decision file. Ask the user,
#         and if they decline, do not spawn the crawl at all.
# Exit 11 the index is still building. Nobody needs to decide anything: wait and run this again.
set -uo pipefail

ROOT=${1:?usage: check-ide.sh <project-root> [decision-file]}
DECISION=${2:-}
INDEX_URL=http://127.0.0.1:29175/
MCP_URL=${INDEX_URL}index-mcp/streamable-http
LAUNCHER=$HOME/.local/share/JetBrains/Toolbox/scripts/phpstorm

request() { # state, reason, fix
	local body
	body=$(
		printf 'NEEDS-DECISION: start_ide %s\n' "$ROOT"
		printf 'reason: %s\n' "$2"
		printf 'state: %s\n' "$1"
		printf 'fix: %s\n' "$3"
	)
	[ -n "$DECISION" ] && printf '%s\n' "$body" > "$DECISION"
	printf '%s\n' "$body"
	exit 10
}

call() { # tool name, arguments JSON -> raw JSON-RPC response
	curl -s -m 20 -X POST "$MCP_URL" \
		-H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
		-d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":$2}}"
}

# The endpoint antivirus accepts connections on dead local ports, so the HTTP status decides, not
# curl's exit code: a dead IDE prints 000.
[ "$(curl -s -o /dev/null -m 2 -w '%{http_code}' "$INDEX_URL")" = "000" ] &&
	request "PhpStorm is not running" \
		"$INDEX_URL did not answer, so the crawler would have no code tools" \
		"run \`$LAUNCHER $ROOT\`, wait until $INDEX_URL answers and the index has finished, then run this again"

# A reachable port is not an open project. A managed-but-closed project makes the crawler refuse
# every question, and parallel checkouts share relative paths and line numbers, so an answer from
# the wrong one is indistinguishable from a right one.
# Ask without project_path: a status call that carries one WAKES a closed managed project, so the
# gate would report the state it just caused. The bare call lists every project untouched.
OPEN=$(call ide_project_status '{}' | python3 -c '
import json, sys
try:
    payload = json.loads(json.load(sys.stdin)["result"]["content"][0]["text"])
    projects = payload["projects"]
except Exception:
    print("unreadable"); raise SystemExit
root = sys.argv[1].rstrip("/")
for project in projects:
    if project.get("path", "").rstrip("/") == root:
        print("open" if project.get("open") else "closed"); break
else:
    print("unknown")
' "$ROOT")

case $OPEN in
open) ;;
closed) request "PhpStorm is running but does not have this project open" \
	"the index refuses every query for a project it does not have open: it answers isError with a hint to use ide_open_project, and does not start it on its own" \
	"post ide_open_project to $MCP_URL with project_path $ROOT (the index exposes it over plain HTTP even where .pi/mcp.json does not expose it to pi), wait until ide_index_status reports isIndexing false, then run this again" ;;
unknown) request "PhpStorm does not know this project" \
	"ide_project_status does not list this root at all, so the index holds nothing for it" \
	"post ide_open_project to $MCP_URL with project_path $ROOT (the index exposes it over plain HTTP even where .pi/mcp.json does not expose it to pi), wait until ide_index_status reports isIndexing false, then run this again" ;;
*) request "the index did not answer ide_project_status" \
	"the index is reachable but its project status was unreadable" \
	"check PhpStorm, then run this again" ;;
esac

# A half-built index answers partially instead of refusing, which is worse than refusing.
if call ide_index_status "{\"project_path\":\"$ROOT\"}" | python3 -c '
import json, sys
try:
    status = json.loads(json.load(sys.stdin)["result"]["content"][0]["text"])
except Exception:
    raise SystemExit(0)
raise SystemExit(1 if status.get("isIndexing") or status.get("isDumbMode") else 0)
'; then
	exit 0
fi
echo "The index is still building for $ROOT. Nobody has to decide anything: wait and run this again."
exit 11
