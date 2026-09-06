#!/bin/bash
# Snapshot everything a fresh install cannot regenerate onto an external disk.
#
# Usage: pre-reinstall-backup.sh [--dry-run] <dest-dir>
#
#   <dest-dir>  Mounted, encrypted external disk (ext4 on LUKS; exFAT loses
#               permissions and symlinks). The script owns <dest-dir>/home,
#               <dest-dir>/system and <dest-dir>/lists and keeps them in sync
#               on re-runs (deleted-at-source files disappear from the copy).
#   --dry-run   Show transfer stats only, write nothing.
#
# What it copies:
#   home/    $HOME minus caches, Trash, Ollama models, package-manager stores,
#            IDE binaries and snap runtime dirs (Thunderbird profile kept).
#   system/  root-owned config: NetworkManager connections (VPN, WiFi PSKs),
#            /etc/hosts, grub kernel params, custom AppArmor/modprobe/sysctl,
#            local CA certs, apt sources + keyrings. Needs sudo once.
#   lists/   package inventories (apt, snap, flatpak, brew, fnm, npm) and
#            exported VPN profiles, for re-installing by hand.
#
# Close Chrome, PhpStorm and Thunderbird first: files they rewrite during the
# run show up in the verification pass as "changed after copy".
#
# Full rsync output goes to <dest-dir>/logs/; the terminal shows one line per
# step, the verification result and the exit code.

set -euo pipefail

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; }

DRY_RUN=0
DEST=""
for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        --dry-run) DRY_RUN=1 ;;
        -*) echo "unknown option: $arg" >&2; usage >&2; exit 2 ;;
        *) DEST="$arg" ;;
    esac
done

if [[ -z "$DEST" ]]; then usage >&2; exit 2; fi
if [[ ! -d "$DEST" ]]; then echo "not a directory: $DEST" >&2; exit 2; fi
if ! mountpoint -q "$DEST" && ! mountpoint -q "$(dirname "$DEST")"; then
    echo "warning: $DEST is not on a mounted volume, is the external disk attached?" >&2
fi

STAMP=$(date +%Y%m%d-%H%M%S)
LOG_DIR="$DEST/logs"
RSYNC_LOG="$LOG_DIR/home-$STAMP.log"
VERIFY_LOG="$LOG_DIR/verify-$STAMP.log"

step() { printf '\033[0;34m→\033[0m %s\n' "$1"; }
ok()   { printf '\033[0;32m✓\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m⚠\033[0m %s\n' "$1"; }

# Paths relative to $HOME that a fresh install regenerates.
EXCLUDES=(
    '.cache/'
    '.local/share/Trash/'
    '.ollama/'
    '.local/share/fnm/'
    '.local/share/pnpm/'
    '.local/share/uv/'
    '.local/share/pipx/'
    '.local/share/JetBrains/Toolbox/apps/'
    '.npm/'
    '.yarn/'
    '.var/app/*/cache/'
    '.claude/debug/'
    '.claude/shell-snapshots/'
    '.claude/paste-cache/'
    '.claude.json.tmp.*'
    '.claude/hook-approvals.log*'
    'snap/*/common/.cache/'
    'snap/core*/'
    'snap/bare/'
    'snap/gnome-*/'
    'snap/gtk-*/'
    'snap/icon-theme-*/'
    'snap/mesa-*/'
    'snap/snapd*/'
    'snap/snap-store/'
    'snap/ubuntu-budgie-welcome/'
    '.xsession-errors*'
    '.Xauthority'
)
RSYNC_EXCLUDES=()
for e in "${EXCLUDES[@]}"; do RSYNC_EXCLUDES+=(--exclude="$e"); done

RSYNC_BASE=(rsync -aH --delete --delete-excluded "${RSYNC_EXCLUDES[@]}")

# ---------------------------------------------------------------- dry run
if [[ $DRY_RUN -eq 1 ]]; then
    step "Dry run: transfer statistics for $HOME → $DEST/home"
    "${RSYNC_BASE[@]}" --dry-run --stats "$HOME/" "$DEST/home/" \
        | grep -E 'Number of (regular )?files|Total (transferred )?file size'
    exit 0
fi

mkdir -p "$DEST/home" "$DEST/system" "$DEST/lists" "$LOG_DIR"

