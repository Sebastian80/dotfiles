#!/usr/bin/env bash
# Offline regression test for trigger-harness.py. Puts a fake `claude` on PATH, so
# no model is called and nothing is billed. Asserts the expected verdict per case:
# hits, misses, false triggers, non-answers that must stay unscored, the model
# guard, and the provenance fields.
#     bash test-trigger-harness.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/out"
cat > "$T/bin/claude" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "--version" ] && { echo "9.9.9 (fake)"; exit 0; }
case "$2" in
  *HIT*)    echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"index-lookup"}}]}}' ;;
  *SILENT*) echo '{"type":"system","subtype":"init"}' ;;
  *AGENT*)  for i in 1 2 3; do echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Agent","input":{"subagent_type":"oro-index-crawler"}}]}}'; done ;;
  *)        for i in 1 2 3; do echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{}}]}}'; done ;;
esac
EOF
chmod +x "$T/bin/claude"
cat > "$T/cases.json" <<'EOF'
[{"query":"HIT positive","should_trigger":true},
 {"query":"miss positive","should_trigger":true},
 {"query":"SILENT positive rate-limited","should_trigger":true},
 {"query":"HIT negative false trigger","should_trigger":false},
 {"query":"quiet negative","should_trigger":false},
 {"query":"AGENT positive routed to crawler","should_trigger":true}]
EOF
H="$HERE/trigger-harness.py"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got '$2', want '$3')"; fail=$((fail+1)); fi; }

out=$(PATH="$T/bin:$PATH" python3 "$H" "$T/cases.json" index-lookup fake "$T/out" 2>&1); check "no --model refused" "$(tail -1 <<<"$out" | grep -c 'model is required')" 1
out=$(PATH="$T/bin:$PATH" python3 "$H" "$T/cases.json" index-lookup fake "$T/out" --model claude-fable-5-1 2>&1); check "fable refused" "$(tail -1 <<<"$out" | grep -c 'refusing')" 1

PATH="$T/bin:$PATH" python3 "$H" "$T/cases.json" index-lookup fake "$T/out" --model sonnet --runs 3 --cwd "$T" >/dev/null 2>&1
check "sonnet run exits 0" "$?" 0
q() { python3 -c "import json,sys; rows={r['query']:r for r in map(json.loads, open('$T/out/fake.jsonl'))}; s=json.load(open('$T/out/fake-summary.json')); print($1)"; }
check "hit positive invoked"              "$(q "rows['HIT positive']['invoked']")" True
check "miss positive not invoked"         "$(q "rows['miss positive']['invoked']")" False
check "silent case unscored"              "$(q "rows['SILENT positive rate-limited']['invoked']")" None
check "silent case 3 non-answers"         "$(q "rows['SILENT positive rate-limited']['non_answers']")" 3
check "false trigger caught"              "$(q "rows['HIT negative false trigger']['invoked']")" True
check "positives exclude silent (3/1)"    "$(q "(s['positives'], s['pos_invoked'])")" "(3, 1)"
check "agent route recorded"              "$(q "rows['AGENT positive routed to crawler']['agents']")" "['oro-index-crawler']"
check "agent route is not a trigger"      "$(q "rows['AGENT positive routed to crawler']['invoked']")" False
check "negatives (2/1)"                   "$(q "(s['negatives'], s['neg_invoked'])")" "(2, 1)"
check "unscored_cases"                    "$(q "s['unscored_cases']")" 1
check "provenance model"                  "$(q "s['model']")" sonnet
check "provenance cli"                    "$(q "s['claude_cli']")" "9.9.9 (fake)"
check "provenance eval hash length"       "$(q "len(s['eval_set_sha256'])")" 16
echo; echo "fail=$fail"; [ "$fail" -eq 0 ]
