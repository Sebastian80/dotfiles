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
#   The Bitwarden session token (BW_SESSION) is the key to the whole vault and
#   must never reach the agent's shell: with it, any command Claude runs could
#   dump every item. Claude only needs the derived tokens (GITLAB_TOKEN,
#   GITHUB_TOKEN, COMPOSER_AUTH), which bitwarden.bash exports separately.

claude() {
    env -u BW_SESSION claude "$@"
    local exit_code=$?
    tput reset 2>/dev/null
    return $exit_code
}
