#!/usr/bin/env bash
#
# plank-use-overrides.sh - Point Plank dock launchers at ~/.local desktop overrides.
#
# Usage:
#   plank-use-overrides.sh           Repoint launchers, restarting Plank if it runs
#   plank-use-overrides.sh --check   Report launchers that bypass an override, change nothing
#   plank-use-overrides.sh -h        This help
#
# Plank stores each launcher's desktop file by absolute path. A dock item created
# against /usr/share/applications/X.desktop keeps launching the system file after
# an override appears in ~/.local/share/applications, so every flag in the override
# is silently dropped for dock launches. Plank rewrites its item files while it
# runs, which is why it is stopped before editing and why the items are not stowed.
#
set -euo pipefail

LAUNCHERS="${XDG_CONFIG_HOME:-$HOME/.config}/plank/dock1/launchers"
OVERRIDES="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

case "${1:-}" in
	-h | --help)
		sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
esac

if [[ ! -d "$LAUNCHERS" ]]; then
	echo "No Plank launchers at $LAUNCHERS; nothing to do."
	exit 0
fi

stale=()
for item in "$LAUNCHERS"/*.dockitem; do
	[[ -e "$item" ]] || continue
	target=$(sed -n 's#^Launcher=file://##p' "$item")
	case "$target" in
		/usr/share/applications/*.desktop | /usr/local/share/applications/*.desktop) ;;
		*) continue ;;
	esac
	[[ -e "$OVERRIDES/$(basename "$target")" ]] && stale+=("$item")
done

if [[ ${#stale[@]} -eq 0 ]]; then
	echo "All Plank launchers already use their overrides."
	exit 0
fi

for item in "${stale[@]}"; do
	echo "bypasses override: $(basename "$item") -> $(sed -n 's#^Launcher=file://##p' "$item")"
done
[[ "${1:-}" == "--check" ]] && exit 1

running=false
if pgrep -x plank >/dev/null; then
	running=true
	pkill -x plank
	while pgrep -x plank >/dev/null; do sleep 0.2; done
fi

for item in "${stale[@]}"; do
	name=$(basename "$(sed -n 's#^Launcher=file://##p' "$item")")
	sed -i "s#^Launcher=file://.*/$name\$#Launcher=file://$OVERRIDES/$name#" "$item"
	echo "repointed: $(basename "$item") -> $OVERRIDES/$name"
done

if $running; then
	setsid plank >/dev/null 2>&1 &
	echo "Plank restarted."
fi
