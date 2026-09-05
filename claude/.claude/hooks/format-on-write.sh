#!/usr/bin/env bash
# PostToolUse hook (Edit|Write|Bash matcher): run the project's own formatter on
# the file Claude just wrote, so formatting is mechanical instead of a CLAUDE.md
# wish ("run a formatter instead of hand-editing whitespace").
#
# Edit/Write name the file in tool_input.file_path. For Bash the hook parses the
# command for files it wrote — `> path`, `>> path` (heredocs included), `tee
# path`, and the last argument of a `sed -i` segment — relative to the hook's
# cwd. Auto mode writes files that way and would otherwise bypass the hook.
# Only paths that exist afterwards count; a false candidate is harmless.
#
# Rules:
#   - A project override wins: the nearest ancestor with an executable
#     .claude/format-file gets called as `format-file <abs path>` and nothing
#     else runs. That is the hook for stacks where only the container can run
#     the tool (docker compose run --rm -T php … < /dev/null; see git.md on
#     compose eating stdin). Keep it fast — it blocks every Edit.
#   - Otherwise only a formatter the PROJECT configures runs, found by walking
#     up from the file to the nearest config. Nothing global, nothing installed
#     on the fly.
#   - Only project-local binaries: vendor/bin/php-cs-fixer, node_modules/.bin/
#     prettier, .venv/bin/ruff. Missing binary → silent no-op. php-cs-fixer runs
#     with PHP_CS_FIXER_IGNORE_ENV=1: the host PHP is newer than the projects'
#     and the fixer refuses otherwise, although it parses that code fine. A
#     stateless formatter is the one PHP tool that doesn't need the stack.
#   - Silent when nothing applies or nothing changed (a silent hook is not even
#     persisted). When the formatter rewrote the file, Claude is told through
#     additionalContext so it re-reads before the next edit.
#   - Failures never block the tool; they land in ~/.claude/format-on-write.log.

INPUT=$(cat)
[ -n "$INPUT" ] || exit 0
LOG="$HOME/.claude/format-on-write.log"

# Files a shell command wrote, one absolute path per line.
bash_targets() {  # command cwd
  local cmd=$1 cwd=$2 t p
  {
    printf '%s' "$cmd" | grep -oE '(^|[^0-9&])>{1,2} *[^ ;&|)>]+' | sed -E 's/^.*>{1,2} *//'
    printf '%s' "$cmd" | grep -oE '(^|[ ;|&(])tee( +-[a-z]+)* +[^ ;&|)]+' | sed -E 's/^.*tee( +-[a-z]+)* +//'
    printf '%s' "$cmd" | tr ';|&' '\n\n\n' | grep -E '(^|[[:space:]])sed[[:space:]]+.*-i' | awk '{print $NF}'
  } 2>/dev/null | sed -E "s/^['\"]//; s/['\"]\$//" | grep -v '^/dev/' | while read -r t; do
    [ -n "$t" ] || continue
    case "$t" in /*) p=$t ;; *) p="$cwd/$t" ;; esac
    [ -f "$p" ] && printf '%s\n' "$p"
  done | sort -u
}

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
if [ "$TOOL" = "Bash" ]; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$CMD" ] || exit 0
  FILES=$(bash_targets "$CMD" "${CWD:-$PWD}")
else
  FILES=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
fi
[ -n "$FILES" ] || exit 0

# Formats one file; prints "<kind>\t<file>" when the formatter changed it.
format_one() {  # file
  local FILE=$1 dir root kind before after
  [ -f "$FILE" ] || return 0
  # Project override: nearest ancestor with an executable .claude/format-file.
  dir=$(dirname "$FILE")
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -x "$dir/.claude/format-file" ]; then
      before=$(md5sum < "$FILE")
      (cd "$dir" && .claude/format-file "$FILE") >>"$LOG" 2>&1 </dev/null || echo "format-file failed: $FILE" >>"$LOG"
      after=$(md5sum < "$FILE")
      [ "$before" = "$after" ] || printf '%s\t%s\n' "project format-file" "$FILE"
      return 0
    fi
    dir=$(dirname "$dir")
  done

  case "$FILE" in
    *.php) kind=php ;;
    *.js|*.jsx|*.ts|*.tsx|*.css|*.scss|*.json|*.md|*.yaml|*.yml) kind=prettier ;;
    *.py) kind=ruff ;;
    *) return 0 ;;
  esac

  # Nearest ancestor that configures this formatter.
  root=""
  dir=$(dirname "$FILE")
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    case "$kind" in
      php)
        if [ -f "$dir/.php-cs-fixer.dist.php" ] || [ -f "$dir/.php-cs-fixer.php" ]; then root=$dir; fi ;;
      prettier)
        if [ -f "$dir/.prettierrc" ] || ls "$dir"/.prettierrc.* >/dev/null 2>&1 \
           || [ -f "$dir/prettier.config.js" ] || [ -f "$dir/prettier.config.mjs" ]; then root=$dir; fi ;;
      ruff)
        if [ -f "$dir/ruff.toml" ] || { [ -f "$dir/pyproject.toml" ] && grep -q '^\[tool\.ruff' "$dir/pyproject.toml"; }; then root=$dir; fi ;;
    esac
    [ -n "$root" ] && break
    dir=$(dirname "$dir")
  done
  [ -z "$root" ] && return 0

  before=$(md5sum < "$FILE")
  case "$kind" in
    php)
      [ -x "$root/vendor/bin/php-cs-fixer" ] || return 0
      (cd "$root" && PHP_CS_FIXER_IGNORE_ENV=1 vendor/bin/php-cs-fixer fix --quiet "$FILE") >>"$LOG" 2>&1 || echo "php-cs-fixer failed: $FILE" >>"$LOG" ;;
    prettier)
      [ -x "$root/node_modules/.bin/prettier" ] || return 0
      (cd "$root" && node_modules/.bin/prettier --write --log-level silent "$FILE") >>"$LOG" 2>&1 || echo "prettier failed: $FILE" >>"$LOG" ;;
    ruff)
      [ -x "$root/.venv/bin/ruff" ] || return 0
      (cd "$root" && .venv/bin/ruff format --quiet "$FILE") >>"$LOG" 2>&1 || echo "ruff failed: $FILE" >>"$LOG" ;;
  esac
  after=$(md5sum < "$FILE")
  [ "$before" = "$after" ] && return 0
  printf '%s\t%s\n' "$kind" "$FILE"
}

CHANGED=$(printf '%s\n' "$FILES" | while read -r f; do [ -n "$f" ] && format_one "$f"; done)
[ -n "$CHANGED" ] || exit 0
MSG=$(printf '%s\n' "$CHANGED" | awk -F'\t' '{printf "%s%s reformatted %s", (NR>1?"; ":""), $1, $2}')
jq -nc --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:("format-on-write: " + $m + "; re-read before further edits.")}}'
