#!/usr/bin/env bash
# Hook for PreToolUse (matcher: Skill) and UserPromptExpansion (matcher: index-lookup).
#
# The index-lookup skill forks a worker whose only data source is PhpStorm's MCP servers. When
# PhpStorm is not running, that worker spends ~12 s and ~18k tokens finding out and answers nothing,
# and it cannot ask the user anything. So the question is asked before the fork starts.
#
#   PreToolUse, Skill tool with skill "index-lookup", port closed:
#       exit 2, the instruction on stderr (the fork is never started). The main session asks the
#       user with AskUserQuestion, then starts PhpStorm or answers with rg.
#   UserPromptExpansion, typed /index-lookup, port closed:
#       A typed command forks straight away, with no main-session turn that could ask, so this hook
#       asks itself with a desktop dialog. "Start PhpStorm" runs phpstorm-background on the session
#       directory and lets the command through once the index answers; "Answer without index", a
#       failed start or no display blocks the command with a message saying what to do instead.
#   Everything else, or the port answers: exit 0, no output.
#
# Contract: stdin = hook JSON. Test overrides: IDE_INDEX_PORT (port), IDE_GATE_DIALOG (command that
# exits 0 for "start"), IDE_GATE_LAUNCHER (replaces phpstorm-background).

INPUT=$(cat)
field() { printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null; }
EVENT=$(field '.hook_event_name')

case "$EVENT" in
  PreToolUse)
    [ "$(field '.tool_name')" = "Skill" ] || exit 0
    [ "$(field '.tool_input.skill')" = "index-lookup" ] || exit 0
    ;;
  UserPromptExpansion)
    [ "$(field '.command_name')" = "index-lookup" ] || exit 0
    ;;
  *)
    exit 0
    ;;
esac

PORT="${IDE_INDEX_PORT:-29175}"
# Any HTTP answer, 404 included, means the server is up; curl fails only without one.
curl -s -m 1 -o /dev/null "http://127.0.0.1:${PORT}/" && exit 0

LAUNCHER="${IDE_GATE_LAUNCHER:-$HOME/bin/phpstorm-background}"

if [ "$EVENT" = "PreToolUse" ]; then
  echo "BLOCK: PhpStorm is not running (the index MCP port ${PORT} does not answer), so the index-lookup worker cannot answer. Ask the user with AskUserQuestion: start PhpStorm with this project, or answer without the index. If they choose to start it, run ${LAUNCHER} with the project root (it starts PhpStorm without keeping keyboard focus and returns once port ${PORT} answers), then run index-lookup again; the worker itself checks that the project is open and indexed. If they decline, or no question can be asked, answer with the built-in tools (Grep, Glob, Read, rg); in PHP projects use rg -uu, since plain rg follows .gitignore and skips vendor/." >&2
  exit 2
fi

ROOT=$(field '.cwd'); ROOT="${ROOT:-$PWD}"
deny() { jq -nc --arg r "$1" '{decision: "block", reason: $r}'; exit 0; }

ask() {
  local text="PhpStorm is not running, so /index-lookup cannot use the index.\n\nStart PhpStorm with ${ROOT}?"
  if [ -n "${IDE_GATE_DIALOG:-}" ]; then
    "$IDE_GATE_DIALOG" "$text"
  else
    zenity --question --title="index-lookup" --text="$text" --no-wrap \
      --ok-label="Start PhpStorm" --cancel-label="Answer without index" --timeout=120 2>/dev/null
  fi
}

if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || { [ -z "${IDE_GATE_DIALOG:-}" ] && ! command -v zenity >/dev/null; }; then
  deny "PhpStorm is not running and no dialog can be shown here. Start it with: ${LAUNCHER} ${ROOT} and run /index-lookup again, or ask the question without the slash to get an answer from rg -uu."
fi

if ! ask; then
  deny "PhpStorm not started. Ask the question again without the slash and it gets answered with rg -uu, without the index."
fi

if ! "$LAUNCHER" "$ROOT" >/dev/null 2>&1; then
  deny "PhpStorm did not come up (port ${PORT} still silent). Check the IDE, then run /index-lookup again."
fi
exit 0
