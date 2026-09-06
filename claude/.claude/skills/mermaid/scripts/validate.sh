#!/bin/bash
# Validate (and optionally render) a Mermaid diagram with mermaid-cli.
#
# Usage: validate.sh <file.mmd|file.md> [output.svg|output.png]
#
# Exit 0 when every diagram parses, 1 with the parser message otherwise.
# A .md input validates every ```mermaid fence in it (mermaid-cli writes one
# output per fence; they are discarded unless an output path is given).
#
# Chromium is started with --no-sandbox: Ubuntu's AppArmor blocks unprivileged
# user namespaces, and Puppeteer's sandbox needs them. First run downloads a
# Chromium (~170 MB) into ~/.cache/puppeteer.

set -uo pipefail

IN="${1:?usage: validate.sh <file.mmd|file.md> [output]}"
OUT="${2:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ -z "$OUT" ]]; then
    case "$IN" in
        *.md) OUT="$TMP/out.md" ;;   # fences become out-1.svg, out-2.svg … in $TMP
        *)    OUT="$TMP/out.svg" ;;
    esac
fi

if npx -y -p @mermaid-js/mermaid-cli mmdc -p "$HERE/puppeteer.json" -i "$IN" -o "$OUT" -q > "$TMP/log" 2>&1; then
    echo "ok: $IN"
    exit 0
fi
echo "invalid: $IN" >&2
grep -E -m1 -A3 'Parse error|Error:|Expecting' "$TMP/log" | sed 's/^/  /' >&2
exit 1
