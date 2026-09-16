#!/usr/bin/env bash
# PreToolUse hook (Bash matcher): steer text-level code searches to the
# index-lookup skill (the oro-index-lookup subagent, the only session that
# has the PhpStorm index server) while a JetBrains IDE with the index-mcp
# plugin runs, and keep stream edits and moves on PHP sources with the Edit
# tool and git mv until a refactoring agent exposes the IDE refactorings.
# Adapted from hechtcarmel/jetbrains-index-mcp-plugin docs/claude-code-hooks.md
# for a PHP/Oro stack, with three gates the upstream script lacks:
#   1. Only enforces when the index server is actually reachable — a closed
#      IDE makes bash the right tool.
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
# invoked, so the routing is stated here.
HINT="Ask with the index-lookup skill (Skill tool, skill index-lookup, args = your question); it forks the oro-index-lookup subagent, which checks that the project is open and answers from the index. Only for IDE-excluded folders or a project PhpStorm does not have open: rg -uu <path>."

matches_target() { printf '%s' "$1" | grep -qE "$TARGET"; }

# One statement of a compound command. Pipelines stay intact (a pipeline is a
# single logical command, and the find+grep rule deliberately spans the pipe).
check_segment() {
  local SEG="$1"

  # Recursive grep on source → the index, via the index-lookup subagent.
  # git grep is left alone; rg -uu is the documented escape hatch for IDE-excluded folders.
  if printf '%s' "$SEG" | grep -qE '(^|[|;&[:space:]])grep[[:space:]]+-[a-zA-Z]*r' \
     && ! printf '%s' "$SEG" | grep -qE 'git[[:space:]]+grep' \
     && matches_target "$SEG"; then
    echo "BLOCK: No recursive grep on source files while the project is indexed. $HINT" >&2
    exit 2
  fi

  if printf '%s' "$SEG" | grep -qE '(^|[|;&[:space:]])rg[[:space:]]' \
     && ! printf '%s' "$SEG" | grep -qE '[[:space:]]-uu' \
     && matches_target "$SEG"; then
    echo "BLOCK: No rg on source files while the project is indexed. $HINT" >&2
    exit 2
  fi

  if printf '%s' "$SEG" | grep -qE '(^|[|;&[:space:]])find[[:space:]]' \
     && printf '%s' "$SEG" | grep -qE '(\||xargs).*grep|grep.*\|' \
     && matches_target "$SEG"; then
    echo "BLOCK: No find+grep on source files while the project is indexed. $HINT" >&2
    exit 2
  fi

  # sed -i on source → the Edit tool. A symbol rename is an IDE refactoring the
  # main session cannot run; do it with Edit and sweep the old name afterwards.
  if printf '%s' "$SEG" | grep -qE '(^|[|;&[:space:]])sed[[:space:]]+-[a-zA-Z]*i' \
     && matches_target "$SEG"; then
    echo "BLOCK: Use the Edit tool for changes to source files, never an in-place stream edit. For a symbol rename, edit the declaration and every reference with Edit, then sweep the old name through index-lookup." >&2
    exit 2
  fi

  # Plain mv on PHP files → git mv (keeps history) plus an Edit of namespace and
  # imports; the PSR-4-aware IDE move is not available in the main session.
  # mv to /tmp is a backup, allowed.
  if printf '%s' "$SEG" | grep -qE '(^|[|;&[:space:]])mv[[:space:]]' \
     && ! printf '%s' "$SEG" | grep -qE 'git[[:space:]]+mv' \
     && printf '%s' "$SEG" | grep -qE '\.(php|phtml)\b' \
     && ! printf '%s' "$SEG" | grep -qE '[[:space:]]/tmp/'; then
    echo "BLOCK: Use git mv for PHP files, then fix the namespace and every import with Edit; a plain mv loses history and the PSR-4-aware IDE move is not available in this session." >&2
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
