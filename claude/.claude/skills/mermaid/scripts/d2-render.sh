#!/bin/bash
# Validate and render a D2 diagram, sketch style with the ELK layout by default.
#
# Usage: d2-render.sh <file.d2> [output.svg|output.png]
#
# Output defaults to <file>.svg next to the input. Override the style through
# D2's own env vars: D2_LAYOUT=tala|dagre, D2_SKETCH=false, D2_THEME=<id>.
# PNG is a screenshot of the SVG taken with the headless Chromium that
# mermaid-cli caches (run validate.sh once if it is missing); D2's own PNG
# export would download a second Chromium.

set -uo pipefail

IN="${1:?usage: d2-render.sh <file.d2> [output.svg|output.png]}"
OUT="${2:-${IN%.d2}.svg}"
export D2_LAYOUT="${D2_LAYOUT:-elk}" D2_SKETCH="${D2_SKETCH:-true}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! d2 validate "$IN" > "$TMP/log" 2>&1; then
    echo "invalid: $IN" >&2
    sed 's/^/  /' "$TMP/log" >&2
    exit 1
fi

case "$OUT" in
    *.png) SVG="$TMP/out.svg" ;;
    *)     SVG="$OUT" ;;
esac

if ! d2 --pad 30 "$IN" "$SVG" > "$TMP/log" 2>&1; then
    echo "render failed: $IN" >&2
    sed 's/^/  /' "$TMP/log" >&2
    exit 1
fi

if [[ "$OUT" == *.png ]]; then
    CHROME="$(ls -d ~/.cache/puppeteer/chrome-headless-shell/*/*/chrome-headless-shell 2>/dev/null | tail -1)"
    if [[ -z "$CHROME" ]]; then
        echo "no cached chrome-headless-shell; run validate.sh once to download it" >&2
        exit 1
    fi
    read -r W H < <(grep -o 'viewBox="[^"]*"' "$SVG" | head -1 | tr -d '"' | awk '{print int($3), int($4)}')
    "$CHROME" --no-sandbox --headless --hide-scrollbars --force-device-scale-factor=2 \
        --window-size="$W,$H" --screenshot="$(realpath -m "$OUT")" "file://$SVG" > /dev/null 2>&1 \
        || { echo "png screenshot failed: $OUT" >&2; exit 1; }
fi

echo "ok: $OUT (layout=$D2_LAYOUT sketch=$D2_SKETCH)"
