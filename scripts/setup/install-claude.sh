#!/usr/bin/env bash
#
# install-claude.sh - Install Claude Code with Anthropic's own installer.
#
# Usage:
#   install-claude.sh [stable|latest|VERSION]   Install it when missing
#   install-claude.sh --check                   Report what is installed, change nothing
#   install-claude.sh --force [TARGET]          Install even when it is already present
#   install-claude.sh -h                        This help
#
# Claude Code is neither an npm package nor stowed: the installer puts a versioned build under
# ~/.local/share/claude/versions and points ~/.local/bin/claude at it, and Claude Code updates
# itself from there. This script therefore only covers the first install on a new machine.
#
set -euo pipefail

INSTALLER_URL="https://claude.ai/install.sh"
LOG="${TMPDIR:-/tmp}/install-claude.$$.log"

info() { printf '  %s\n' "$1"; }
fail() {
	printf 'FAILED: %s\n  log: %s\n' "$1" "$LOG" >&2
	exit 1
}

case "${1:-}" in
	-h | --help)
		sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
esac

if [[ "${1:-}" == "--check" ]]; then
	printf 'claude:   %s\n' "$(command -v claude || echo 'not installed')"
	printf 'version:  %s\n' "$(claude --version 2>/dev/null || echo '-')"
	exit 0
fi

FORCE=""
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
	shift
fi
TARGET="${1:-}"

if [[ -z "$FORCE" ]] && command -v claude >/dev/null; then
	info "Claude Code already installed: $(claude --version 2>/dev/null || echo 'version unknown')"
	info "It updates itself, so nothing to do. Use --force to install anyway."
	exit 0
fi

# Download first, then run the file, rather than piping the network straight into bash: a truncated
# download fails as a whole here instead of executing the half that arrived.
info "Downloading the installer from $INSTALLER_URL"
script="$(mktemp)"
trap 'rm -f "$script"' EXIT
curl -fsSL "$INSTALLER_URL" -o "$script" >"$LOG" 2>&1 || fail "could not download $INSTALLER_URL"
[[ -s "$script" ]] || fail "the downloaded installer is empty"

info "Running the installer${TARGET:+ for $TARGET}"
bash "$script" ${TARGET:+"$TARGET"} 2>&1 | tee -a "$LOG" || fail "the installer exited non-zero"

command -v claude >/dev/null || fail "installer finished but 'claude' is not on PATH (expected ~/.local/bin)"
info "Done: $(claude --version)"
info "Log: $LOG"
