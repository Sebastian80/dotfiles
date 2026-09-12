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
#   Nothing credential-shaped reaches the agent. BW_SESSION is the key to the whole
#   vault, and the derived tokens are scrubbed too: a command that can read an env
#   var can print it into a transcript, and nothing can redact it afterwards
#   (PostToolUse runs after the result is already written and cannot modify it).
#   Verified 2026-09-12: gh and glab both authenticate from the OS keyring without
#   GITHUB_TOKEN / GITLAB_TOKEN, so this costs no capability.
#
#   This launcher is the only control point that works. A guard in bitwarden.bash
#   cannot unset what the shell already inherited, and .bashrc is not even sourced
#   for the agent's non-interactive tool shells ($- has no 'i').

claude() {
    env -u BW_SESSION -u GITHUB_TOKEN -u GITLAB_TOKEN -u COMPOSER_AUTH claude "$@"
    local exit_code=$?
    tput reset 2>/dev/null
    return $exit_code
}
