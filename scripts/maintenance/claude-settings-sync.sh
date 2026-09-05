#!/usr/bin/env bash
# Keep the tracked claude/.claude/settings.reference.json equal to the live,
# gitignored ~/.claude/settings.json. Run it after changing Claude Code settings
# (or in a session retro): the live file is the one the harness reads and edits,
# the reference is what git and other machines see, and the two drift silently.
#
# Usage:
#   claude-settings-sync.sh          show drift as a diff (exit 1 if any)
#   claude-settings-sync.sh --apply  copy live -> reference
set -euo pipefail

LIVE="$HOME/.claude/settings.json"
REF="$(cd "$(dirname "$0")/../.." && pwd)/claude/.claude/settings.reference.json"

for f in "$LIVE" "$REF"; do
  [ -f "$f" ] || { echo "missing: $f" >&2; exit 2; }
  jq -e . "$f" >/dev/null || { echo "invalid JSON: $f" >&2; exit 2; }
done

# autoMode.environment describes internal infrastructure (hosts, namespaces) for the
# classifier; the dotfiles repo is public, so it never enters the reference.
STRIP='del(.autoMode.environment)'

case "${1:-}" in
  --apply)
    jq --indent 2 "$STRIP" "$LIVE" > "$REF"
    echo "reference synced from live (autoMode.environment stripped)"
    ;;
  "")
    if diff -u --label reference --label live <(jq -S . "$REF") <(jq -S "$STRIP" "$LIVE"); then
      echo "reference == live"
    else
      echo "drift: run $0 --apply" >&2
      exit 1
    fi
    ;;
  *)
    sed -n '2,9p' "$0" | cut -c3-
    exit 2
    ;;
esac
