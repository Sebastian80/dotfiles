#!/usr/bin/env bash
# ~/.bash/exports/bitwarden.bash
# Bitwarden SSH agent configuration
#
# Purpose:
#   Configure SSH to use Bitwarden as SSH agent for SSH key management.
#
# How it works:
#   - Bitwarden desktop app can act as an SSH agent
#   - Creates socket at ~/.bitwarden-ssh-agent.sock
#   - SSH client uses this socket via SSH_AUTH_SOCK
#
# Usage:
#   1. Enable SSH agent in Bitwarden desktop settings
#   2. Add SSH keys to Bitwarden vault
#   3. SSH will automatically use Bitwarden for authentication
#
# Note:
#   This replaces the need for ssh-agent or keychain.

# Configure SSH to use Bitwarden SSH agent
if [ -S "$HOME/.bitwarden-ssh-agent.sock" ]; then
    export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
fi
