#!/usr/bin/env bash
# PostToolUse hook (Bash|Read|Grep|WebFetch|mcp__.* matcher): mask credentials in
# tool output before Claude sees it, through hookSpecificOutput.updatedToolOutput
# (all tools since Claude Code 2.1.121). The replacement is also what the session
# transcript stores, so a leaked value never reaches the jsonl. It is a safety
# net behind the "never print a credential" rule, not a licence to print one:
# telemetry still captures the original, and a value Claude can derive from the
# command itself (echo $((…))) is not hidden.
#
# What counts as a secret:
#   - the exact value of any env var whose name has a TOKEN, SECRET, PASSWORD,
#     PASSWD, PASS, API_KEY, PAT, CREDENTIAL(S), PRIVATE_KEY or AUTH segment —
#     the hook inherits Claude Code's environment, so bw-loaded tokens count
#   - the same for KEY=VALUE lines in ~/.env* (Jira/Confluence PATs have no
#     recognisable prefix, so this is the only way to catch them)
#   - well-known token shapes (GitHub, GitLab, Anthropic, OpenAI, AWS key ids,
#     Slack, JWTs, PEM private keys), URL userinfo passwords, and auth headers
# Values shorter than 12 characters or starting with / or ~ are ignored: they
# are paths or switches, and masking them would only confuse Claude.
#
# The rewrite walks every string in tool_response and leaves the structure
# alone, because Claude Code ignores a replacement that doesn't match the tool's
# output schema and falls back to the original. Silent when nothing matched.
# Never blocks: any failure exits 0 with no output.

INPUT=$(cat)
[ -n "$INPUT" ] || exit 0

ENV_FILES=""
for f in "$HOME"/.env*; do
  [ -f "$f" ] && ENV_FILES+=$(cat "$f" 2>/dev/null)$'\n'
done

printf '%s' "$INPUT" | jq -c --arg envfiles "$ENV_FILES" --arg q "'" '
  def secret_name: test("(^|_)(TOKEN|SECRET|PASSWORD|PASSWD|PASS|API_?KEY|PAT|CREDENTIALS?|PRIVATE_KEY|AUTH)(_|$)"; "i");
  def usable: length >= 12 and (startswith("/") or startswith("~") | not);

  ( [ $ENV | to_entries[] | select(.key | secret_name) | .value | select(usable) ]
    + [ $envfiles | split("\n")[]
        | capture("^\\s*(export\\s+)?(?<k>[A-Za-z_][A-Za-z0-9_]*)\\s*=\\s*(?<v>.*?)\\s*$")?
        | select(.k | secret_name)
        | .v | ltrimstr("\"") | rtrimstr("\"") | ltrimstr($q) | rtrimstr($q)
        | select(usable) ]
    | unique | sort_by(-length)
  ) as $literals

  | def redact:
      reduce $literals[] as $v (.; split($v) | join("[redacted]"))
      | gsub("-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\\s\\S]*?-----END [A-Z0-9 ]*PRIVATE KEY-----"; "[redacted]")
      | gsub("gh[pousr]_[A-Za-z0-9]{36,}"; "[redacted]")
      | gsub("github_pat_[A-Za-z0-9_]{22,}"; "[redacted]")
      | gsub("(glpat|glptt|gldt|glrt|glcbt|glsoat|glffct|glimt|glagent|gloas)-[A-Za-z0-9_-]{20,}"; "[redacted]")
      | gsub("sk-ant-[A-Za-z0-9_-]{20,}"; "[redacted]")
      | gsub("sk-(proj|svcacct|admin)-[A-Za-z0-9_-]{20,}"; "[redacted]")
      | gsub("\\b(AKIA|ASIA)[0-9A-Z]{16}\\b"; "[redacted]")
      | gsub("xox[abposr]-[A-Za-z0-9-]{10,}"; "[redacted]")
      | gsub("eyJ[A-Za-z0-9_-]{10,}\\.eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}"; "[redacted]")
      | gsub("(?<p>://[^:/@\\s]+:)[^@\\s/]{4,}(?=@)"; "\(.p)[redacted]")
      | gsub("(?<p>(?i:authorization|proxy-authorization|private-token|x-api-key)[\"" + $q + "]?\\s*[:=]\\s*[\"" + $q + "]?((?i:bearer|basic|token)\\s+)?)[A-Za-z0-9._~+/=-]{8,}"; "\(.p)[redacted]");

  .tool_response as $orig
  | ($orig | walk(if type == "string" then redact else . end)) as $new
  | if $new == $orig then empty else
      { hookSpecificOutput: {
          hookEventName: "PostToolUse",
          updatedToolOutput: $new,
          additionalContext: "mask-output: credential-like values in this tool output were replaced with [redacted] before you saw it. The real values exist; do not print, decode or reconstruct them — refer to them by variable or file name."
      } }
    end
' 2>/dev/null
exit 0
