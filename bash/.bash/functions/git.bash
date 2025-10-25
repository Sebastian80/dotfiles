#!/usr/bin/env bash
# ~/.bash/functions/git.bash
# Git helper functions
#
# Purpose:
#   Convenient shortcuts for common Git operations.
#   Reduces typing for frequent workflows.
#
# Functions:
#   clone - Clone repository and cd into it
#   gcm   - Git commit with message
#   gac   - Git add all and commit

# Clone repository and cd into it
# Automatically extracts directory name from URL and enters it
# Usage: clone <git_url> [additional_git_clone_args]
# Examples:
#   clone https://github.com/user/repo.git
#   clone git@github.com:user/repo.git
#   clone https://github.com/user/repo.git --depth 1
clone() {
    if [ -z "$1" ]; then
        echo "Usage: clone <git_url>"
        return 1
    fi
    git clone "$@" && cd "$(basename "$1" .git)" || return
}

# Git commit with message
# Quick commit without staging (assumes you already staged with 'git add')
# Usage: gcm <commit_message>
# Example: gcm "Fix bug in authentication"
gcm() {
    if [ -z "$1" ]; then
        echo "Usage: gcm <commit_message>"
        return 1
    fi
    git commit -m "$@"
}

# Git add all and commit
# Stages all changes and commits in one command
# Usage: gac <commit_message>
# Example: gac "Update documentation"
gac() {
    if [ -z "$1" ]; then
        echo "Usage: gac <commit_message>"
        return 1
    fi
    git add -A && git commit -m "$@"
}
