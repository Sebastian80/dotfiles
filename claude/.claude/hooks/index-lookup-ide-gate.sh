#!/usr/bin/env bash
# Hook for PreToolUse (matcher: Skill) and UserPromptExpansion (matcher: index-lookup).
#
# The index-lookup skill forks a worker whose only data source is PhpStorm's MCP servers. When
# PhpStorm is not running, that worker spends ~12 s and ~18k tokens finding out and answers nothing,
# and it cannot ask the user anything. So the question is asked before the fork starts.
#
#   PreToolUse, Skill tool with skill "index-lookup", PhpStorm down or project not open:
#       exit 2, the instruction on stderr (the fork is never started). The main session asks the
#       user with AskUserQuestion, then starts PhpStorm or answers with rg.
#   UserPromptExpansion, typed /index-lookup, PhpStorm down or project not open:
#       A typed command forks straight away, with no main-session turn that could ask, so this hook
#       asks itself with a desktop dialog. "Start PhpStorm" / "Open project" runs phpstorm-background on
#       the session directory and lets the command through once the project is open; "Answer without index", a
#       failed start or no display blocks the command with a message saying what to do instead.
#   Everything else, or the project is open (or its state unreadable): exit 0, no output.
#
# Contract: stdin = hook JSON. Test overrides: IDE_INDEX_PORT (port), IDE_GATE_DIALOG (command that
# exits 0 for "start"), IDE_GATE_LAUNCHER (replaces phpstorm-background), IDE_GATE_BIN (helper directory).

INPUT=$(cat)
field() { printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null; }
EVENT=$(field '.hook_event_name')
SKILL=index-lookup
BIN="${IDE_GATE_BIN:-$HOME/bin}"

case "$EVENT" in
  PreToolUse)
    [ "$(field '.tool_name')" = "Skill" ] || exit 0
    [ "$(field '.tool_input.skill')" = "$SKILL" ] || exit 0
    ;;
  UserPromptExpansion)
    [ "$(field '.command_name')" = "$SKILL" ] || exit 0
    ;;
  *)
    exit 0
    ;;
esac

PORT="${IDE_INDEX_PORT:-29175}"
export IDE_INDEX_PORT="$PORT"
ROOT=$(field '.cwd'); ROOT="${ROOT:-$PWD}"
LAUNCHER="${IDE_GATE_LAUNCHER:-$BIN/phpstorm-background}"

# Any HTTP answer, 404 included, means the server is up; curl fails only without one. A running
# PhpStorm still cannot answer for a project it does not have open, so the project is checked too.
# When its state cannot be read, the lookup goes ahead and the worker reports what it finds.
if curl -s -m 1 -o /dev/null "http://127.0.0.1:${PORT}/"; then
  state=$("$BIN/phpstorm-project-state" "$ROOT" 2>/dev/null) || exit 0
  [ "$state" = closed ] || exit 0
  PROBLEM="PhpStorm is running, but ${ROOT} is not open in it"
  ACTION="Open ${ROOT} in PhpStorm"
  BUTTON="Open project"
else
  PROBLEM="PhpStorm is not running (the index MCP port ${PORT} does not answer)"
  ACTION="Start PhpStorm with ${ROOT}"
  BUTTON="Start PhpStorm"
fi

if [ "$EVENT" = "PreToolUse" ]; then
  echo "BLOCK: ${PROBLEM}, so the index-lookup worker cannot answer. Ask the user with AskUserQuestion: ${ACTION}, or answer without the index. If they agree, run ${LAUNCHER} with the project root (it starts PhpStorm or opens the project without taking keyboard focus, and returns once the project is open), then run index-lookup again. If they decline, or no question can be asked, answer with the built-in tools (Grep, Glob, Read, rg); in PHP projects use rg -uu, since plain rg follows .gitignore and skips vendor/." >&2
  exit 2
fi

deny() { jq -nc --arg r "$1" '{decision: "block", reason: $r}'; exit 0; }

ask() {
  local text="${PROBLEM}, so /index-lookup cannot use the index.\n\n${ACTION}?"
  if [ -n "${IDE_GATE_DIALOG:-}" ]; then
    "$IDE_GATE_DIALOG" "$text"
  else
    zenity --question --title="index-lookup" --text="$text" --no-wrap \
      --ok-label="$BUTTON" --cancel-label="Answer without index" --timeout=120 2>/dev/null
  fi
}

if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || { [ -z "${IDE_GATE_DIALOG:-}" ] && ! command -v zenity >/dev/null; }; then
  deny "${PROBLEM} and no dialog can be shown here. Run: ${LAUNCHER} ${ROOT} and then /index-lookup again, or ask the question without the slash to get an answer from rg -uu."
fi

if ! ask; then
  deny "Not opened in PhpStorm. Ask the question again without the slash and it gets answered with rg -uu, without the index."
fi

if ! "$LAUNCHER" "$ROOT" >/dev/null 2>&1; then
  deny "PhpStorm did not come up with ${ROOT} open. Check the IDE, then run /index-lookup again."
fi
exit 0