# ---------------------------------------------------------------- inventories
step "Writing package and tool inventories to $DEST/lists"
apt-mark showmanual            > "$DEST/lists/apt-manual.txt"
dpkg --get-selections          > "$DEST/lists/dpkg-selections.txt"
snap list 2>/dev/null          > "$DEST/lists/snap.txt" || true
flatpak list --app --columns=application,origin 2>/dev/null > "$DEST/lists/flatpak.txt" || true
brew bundle dump --force --file="$DEST/lists/Brewfile.live" 2>/dev/null || warn "brew bundle dump failed"
fnm ls 2>/dev/null             > "$DEST/lists/fnm.txt" || true
npm ls -g --depth=0 2>/dev/null > "$DEST/lists/npm-global.txt" || true
uv tool list 2>/dev/null       > "$DEST/lists/uv-tools.txt" || true
systemctl --user list-unit-files --state=enabled --no-legend 2>/dev/null > "$DEST/lists/systemd-user-enabled.txt" || true
ls "$HOME/.config/JetBrains"   > "$DEST/lists/jetbrains-versions.txt" 2>/dev/null || true
nmcli -t -f NAME,TYPE connection show > "$DEST/lists/nm-connections.txt" 2>/dev/null || true
ok "inventories written"

step "Exporting VPN profiles"
mkdir -p "$DEST/lists/vpn"
while IFS=: read -r name type; do
    [[ "$type" == "vpn" ]] || continue
    if nmcli connection export "$name" "$DEST/lists/vpn/$name.ovpn" 2>>"$LOG_DIR/vpn-export-$STAMP.log"; then
        ok "exported $name"
    else
        warn "export failed for $name (system-connections copy below still has it)"
    fi
done < "$DEST/lists/nm-connections.txt"

# ---------------------------------------------------------------- home
step "Syncing $HOME → $DEST/home (log: $RSYNC_LOG)"
# Exit 23 = partial transfer: typically root-owned Docker bind-mount data under
# the workspace. Those are container state, not ours to keep; report and go on.
RSYNC_RC=0
"${RSYNC_BASE[@]}" --info=progress2 --log-file="$RSYNC_LOG" "$HOME/" "$DEST/home/" || RSYNC_RC=$?
case $RSYNC_RC in
    0)  ok "home synced" ;;
    23) warn "home synced except unreadable paths:"
        grep -E 'failed:|Permission denied' "$RSYNC_LOG" | sed 's/^.*rsync: /  /' | head -20 ;;
    *)  echo "rsync failed with exit $RSYNC_RC, see $RSYNC_LOG" >&2; exit "$RSYNC_RC" ;;
esac

# ---------------------------------------------------------------- system
step "Copying root-owned system config to $DEST/system (sudo)"
SYSTEM_PATHS=(
    /etc/NetworkManager/system-connections
    /etc/hosts
    /etc/default/grub
    /etc/apparmor.d/bwrap-userns
    /etc/modprobe.d/audio-power.conf
    /etc/sysctl.d
    /etc/sudoers.d
    /etc/udev/rules.d
    /etc/apt/sources.list.d
    /etc/apt/keyrings
    /usr/share/keyrings
    /usr/local/share/ca-certificates
    /etc/docker
    /etc/wireguard
)
sudo -v
for p in "${SYSTEM_PATHS[@]}"; do
    if sudo test -e "$p"; then
        sudo rsync -a --relative "$p" "$DEST/system/"
    fi
done
sudo chown -R "$(id -u):$(id -g)" "$DEST/system"
ok "system config copied"

# ---------------------------------------------------------------- verify
step "Verifying: second pass must transfer nothing"
"${RSYNC_BASE[@]}" --dry-run --itemize-changes "$HOME/" "$DEST/home/" 2>"$VERIFY_LOG.stderr" \
    | grep -vE '^\.d\.\.t' > "$VERIFY_LOG" || true
CHANGED=$(wc -l < "$VERIFY_LOG")

echo
du -sh "$DEST/home" "$DEST/system" "$DEST/lists" 2>/dev/null
if [[ "$CHANGED" -eq 0 ]]; then
    ok "backup complete and verified: $DEST"
    exit 0
fi
warn "$CHANGED entries changed while copying (see $VERIFY_LOG). Close running apps and re-run; re-runs are incremental."
head -20 "$VERIFY_LOG"
exit 3
