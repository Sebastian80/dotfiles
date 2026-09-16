#!/usr/bin/env bash
# ~/.bash/functions/claude.bash
# Claude Code terminal cleanup wrapper
#
# Purpose:
#   Work around Claude Code TUI cleanup bug (anthropics/claude-code#39294)
#   where status line content and autocomplete suggestions leak into the
#   terminal after /exit.
#
# Functions:
#   claude - Wrapper that resets terminal state after Claude Code exits
#
# Secrets:
#   BW_SESSION is the key to the whole vault and never reaches the agent. The derived
#   tokens are scrubbed too wherever that costs no capability: a command that can read
#   an env var can print it into a transcript, and nothing can redact it afterwards
#   (PostToolUse runs after the result is already written and cannot modify it).
#   gh and glab authenticate from the OS keyring without GITHUB_TOKEN / GITLAB_TOKEN
#   (verified 2026-09-12), so those two go.
#
#   COMPOSER_AUTH stays. The Docker toolboxes receive it by env pass-through and have
#   no keyring to fall back on; without it `composer install` inside the container
#   runs unauthenticated, the internal Satis answers with the GitLab sign-in page and
#   dist downloads fail with "Invalid credentials". Never echo it; assert on its length.
#
#   This launcher is the only control point that works. A guard in bitwarden.bash
#   cannot unset what the shell already inherited, and .bashrc is not even sourced
#   for the agent's non-interactive tool shells ($- has no 'i').

claude() {
    env -u BW_SESSION -u GITHUB_TOKEN -u GITLAB_TOKEN claude "$@"
    local exit_code=$?
    tput reset 2>/dev/null
    return $exit_code
}
