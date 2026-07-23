#!/usr/bin/env bash
# PreToolUse hook (Bash matcher): steer text-level code operations to the
# IDE Index MCP tools (ide_search_text, ide_find_references, ide_move_file,
# ide_refactor_rename) while a JetBrains IDE with the index-mcp plugin runs.
# Adapted from hechtcarmel/jetbrains-index-mcp-plugin docs/claude-code-hooks.md
# for a PHP/Oro stack, with two gates the upstream script lacks:
#   1. Only enforces when the index server is actually reachable — a closed
#      IDE makes bash the right tool (matches the ide-index-mcp skill).
#   2. Only enforces for work under ~/workspace (where IDE projects live);
#      dotfiles/scripts/scratch work stays unrestricted.

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

matches_target() { printf '%s' "$CMD" | grep -qE "$TARGET"; }

# Recursive grep on source → ide_search_text / ide_find_references.
# git grep is left alone; rg -uu is the documented escape hatch for IDE-excluded folders.
if printf '%s' "$CMD" | grep -qE '(^|[|;&[:space:]])grep[[:space:]]+-[a-zA-Z]*r' \
   && ! printf '%s' "$CMD" | grep -qE 'git[[:space:]]+grep' \
   && matches_target; then
  echo "BLOCK: Use ide_search_text (regex: true, filePattern: ...) or ide_find_references instead of recursive grep on source files. Only for IDE-excluded folders: rg -uu <path>." >&2
  exit 2
fi

if printf '%s' "$CMD" | grep -qE '(^|[|;&[:space:]])rg[[:space:]]' \
   && ! printf '%s' "$CMD" | grep -qE '[[:space:]]-uu' \
   && matches_target; then
  echo "BLOCK: Use ide_search_text (regex: true, filePattern: ...) or ide_find_references instead of rg on source files. Only for IDE-excluded folders: rg -uu <path>." >&2
  exit 2
fi

if printf '%s' "$CMD" | grep -qE '(^|[|;&[:space:]])find[[:space:]]' \
   && printf '%s' "$CMD" | grep -qE '(\||xargs).*grep|grep.*\|' \
   && matches_target; then
  echo "BLOCK: Use ide_search_text instead of find+grep on source files." >&2
  exit 2
fi

# sed -i on source → semantic rename or the Edit tool.
if printf '%s' "$CMD" | grep -qE '(^|[|;&[:space:]])sed[[:space:]]+-[a-zA-Z]*i' \
   && matches_target; then
  echo "BLOCK: Use ide_refactor_rename for symbol renames, or the Edit tool for text changes — not sed -i on source files." >&2
  exit 2
fi

# mv on PHP files → ide_move_file (PSR-4-aware). mv to /tmp is a backup, allowed.
if printf '%s' "$CMD" | grep -qE '(^|[|;&[:space:]])mv[[:space:]]' \
   && printf '%s' "$CMD" | grep -qE '\.(php|phtml)\b' \
   && ! printf '%s' "$CMD" | grep -qE '[[:space:]]/tmp/'; then
  echo "BLOCK: Use ide_move_file (updates PSR-4 namespaces and references) or ide_refactor_rename in file mode instead of mv on PHP files." >&2
  exit 2
fi

exit 0
