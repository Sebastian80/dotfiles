#!/usr/bin/env bash
# ~/.bash/completions/ripgrep.bash
# Lazy-loading completion for ripgrep (rg)
#
# Uses ripgrep's built-in completion generator: rg --generate complete-bash
# Lazy-loaded to avoid ~50ms startup cost

_lazy_rg_completion() {
    # Check if rg is available
    if ! command -v rg &>/dev/null; then
        return
    fi

    # Load the real completion from ripgrep
    eval "$(rg --generate complete-bash 2>/dev/null)"

    # Tell bash to retry completion with the newly loaded function
    return 124
}

# Only set up lazy completion if rg exists and no completion is registered
if command -v rg &>/dev/null && ! complete -p rg &>/dev/null 2>&1; then
    complete -F _lazy_rg_completion rg
fi
