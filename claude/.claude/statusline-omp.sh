#!/bin/bash

# Oh My Posh style statusline for Claude Code
# Uses One Dark palette from netresearch.omp.json
# Requires: Nerd Font, jq

input=$(cat)

# Parse JSON
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "~"')

# Show ~ for home, or ~/path format
if [ "$cwd" = "$HOME" ]; then
    dir_name="~"
elif [ -n "$cwd" ] && [ "$cwd" != "null" ]; then
    dir_name="${cwd/#$HOME/\~}"
else
    dir_name="~"
fi

context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_tokens=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

# Calculate context usage
total_tokens=$((input_tokens + cache_tokens))
percent=$((total_tokens * 100 / context_size))

# Format as K (e.g., 190K/200K)
tokens_k=$((total_tokens / 1000))
context_k=$((context_size / 1000))

# Git info
branch=""
git_status=""
git_icon=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
            git_icon=" ●"
        else
            git_icon=" ✓"
        fi
        ahead=$(git -C "$cwd" rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
        behind=$(git -C "$cwd" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
        [ "$ahead" -gt 0 ] 2>/dev/null && git_status+=" ⇡$ahead"
        [ "$behind" -gt 0 ] 2>/dev/null && git_status+=" ⇣$behind"
    fi
fi

# Powerline separator
SEP=""

# One Dark palette (true color)
# Background
BG_DARK="\033[48;2;62;68;81m"      # #3e4451
BG_TEAL="\033[48;2;47;153;164m"    # #2F99A4
BG_GREEN="\033[48;2;152;195;121m"  # #98c379
BG_YELLOW="\033[48;2;229;192;123m" # #e5c07b
BG_RED="\033[48;2;224;108;117m"    # #e06c75
BG_PURPLE="\033[48;2;198;120;221m" # #c678dd

# Foreground
FG_LIGHT="\033[38;2;171;178;191m"  # #abb2bf
FG_WHITE="\033[38;2;255;255;255m"  # #ffffff
FG_DARK="\033[38;2;62;68;81m"      # #3e4451
FG_TEAL="\033[38;2;47;153;164m"    # #2F99A4
FG_GREEN="\033[38;2;152;195;121m"  # #98c379
FG_YELLOW="\033[38;2;229;192;123m" # #e5c07b
FG_RED="\033[38;2;224;108;117m"    # #e06c75
FG_PURPLE="\033[38;2;198;120;221m" # #c678dd

BOLD="\033[1m"
RESET="\033[0m"

# Context color based on usage
if [ "$percent" -lt 50 ]; then
    CTX_BG="$BG_GREEN"
    CTX_FG="$FG_GREEN"
elif [ "$percent" -lt 80 ]; then
    CTX_BG="$BG_YELLOW"
    CTX_FG="$FG_YELLOW"
else
    CTX_BG="$BG_RED"
    CTX_FG="$FG_RED"
fi

output=""

# All segments on same dark background, matching Oh My Posh style
# Segment 1: Claude branding [n] (teal brackets, white n)
output+="${BG_DARK}${FG_TEAL}${BOLD} [${FG_WHITE}n${FG_TEAL}] ${RESET}"

# Segment 2: Directory (light text)
output+="${BG_DARK}${FG_LIGHT}${dir_name} ${RESET}"

# Segment 3: Git branch (if in repo) - GitHub icon + branch
if [ -n "$branch" ]; then
    output+="${BG_DARK}${FG_WHITE}  $branch${RESET}"
    output+="${BG_DARK}${FG_YELLOW}${git_icon}${git_status} ${RESET}"
fi

# Segment 4: Model (teal text, matching branding color)
output+="${BG_DARK}${FG_TEAL}${BOLD}  $model ${RESET}"

# Segment 5: Context usage (color-coded text) - e.g., 190K/200K (95%)
output+="${BG_DARK}${CTX_FG}${BOLD}󰍛 ${tokens_k}K/${context_k}K (${percent}%) ${RESET}"

# Single powerline separator at end
output+="${FG_DARK}${SEP}${RESET}"

printf "%b\n" "$output"
