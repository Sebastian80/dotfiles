#!/usr/bin/env bash
#
# install-pi.sh - Install the pi coding agent and provision its sandbox extension.
#
# Usage:
#   install-pi.sh            Install pi, its packages and the sandbox extension
#   install-pi.sh --check    Report what is installed, change nothing
#   install-pi.sh -h         This help
#
# The stow package `pi` provides the tracked config (agents, protected-paths,
# sandbox.json, settings.json). This script provides the parts that cannot be
# tracked: the global npm install, the pi packages, and the sandbox extension,
# which is copied out of pi's own examples rather than vendored here.
#
# Why the version pin below: pi ships the sandbox example pinned to
# @anthropic-ai/sandbox-runtime 0.0.26, which depends on shell-quote <=1.8.4.
# That version carries a critical advisory (quote() does not escape newlines)
# in the library used to build the sandbox command line. Pinning forward drops
# the dependency entirely.
#
set -euo pipefail

SANDBOX_RUNTIME_VERSION="0.0.75"
PI_PACKAGE="@earendil-works/pi-coding-agent"
AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
EXT_DIR="$AGENT_DIR/extensions"
LOG="${TMPDIR:-/tmp}/install-pi.$$.log"

case "${1:-}" in
	-h | --help)
		sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
esac

info() { printf '  %s\n' "$1"; }
fail() {
	printf 'FAILED: %s\n  log: %s\n' "$1" "$LOG" >&2
	exit 1
}

if [[ "${1:-}" == "--check" ]]; then
	printf 'pi:               %s\n' "$(command -v pi || echo 'not installed')"
	printf 'version:          %s\n' "$(pi --version 2>/dev/null || echo '-')"
	printf 'agent dir:        %s\n' "$AGENT_DIR"
	printf 'codex auth:       %s\n' "$(pi auth check --provider openai-codex --json 2>/dev/null || echo '-')"
	printf 'sandbox ext:      %s\n' "$([[ -d "$EXT_DIR/sandbox/node_modules" ]] && echo present || echo missing)"
	printf 'sandbox runtime:  %s\n' "$(npm ls --prefix "$EXT_DIR/sandbox" @anthropic-ai/sandbox-runtime 2>/dev/null | sed -n '2s/.*@//p' || echo '-')"
	exit 0
fi

if ! command -v npm >/dev/null; then
	fail "npm not found; install Node via fnm first (scripts/setup/install-node.sh)"
fi

info "Installing $PI_PACKAGE globally"
npm install -g --ignore-scripts "$PI_PACKAGE" >"$LOG" 2>&1 || fail "global pi install"

info "Installing pi packages declared in settings.json"
[[ -f "$AGENT_DIR/settings.json" ]] || fail "$AGENT_DIR/settings.json missing; stow the 'pi' package first (make install)"
jq -r '.packages[]' "$AGENT_DIR/settings.json" | while read -r pkg; do
	pi install "$pkg" >>"$LOG" 2>&1 || fail "pi install $pkg"
done

info "Provisioning the sandbox extension"
SRC="$(npm root -g)/$PI_PACKAGE/examples/extensions/sandbox"
[[ -d "$SRC" ]] || fail "sandbox example not found at $SRC"
mkdir -p "$EXT_DIR"
rm -rf "$EXT_DIR/sandbox"
cp -R "$SRC" "$EXT_DIR/sandbox"

info "Pinning @anthropic-ai/sandbox-runtime to $SANDBOX_RUNTIME_VERSION"
npm install --prefix "$EXT_DIR/sandbox" --ignore-scripts \
	"@anthropic-ai/sandbox-runtime@$SANDBOX_RUNTIME_VERSION" >>"$LOG" 2>&1 || fail "sandbox dependency install"

if ! npm audit --prefix "$EXT_DIR/sandbox" --audit-level=high >>"$LOG" 2>&1; then
	printf 'WARNING: npm audit reports advisories in the sandbox extension.\n  log: %s\n' "$LOG" >&2
fi

info "Done. Config comes from the 'pi' stow package; credentials stay in $AGENT_DIR/auth.json."
info "Log: $LOG"
