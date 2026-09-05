#!/usr/bin/env bash
# PostToolUse hook (Edit|Write matcher): run the project's own formatter on the
# file Claude just wrote, so formatting is mechanical instead of a CLAUDE.md
# wish ("run a formatter instead of hand-editing whitespace").
#
# Rules:
#   - Only a formatter the PROJECT configures runs, found by walking up from the
#     file to the nearest config. Nothing global, nothing installed on the fly.
#   - Only project-local binaries: vendor/bin/php-cs-fixer, node_modules/.bin/
#     prettier, .venv/bin/ruff. Missing binary → silent no-op.
#   - Silent when nothing applies or nothing changed (a silent hook is not even
#     persisted). When the formatter rewrote the file, Claude is told through
#     additionalContext so it re-reads before the next edit.
#   - Failures never block the tool; they land in ~/.claude/format-on-write.log.

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$FILE" ] && [ -f "$FILE" ] || exit 0

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

LOG="$HOME/.claude/format-on-write.log"
before=$(md5sum < "$FILE")
case "$kind" in
  php)
    [ -x "$root/vendor/bin/php-cs-fixer" ] || exit 0
    (cd "$root" && vendor/bin/php-cs-fixer fix --quiet "$FILE") >>"$LOG" 2>&1 || echo "php-cs-fixer failed: $FILE" >>"$LOG" ;;
  prettier)
    [ -x "$root/node_modules/.bin/prettier" ] || exit 0
    (cd "$root" && node_modules/.bin/prettier --write --log-level silent "$FILE") >>"$LOG" 2>&1 || echo "prettier failed: $FILE" >>"$LOG" ;;
  ruff)
    [ -x "$root/.venv/bin/ruff" ] || exit 0
    (cd "$root" && .venv/bin/ruff format --quiet "$FILE") >>"$LOG" 2>&1 || echo "ruff failed: $FILE" >>"$LOG" ;;
esac
after=$(md5sum < "$FILE")
[ "$before" = "$after" ] && exit 0

jq -nc --arg k "$kind" --arg f "$FILE" \
  '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:("format-on-write: " + $k + " reformatted " + $f + "; re-read it before further edits.")}}'
