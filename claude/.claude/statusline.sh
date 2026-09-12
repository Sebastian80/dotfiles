#!/bin/bash

# Claude Code statusline in the Netresearch oh-my-posh look (netresearch.omp.json):
# a dark block with the [n] badge, path and git branch + change counts on the left, and a
# context bar ("▓░░░░░░░░░ 8%") right-aligned, colored by fill level, with the model
# dimmed on the line above it.
# Reads the statusLine JSON payload from stdin. Requires: jq, a Nerd Font.

# The bar and glyphs are multibyte; a UTF-8 locale makes ${#var} count characters for alignment.
export LC_ALL=C.UTF-8

input=$(cat)

IFS=$'\t' read -r model cwd used <<<"$(jq -r '
  [
    (.model.display_name // .model.id // "Claude"),
    (.workspace.current_dir // .cwd // ""),
    (.context_window.used_percentage // "" | tostring)
  ] | @tsv
' <<<"$input" 2>/dev/null)"

# "Opus 5 (1M context)" -> "Opus 5 (1M)"
model="${model/ context)/)}"

# Shorten $HOME to ~
dir="${cwd/#$HOME/\~}"

# One Dark palette from netresearch.omp.json (true color)
BG=$'\033[48;2;62;68;81m'          # #3e4451
FG_BLOCK=$'\033[38;2;62;68;81m'    # #3e4451, for the powerline arrow
FG_TEAL=$'\033[38;2;47;153;164m'   # #2F99A4
FG_LIGHT=$'\033[38;2;171;178;191m' # #abb2bf
FG_WHITE=$'\033[38;2;255;255;255m' # #ffffff
FG_YELLOW=$'\033[38;2;229;192;123m' # #e5c07b, working tree
FG_GREEN=$'\033[38;2;152;195;121m' # #98c379, staged
FG_PURPLE=$'\033[38;2;198;120;221m' # #c678dd, stash
FG_DIM=$'\033[38;2;127;132;142m'   # #7f848e, untracked
POWERLINE=$''   # Nerd Font right arrow, as in the omp theme
ICON_GITHUB=$'\uf09b' # Nerd Font icons for the repo host, picked from the origin remote
ICON_GITLAB=$'\uf296'
ICON_GIT=$'\ue725'
BOLD=$'\033[1m'
NOBOLD=$'\033[22m'
RESET=$'\033[0m'

# Each segment is appended twice: colored for output, plain for measuring visible width.
left="${BG}" left_plain=""
seg() { left+="$1"; left_plain+="$2"; }

seg "${FG_TEAL}${BOLD} [${FG_WHITE}n${FG_TEAL}] ${NOBOLD}" " [n] "
seg "${FG_LIGHT}${dir} " "${dir} "

# Git: host icon, branch, ahead/behind, file totals (● staged ✎ unstaged ? untracked), stash.
# A file with both staged and unstaged edits counts in both totals.
# One porcelain v2 call; --no-optional-locks keeps it from touching the index lock.
if [ -n "$cwd" ] && status=$(git -C "$cwd" --no-optional-locks status --porcelain=v2 --branch --show-stash 2>/dev/null); then
    IFS=$'\t' read -r head oid ahead behind stash staged unstaged untracked <<<"$(awk '
        /^# branch.head / { head = $3 }
        /^# branch.oid /  { oid = substr($3, 1, 7) }
        /^# branch.ab /   { ahead = substr($3, 2); behind = substr($4, 2) }
        /^# stash /       { stash = $3 }
        /^[12u] / {
            if (substr($2, 1, 1) != ".") staged++
            if (substr($2, 2, 1) != ".") unstaged++
        }
        /^\? / { untracked++ }
        END { printf "%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\n", head, oid, ahead, behind, stash, staged, unstaged, untracked }
    ' <<<"$status")"
    [ "$head" = "(detached)" ] && head="$oid"

    case "$(git -C "$cwd" config --get remote.origin.url)" in
        *github.com*)                  icon="$ICON_GITHUB" ;;
        *gitlab*|*git.netresearch.de*) icon="$ICON_GITLAB" ;;
        *)                             icon="$ICON_GIT" ;;
    esac
    seg "${FG_WHITE} ${icon} ${head}" " ${icon} ${head}"
    (( ahead > 0 )) && seg " ⇡ ${ahead}" " ⇡ ${ahead}"
    (( behind > 0 )) && seg " ⇣ ${behind}" " ⇣ ${behind}"
    (( staged > 0 )) && seg " ${FG_GREEN}● ${staged}" " ● ${staged}"
    (( unstaged > 0 )) && seg " ${FG_YELLOW}✎ ${unstaged}" " ✎ ${unstaged}"
    (( untracked > 0 )) && seg " ${FG_DIM}? ${untracked}" " ? ${untracked}"
    (( stash > 0 )) && seg " ${FG_PURPLE}≡ ${stash}" " ≡ ${stash}"
    seg " " " "
fi

seg "${RESET}${FG_BLOCK}${POWERLINE}${RESET}" "${POWERLINE}"

# Right-align using the width Claude Code passes in COLUMNS. MARGIN leaves room for the
# TUI's own row padding (2 cells each side); anything wider gets cut off with "…".
MARGIN=4

# First line: the model, dimmed and right-aligned so it sits above the context bar.
pad=$(( ${COLUMNS:-0} - MARGIN - ${#model} ))
(( pad < 1 )) && pad=1
# Starts with the color code: Claude Code trims leading whitespace, which would drop the padding.
printf '%s%*s%s\n' "$FG_DIM" "$pad" "" "${model}${RESET}"

if [ -z "$used" ]; then
    printf '%s\n' "$left"
    exit 0
fi

# Right: 10-cell context bar, one cell per 10% (rounded), colored by fill level.
pct=${used%%.*}
filled=$(( (pct + 5) / 10 ))
(( filled > 10 )) && filled=10
(( filled < 0 )) && filled=0
bar=""
for (( i = 0; i < 10; i++ )); do
    if (( i < filled )); then bar+="▓"; else bar+="░"; fi
done

if (( pct >= 80 )); then
    ctx_color=$'\033[31m'
elif (( pct >= 50 )); then
    ctx_color=$'\033[33m'
else
    ctx_color=$'\033[32m'
fi
right_plain="${bar} ${pct}%"
right="${ctx_color}${right_plain}${RESET}"

pad=$(( ${COLUMNS:-0} - MARGIN - ${#left_plain} - ${#right_plain} ))
(( pad < 1 )) && pad=1
printf '%s%*s%s\n' "$left" "$pad" "" "$right"
