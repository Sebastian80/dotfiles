#!/usr/bin/env bash
# Verdict matrix for mask-output.sh.
#
# Run after ANY change to the hook:
#     bash claude/.claude/hooks/tests/run-mask-output-tests.sh
#
# Each case feeds a PostToolUse payload and asserts the verdict:
#   redacted - hook emitted updatedToolOutput with the same shape (same paths,
#              same non-string values), no trace of the secret, "[redacted]"
#              present, the non-secret text kept, and an additionalContext note.
#   silent   - no output at all (Claude sees the original).
# A redaction hook that fails open prints nothing and looks healthy, so every
# case that must redact asserts on the secret being gone, not on exit codes.
#
# Fake secrets are assembled at runtime: no token-shaped literal lives in this
# repo (GitHub push protection would flag it), and the hook runs under env -i so
# no real credential from the calling shell can reach it or this output.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../mask-output.sh"
[ -f "$HOOK" ] || { echo "hook not found: $HOOK"; exit 1; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
FAKE_HOME="$T/home"; mkdir -p "$FAKE_HOME"

rep() { printf "%${2}s" '' | tr ' ' "$1"; }  # char count
GH="ghp_$(rep a 36)"
GH_PAT="github_pat_$(rep B 30)"
GL="glpat-$(rep c 20)"
ANT="sk-ant-api03-$(rep D 30)"
AWS="AKIA$(rep E 16)"
SLACK="xoxb-$(rep 1 12)-$(rep f 16)"
JWT="eyJ$(rep g 16).eyJ$(rep h 16).$(rep i 20)"
ENVVAL="zQ9$(rep k 17)"        # 20 chars, only known through the env var
SHORTVAL="abc123"              # below the length floor
FILEVAL="Pw7$(rep m 21)"       # only known through ~/.env.jira
PEM="-----BEGIN OPENSSH PRIVATE KEY-----
$(rep n 40)
$(rep o 40)
-----END OPENSSH PRIVATE KEY-----"
printf 'JIRA_URL=https://jira.example.test/some/long/path\nexport JIRA_API_TOKEN="%s"\n' "$FILEVAL" > "$FAKE_HOME/.env.jira"

hook() {  # stdin: payload
  env -i PATH="$PATH" HOME="$FAKE_HOME" \
    FAKE_API_TOKEN="$ENVVAL" SHORT_TOKEN="$SHORTVAL" \
    SSH_AUTH_SOCK="/tmp/ssh-agent.sock-long-enough" DEPLOY_URL="https://deploy.example.test/long" \
    MAX_MCP_OUTPUT_TOKENS=50000 \
    bash "$HOOK" 2>/dev/null
}

bash_payload() { jq -nc --arg o "$1" --arg e "${2:-}" '{tool_name:"Bash",tool_input:{command:"x"},tool_response:{stdout:$o,stderr:$e,interrupted:false,isImage:false}}'; }

pass=0; fail=0
check() {  # label payload want(redacted|silent) secret keep
  local lbl=$1 payload=$2 want=$3 secret=$4 keep=$5 out got orig new
  out=$(printf '%s' "$payload" | hook)
  if [ -z "$out" ]; then
    got=silent
  else
    orig=$(printf '%s' "$payload" | jq -c '.tool_response | [paths(scalars)] | sort')
    new=$(printf '%s' "$out" | jq -c '.hookSpecificOutput.updatedToolOutput | [paths(scalars)] | sort' 2>/dev/null)
    if [ "$orig" = "$new" ] \
       && [ "$(printf '%s' "$payload" | jq -c '[.tool_response | .. | select(type=="boolean" or type=="number")]')" \
          = "$(printf '%s' "$out" | jq -c '[.hookSpecificOutput.updatedToolOutput | .. | select(type=="boolean" or type=="number")]')" ] \
       && ! printf '%s' "$out" | grep -qF -- "$secret" \
       && printf '%s' "$out" | grep -qF '[redacted]' \
       && { [ -z "$keep" ] || printf '%s' "$out" | grep -qF -- "$keep"; } \
       && printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse" and (.hookSpecificOutput.additionalContext | length > 0)' >/dev/null 2>&1; then
      got=redacted
    else
      got=BROKEN
    fi
  fi
  if [ "$got" = "$want" ]; then mark=ok; pass=$((pass + 1)); else mark=FAIL; fail=$((fail + 1)); fi
  printf '%-50s -> %-9s want=%-9s %s\n' "$lbl" "$got" "$want" "$mark"
}

check "bash stdout: GitHub token, text kept"      "$(bash_payload "token is $GH here")"            redacted "$GH"     "token is"
check "bash stdout: fine-grained GitHub PAT"       "$(bash_payload "$GH_PAT")"                      redacted "$GH_PAT" ""
check "bash stderr: GitLab PAT"                    "$(bash_payload ok "auth $GL failed")"           redacted "$GL"     "failed"
check "bash: Anthropic key"                        "$(bash_payload "key=$ANT")"                     redacted "$ANT"    "key="
check "bash: AWS access key id"                    "$(bash_payload "$AWS")"                         redacted "$AWS"    ""
check "bash: Slack token"                          "$(bash_payload "$SLACK")"                       redacted "$SLACK"  ""
check "bash: JWT"                                  "$(bash_payload "jwt $JWT")"                     redacted "$JWT"    "jwt"
check "bash: private key block"                    "$(bash_payload "before
$PEM
after")"                                                                                            redacted "$(rep n 40)" "after"
check "bash: password in URL userinfo"             "$(bash_payload "https://oauth2:$ENVVAL-x@git.example.test/r.git")" redacted "$ENVVAL-x" "git.example.test"
check "bash: Authorization bearer header"          "$(bash_payload "Authorization: Bearer opaque.$(rep p 12)")" redacted "opaque.$(rep p 12)" "Authorization"
check "bash: value of a *_TOKEN env var"           "$(bash_payload "printed $ENVVAL")"              redacted "$ENVVAL" "printed"
check "bash: value from ~/.env.jira"               "$(bash_payload "JIRA_API_TOKEN=$FILEVAL")"     redacted "$FILEVAL" "JIRA_API_TOKEN="
check "read: file.content, shape kept"             "$(jq -nc --arg c "a
$GH
b" '{tool_name:"Read",tool_input:{file_path:"/x"},tool_response:{type:"text",file:{filePath:"/x",content:$c,numLines:3,startLine:1,totalLines:3}}}')" redacted "$GH" "b"
check "mcp: plain string output"                   "$(jq -nc --arg c "t $GL" '{tool_name:"mcp__jira__get",tool_response:$c}')" redacted "$GL" ""
check "mcp: content block array"                   "$(jq -nc --arg c "t $GL" '{tool_name:"mcp__x__y",tool_response:[{type:"text",text:$c}]}')" redacted "$GL" ""

check "clean output stays silent"                  "$(bash_payload "all good, 3 files changed")"    silent "" ""
check "short *_TOKEN value is ignored"             "$(bash_payload "code $SHORTVAL")"               silent "" ""
check "path-valued SSH_AUTH_SOCK is ignored"       "$(bash_payload "/tmp/ssh-agent.sock-long-enough")" silent "" ""
check "non-secret env name (DEPLOY_URL) ignored"   "$(bash_payload "https://deploy.example.test/long")" silent "" ""
check "non-secret key from env file (JIRA_URL)"    "$(bash_payload "https://jira.example.test/some/long/path")" silent "" ""
check "lookalike words: glob-/sk- prose"           "$(bash_payload "glob-pattern-matching-for-files and sk-learn-is-a-library-name")" silent "" ""
check "empty stdin"                                ""                                               silent "" ""
check "malformed json"                             "{not json"                                      silent "" ""

echo "---"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
