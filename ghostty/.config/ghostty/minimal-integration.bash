#!/bin/bash
# Minimal Ghostty integration for oh-my-posh
# Adds back essential features without conflicting with PROMPT_COMMAND

# Debug: Uncomment to see if this script runs
# echo "DEBUG: Loading minimal-integration.bash"

# Only run in Ghostty
[[ -z "$GHOSTTY_RESOURCES_DIR" && ! -f /usr/bin/ghostty ]] && return

# ========================================
# 1. Sudo wrapper - Preserve TERMINFO
# ========================================
function sudo() {
    builtin local sudo_has_sudoedit_flags="no"
    for arg in "$@"; do
        if [[ "$arg" == "-e" || "$arg" == "--edit" ]]; then
            sudo_has_sudoedit_flags="yes"
            builtin break
        fi
        if [[ "$arg" != -* && "$arg" != *=* ]]; then
            builtin break
        fi
    done

    if [[ "$sudo_has_sudoedit_flags" == "yes" ]]; then
        builtin command sudo "$@"
    elif [[ -n "$TERMINFO" ]]; then
        # Only pass TERMINFO if it's set
        builtin command sudo TERMINFO="$TERMINFO" "$@"
    else
        builtin command sudo "$@"
    fi
}

# ========================================
# 2. SSH wrapper - Handle terminfo
# ========================================
function ssh() {
    # Use xterm-256color for SSH (widely compatible)
    TERM="xterm-256color" builtin command ssh "$@"
}

# ========================================
# 3. Working Directory Tracking (OSC 7)
# ========================================
_ghostty_report_cwd() {
    # Report current directory to Ghostty
    printf '\e]7;file://%s%s\a' "$HOSTNAME" "$PWD"
}

# ========================================
# 4. Wrap oh-my-posh hook for OSC sequences
# ========================================
if declare -f _omp_hook &>/dev/null; then
    # Save original oh-my-posh hook
    eval "$(declare -f _omp_hook | sed '1s/_omp_hook/_omp_hook_original/')"

    function _omp_hook() {
        local ret=$?

        # OSC 133;D - Mark end of previous command with exit code
        if [[ -n "$_omp_start_time" ]]; then
            printf '\e]133;D;%s\a' "$ret"
        fi

        # OSC 133;A - Mark start of prompt (k=s for multiline)
        printf '\e]133;A;k=s\a'

        # OSC 7 - Report working directory
        _ghostty_report_cwd

        # Call original oh-my-posh hook (generates PS1)
        _omp_hook_original

        # OSC 133;B - Append "ready for input" marker to PS1
        PS1="${PS1}\[\e]133;B\a\]"

        return $ret
    }
fi
