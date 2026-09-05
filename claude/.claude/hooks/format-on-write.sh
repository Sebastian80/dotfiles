#!/usr/bin/env bash
# PostToolUse hook (Edit|Write matcher): run the project's own formatter on the
# file Claude just wrote, so formatting is mechanical instead of a CLAUDE.md
# wish ("run a formatter instead of hand-editing whitespace").
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
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$FILE" ] && [ -f "$FILE" ] || exit 0

LOG="$HOME/.claude/format-on-write.log"

report() {  # kind
  jq -nc --arg k "$1" --arg f "$FILE" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:("format-on-write: " + $k + " reformatted " + $f + "; re-read it before further edits.")}}'
}

# Project override: nearest ancestor with an executable .claude/format-file.
dir=$(dirname "$FILE")
while [ "$dir" != "/" ] && [ -n "$dir" ]; do
  if [ -x "$dir/.claude/format-file" ]; then
    before=$(md5sum < "$FILE")
    (cd "$dir" && .claude/format-file "$FILE") >>"$LOG" 2>&1 </dev/null || echo "format-file failed: $FILE" >>"$LOG"
    after=$(md5sum < "$FILE")
    [ "$before" = "$after" ] || report "project format-file"
    exit 0
  fi
  dir=$(dirname "$dir")
done

case "$FILE" in
  *.php) kind=php ;;
  *.js|*.jsx|*.ts|*.tsx|*.css|*.scss|*.json|*.md|*.yaml|*.yml) kind=prettier ;;
  *.py) kind=ruff ;;
  *) exit 0 ;;
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
[ -z "$root" ] && exit 0

before=$(md5sum < "$FILE")
case "$kind" in
  php)
    [ -x "$root/vendor/bin/php-cs-fixer" ] || exit 0
    (cd "$root" && PHP_CS_FIXER_IGNORE_ENV=1 vendor/bin/php-cs-fixer fix --quiet "$FILE") >>"$LOG" 2>&1 || echo "php-cs-fixer failed: $FILE" >>"$LOG" ;;
  prettier)
    [ -x "$root/node_modules/.bin/prettier" ] || exit 0
    (cd "$root" && node_modules/.bin/prettier --write --log-level silent "$FILE") >>"$LOG" 2>&1 || echo "prettier failed: $FILE" >>"$LOG" ;;
  ruff)
    [ -x "$root/.venv/bin/ruff" ] || exit 0
    (cd "$root" && .venv/bin/ruff format --quiet "$FILE") >>"$LOG" 2>&1 || echo "ruff failed: $FILE" >>"$LOG" ;;
esac
after=$(md5sum < "$FILE")
[ "$before" = "$after" ] && exit 0
report "$kind"
