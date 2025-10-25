#!/usr/bin/env bash
# ~/.bash/exports/colors.bash
# Terminal colors and pager configuration
#
# Purpose:
#   Configure colors for less (pager) and enable colored output for various tools.
#   Makes man pages and command output more readable with syntax highlighting.
#
# Variables:
#   LESS           - Options for the less pager
#   LESS_TERMCAP_* - Colors for man pages in less

# Less pager options
#   -F: Quit if output fits on one screen
#   -g: Highlight only last searched string
#   -i: Case-insensitive searches (unless uppercase used)
#   -M: Verbose prompt with percentage
#   -R: Allow ANSI color escape sequences
#   -S: Chop long lines instead of wrapping
#   -w: Highlight first unread line on new page
#   -X: Don't clear screen on exit
#   -z-4: Keep 4 lines when scrolling
export LESS='-F -g -i -M -R -S -w -X -z-4'

# Colored man pages using ANSI escape codes
export LESS_TERMCAP_mb=$'\E[1;31m'      # Begin bold (red)
export LESS_TERMCAP_md=$'\E[1;36m'      # Begin blink (cyan)
export LESS_TERMCAP_me=$'\E[0m'         # Reset bold/blink
export LESS_TERMCAP_so=$'\E[01;44;33m'  # Begin reverse video (yellow on blue)
export LESS_TERMCAP_se=$'\E[0m'         # Reset reverse video
export LESS_TERMCAP_us=$'\E[1;32m'      # Begin underline (green)
export LESS_TERMCAP_ue=$'\E[0m'         # Reset underline

# Enable lesspipe for better file viewing (if available)
# Allows less to view archives, PDFs, images, etc.
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# dircolors - color setup for ls
# Use custom color scheme if ~/.dircolors exists, otherwise use system default
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi
