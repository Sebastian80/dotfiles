#!/bin/bash
# Ghostty + Oh-My-Posh integration
# Enables oh-my-posh's built-in FTCS support and adds missing OSC sequences for Ghostty

# Only run in interactive mode
[[ "$-" != *i* ]] && return

# Initialize oh-my-posh first
eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/clean-detailed.omp.json)"

# Enable oh-my-posh's built-in FTCS marks (OSC 133 support)
# This is disabled by default, we enable it for Ghostty
_omp_ftcs_marks=1

# Wrap oh-my-posh's hook to add OSC 133;A (prompt start) and OSC 133;D (command end)
_omp_hook_original=$(declare -f _omp_hook)
eval "${_omp_hook_original/_omp_hook()/_omp_hook_original()}"

function _omp_hook() {
    local ret=$?

    # Mark end of previous command with exit code (OSC 133;D)
    if [[ -n "$_omp_start_time" ]]; then
        printf '\e]133;D;%s\a' "$ret"
    fi

    # Mark start of prompt (OSC 133;A)
    # Use k=s for multiline prompts to prevent erasure on resize
    printf '\e]133;A;k=s\a'

    # Report current working directory (OSC 7)
    printf '\e]7;file://%s%s\a' "$HOSTNAME" "$PWD"

    # Call original oh-my-posh hook
    _omp_hook_original

    # Return the original exit code
    return $ret
}

# Modify PS1 to add OSC 133;B at the end (marks ready for user input)
# We wrap the command substitution instead of replacing it
_omp_get_primary_original=$(declare -f _omp_get_primary)
eval "${_omp_get_primary_original/_omp_get_primary()/_omp_get_primary_original()}"

function _omp_get_primary() {
    local prompt
    prompt=$(_omp_get_primary_original)
    # Add OSC 133;B at the end to mark "ready for input"
    echo -n "${prompt}"
    printf '\[\e]133;B\a\]'
}

# PS0 already handled by oh-my-posh's _omp_ftcs_command_start (now that _omp_ftcs_marks=1)
