#!/usr/bin/env bash
# ~/.bash/exports/history.bash
# Bash history configuration
#
# Purpose:
#   Control how bash saves and manages command history.
#   Optimized for useful history without clutter.
#
# Variables:
#   HISTSIZE       - Number of commands to keep in memory
#   HISTFILESIZE   - Number of commands to keep in history file
#   HISTCONTROL    - Control what gets saved
#   HISTIGNORE     - Patterns of commands to never save
#   HISTTIMEFORMAT - Timestamp format for history entries

# History size limits
export HISTSIZE=10000            # Keep 10,000 commands in memory
export HISTFILESIZE=20000        # Keep 20,000 commands in ~/.bash_history file

# History control
#   ignoreboth = ignore lines starting with space + ignore duplicates
#   erasedups  = remove all previous duplicates of current command
export HISTCONTROL=ignoreboth:erasedups

# Ignore common commands that clutter history
export HISTIGNORE="ls:ll:cd:pwd:exit:clear:history"

# Add timestamp to history (format: YYYY-MM-DD HH:MM:SS)
export HISTTIMEFORMAT="%F %T "
