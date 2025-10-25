#!/usr/bin/env bash
# ~/.bash/path
# PATH modifications for all shells
# Loaded by: .bash_profile and .bashrc

# Homebrew (must be first to prioritize brew packages)
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Add ~/.local/bin to PATH (if not already present)
case ":${PATH}:" in
    *:"$HOME/.local/bin":*)
        ;;
    *)
        # Prepending path in case a system-installed binary needs to be overridden
        export PATH="$HOME/.local/bin:$PATH"
        ;;
esac

# fnm (Fast Node Manager) - installed via Homebrew
# Initialize fnm for automatic Node.js version switching
if command -v fnm &>/dev/null; then
    eval "$(fnm env 2>/dev/null)"
fi

# Local bin directory (alternative location)
if [ -d "$HOME/bin" ]; then
    export PATH="$HOME/bin:$PATH"
fi
