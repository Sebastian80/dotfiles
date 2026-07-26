#!/usr/bin/env bash
# PreToolUse hook (Bash matcher): steer text-level code operations to the
# IDE Index MCP tools (ide_search_text, ide_find_references, ide_move_file,
# ide_refactor_rename) while a JetBrains IDE with the index-mcp plugin runs.
# Adapted from hechtcarmel/jetbrains-index-mcp-plugin docs/claude-code-hooks.md
# for a PHP/Oro stack, with three gates the upstream script lacks:
#   1. Only enforces when the index server is actually reachable — a closed
#      IDE makes bash the right tool (matches the ide-index-mcp skill).
#   2. Only enforces for work under ~/workspace (where IDE projects live);
#      dotfiles/scripts/scratch work stays unrestricted.
#   3. Evaluates each statement of a compound command separately, so a source
#      path in one statement cannot trip a rule matching in another.

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
case "$CWD" in
  "$HOME"/workspace/*|"$HOME"/workspace) ;;
  *) exit 0 ;;
esac

curl -s -m 0.3 -o /dev/null "http://127.0.0.1:${IDE_INDEX_PORT:-29175}/" || exit 0

# Source-code targets: extensions or canonical source dirs.
TARGET='\.(php|phtml|twig|js|mjs|ts|vue|scss|ya?ml)\b|(^|[[:space:]"'"'"'])(src|tests|app|config|templates)/'

# Appended to search-rule blocks: the hook fires reliably, the skill often is not
# invoked, so the failure mode that produces wrong answers is stated here.
HINT="If an IDE search comes back empty, verify with ide_project_status that this project is open — an empty result is only an answer for a project the IDE actually has indexed."

matches_target() { printf '%s' "$1" | grep -qE "$TARGET"; }

# One statement of a compound command. Pipelines stay intact (a pipeline is a
# single logical command, and the find+grep rule deliberately spans the pipe).
check_segment() {
  local SEG="$1"

  # Recursive grep on source → ide_search_text / ide_find_references.
  # git grep is left alone; rg -uu is the documented escape hatch for IDE-excluded folders.
  if printf '%s' "$SEG" | grep -qE '(^|[|;&[:space:]])grep[[:space:]]+-[a-zA-Z]*r' \
     && ! printf '%s' "$SEG" | grep -qE 'git[[:space:]]+grep' \
     && matches_target "$SEG"; then
    echo "BLOCK: Use ide_search_text (regex: true, filePattern: ...) or ide_find_references instead of recursive grep on source files. Only for IDE-excluded folders: rg -uu <path>. $HINT" >&2
    exit 2
  fi

  if printf '%s' "$SEG" | grep -qE '(^|[|;&[:space:]])rg[[:space:]]' \
     && ! printf '%s' "$SEG" | grep -qE '[[:space:]]-uu' \
     && matches_target "$SEG"; then
    echo "BLOCK: Use ide_search_text (regex: true, filePattern: ...) or ide_find_references instead of rg on source files. Only for IDE-excluded folders: rg -uu <path>. $HINT" >&2
    exit 2
  fi

  if printf '%s' "$SEG" | grep -qE '(^|[|;&[:space:]])find[[:space:]]' \
     && printf '%s' "$SEG" | grep -qE '(\||xargs).*grep|grep.*\|' \
     && matches_target "$SEG"; then
    echo "BLOCK: Use ide_search_text instead of find+grep on source files. $HINT" >&2
    exit 2
  fi

  # sed -i on source → semantic rename or the Edit tool.
  if printf '%s' "$SEG" | grep -qE '(^|[|;&[:space:]])sed[[:space:]]+-[a-zA-Z]*i' \
     && matches_target "$SEG"; then
    echo "BLOCK: Use ide_refactor_rename for symbol renames, or the Edit tool for text changes — not an in-place stream edit on source files." >&2
    exit 2
  fi

  # mv on PHP files → ide_move_file (PSR-4-aware). mv to /tmp is a backup, allowed.
  if printf '%s' "$SEG" | grep -qE '(^|[|;&[:space:]])mv[[:space:]]' \
     && printf '%s' "$SEG" | grep -qE '\.(php|phtml)\b' \
     && ! printf '%s' "$SEG" | grep -qE '[[:space:]]/tmp/'; then
    echo "BLOCK: Use ide_move_file (updates PSR-4 namespaces and references) or ide_refactor_rename in file mode instead of mv on PHP files." >&2
    exit 2
  fi
}

# Split on statement separators (;  &&  ||  newline). NOT on a single | —
# pipelines are one command and rule 3 matches across the pipe.
# `|| [ -n "$SEG" ]` is required: a command with no separator yields a single
# segment with no trailing newline, and plain `read` would drop it — silently
# disabling every rule.
while IFS= read -r SEG || [ -n "$SEG" ]; do
  [ -z "${SEG//[[:space:]]/}" ] && continue
  check_segment "$SEG"
done < <(printf '%s' "$CMD" | sed -E 's/\|\|/\n/g; s/&&/\n/g; s/;/\n/g')

exit 0
