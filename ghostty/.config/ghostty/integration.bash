#!/bin/bash
# Simple Ghostty integration - Always loads, no guards

# Sudo wrapper - Preserves TERMINFO if set
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
        builtin command sudo TERMINFO="$TERMINFO" "$@"
    else
        builtin command sudo "$@"
    fi
}

# SSH wrapper - Use xterm-256color for compatibility
function ssh() {
    TERM="xterm-256color" builtin command ssh "$@"
}

# Working directory tracking (OSC 7) - for new tab inheritance
_ghostty_report_cwd() {
    # Report current directory to Ghostty
    printf '\e]7;file://%s%s\a' "$HOSTNAME" "$PWD"
}

# Wrap oh-my-posh's _omp_hook to add OSC 7 reporting
if declare -f _omp_hook &>/dev/null; then
    # Save original oh-my-posh hook
    eval "$(declare -f _omp_hook | sed '1s/_omp_hook/_omp_hook_original/')"

    function _omp_hook() {
        # Report current directory BEFORE oh-my-posh generates the prompt
        _ghostty_report_cwd

        # Call original oh-my-posh hook
        _omp_hook_original
    }
fi
