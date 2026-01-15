#!/usr/bin/env bash
# ~/.bash/path
# PATH modifications for all shells
# Loaded by: .bash_profile and .bashrc

# Helper: add to PATH only if not already present
__prepend_path() {
    case ":${PATH}:" in
        *:"$1":*) ;;
        *) export PATH="$1:$PATH" ;;
    esac
}

# Homebrew (must be first to prioritize brew packages)
# Only initialize if not already in PATH (prevents duplicates on nested shells)
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    case ":${PATH}:" in
        *:/home/linuxbrew/.linuxbrew/bin:*) ;;
        *)
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            ;;
    esac
    # Always export HOMEBREW_PREFIX for use in other scripts
    export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
fi

# Add ~/.local/bin to PATH (if not already present)
__prepend_path "$HOME/.local/bin"

# fnm (Fast Node Manager) - installed via Homebrew
# Only initialize if FNM_MULTISHELL_PATH not set (prevents duplicates)
if command -v fnm &>/dev/null && [ -z "$FNM_MULTISHELL_PATH" ]; then
    eval "$(fnm env 2>/dev/null)"
fi

# Local bin directory (alternative location)
if [ -d "$HOME/bin" ]; then
    __prepend_path "$HOME/bin"
fi

unset -f __prepend_path
