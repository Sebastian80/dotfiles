#!/usr/bin/env bash
# Hook for PreToolUse (matcher: Skill) and UserPromptSubmit.
#
# The index-lookup skill forks a worker whose only data source is PhpStorm's MCP
# servers. When PhpStorm is not running, that worker spends a model call finding
# out and answers nothing. This hook checks the index port first and hands the
# main session a decision it can put to the user: start PhpStorm, or answer with
# the built-in tools. Subagents cannot ask the user, so the question has to come
# from the main session.
#
#   PreToolUse, Skill tool with skill "index-lookup", port closed:
#       exit 2, the instruction on stderr (the fork is never started).
#   UserPromptSubmit, prompt starting with "/index-lookup", port closed:
#       exit 0 with additionalContext. A typed slash command bypasses the Skill
#       tool, and blocking the prompt would show the message to the user only,
#       so the model could not ask anything.
#   Everything else, or the port answers: exit 0, no output.
#
# Contract: stdin = hook JSON. IDE_INDEX_PORT overrides the port (tests use it).

INPUT=$(cat)
EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)

case "$EVENT" in
  PreToolUse)
    [ "$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')" = "Skill" ] || exit 0
    [ "$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // empty')" = "index-lookup" ] || exit 0
    ;;
  UserPromptSubmit)
    printf '%s' "$INPUT" | jq -r '.prompt // empty' | head -n 1 | grep -qE '^[[:space:]]*/index-lookup([[:space:]]|$)' || exit 0
    ;;
  *)
    exit 0
    ;;
esac

PORT="${IDE_INDEX_PORT:-29175}"
# Any HTTP answer, 404 included, means the server is up; curl fails only without one.
curl -s -m 1 -o /dev/null "http://127.0.0.1:${PORT}/" && exit 0

MSG="PhpStorm is not running (the index MCP port ${PORT} does not answer), so the index-lookup worker cannot answer. Ask the user with AskUserQuestion: start PhpStorm with this project, or answer without the index. If they choose to start it, run ${HOME}/.local/share/JetBrains/Toolbox/scripts/phpstorm with the project root in the background, wait until port ${PORT} answers, then run index-lookup again; the worker itself checks that the project is open and indexed. If they decline, or no question can be asked, answer with the built-in tools (Grep, Glob, Read, rg); ide-first.sh lets grep and rg through while this port is closed."

if [ "$EVENT" = "PreToolUse" ]; then
  echo "BLOCK: $MSG" >&2
  exit 2
fi

jq -nc --arg msg "$MSG" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $msg}}'
exit 0
