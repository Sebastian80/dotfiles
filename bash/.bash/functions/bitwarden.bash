#!/usr/bin/env bash
# ~/.bash/functions/bitwarden.bash
# Bitwarden CLI integration and secrets management
#
# Purpose:
#   Enhanced Bitwarden CLI with convenient shortcuts and automatic secret loading.
#   Overrides the official 'bw' command with additional functionality while
#   maintaining full compatibility via pass-through for all original commands.
#
# Architecture:
#   - Session stored in tmpfs (/run/user/$UID/bw-session)
#   - Auto-cleared on logout/reboot (tmpfs is memory-only)
#   - Tokens cached in tmpfs for instant access across all terminals
#   - One unlock per login session, shared across all terminals
#
# Functions:
#   load_bw_secrets - Load development secrets from Bitwarden into environment
#   bw              - Enhanced Bitwarden CLI with shortcuts
#
# Storage:
#   All sensitive data stored in tmpfs (RAM-only, auto-cleared):
#     /run/user/$UID/bw-session       - Bitwarden session token
#     /run/user/$UID/bw-github-token  - GitHub personal access token
#     /run/user/$UID/bw-gitlab-token  - GitLab access token
#     /run/user/$UID/bw-composer-auth - Composer auth JSON (github-oauth + gitlab-token)

# ============================================
# Auto-load Bitwarden Session
# ============================================

# Auto-load Bitwarden session and tokens from tmpfs if available
# This allows all terminals to share the same session without re-unlocking
if command -v bw &>/dev/null; then
    # Cache user ID to avoid multiple calls
    _BW_RUNDIR="/run/user/${UID:-$(id -u)}"

    # Load session and tokens if available
    [[ -f "$_BW_RUNDIR/bw-session" ]] && export BW_SESSION=$(command cat "$_BW_RUNDIR/bw-session")
    [[ -f "$_BW_RUNDIR/bw-github-token" ]] && export GITHUB_TOKEN=$(command cat "$_BW_RUNDIR/bw-github-token")
    if [[ -f "$_BW_RUNDIR/bw-gitlab-token" ]]; then
        export GITLAB_TOKEN=$(command cat "$_BW_RUNDIR/bw-gitlab-token")
        export GITLAB_HOST="git.netresearch.de"  # Self-hosted GitLab instance
    fi
    [[ -f "$_BW_RUNDIR/bw-composer-auth" ]] && export COMPOSER_AUTH=$(command cat "$_BW_RUNDIR/bw-composer-auth")

    # Auto-prompt for unlock in interactive shells (only if vault is locked)
    if [[ $- == *i* ]] && [[ -z "$BW_SESSION" ]]; then
        # Check if vault is locked
        _bw_status=$(command bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        if [[ "$_bw_status" == "locked" ]]; then
            echo ""
            echo "🔒 Bitwarden vault is locked"
            echo "💡 Run 'bw unlock' to load development secrets"
            echo ""
        fi
        unset _bw_status
    fi

    unset _BW_RUNDIR
fi

# ============================================
# Bitwarden Functions
# ============================================

# Load development secrets from Bitwarden into environment variables
# Fetches API tokens and credentials from Bitwarden and exports them.
# Also saves them to tmpfs for instant loading in new terminals.
#
# Prerequisites:
#   - Bitwarden CLI must be installed (bw command)
#   - Vault must be unlocked (BW_SESSION must be set)
#   - jq must be installed for JSON parsing
#
# Tokens loaded:
#   GITHUB_TOKEN   - From item: db6b3004-7194-4175-b4ff-b37f00ea56ad (Github)
#                    Used by: gh CLI, Composer (via COMPOSER_AUTH)
#   GITLAB_TOKEN   - From item: 8cff5d6b-ba18-484b-add5-b37f00f82acc (Gitlab)
#                    Used by: glab CLI, Composer (via COMPOSER_AUTH)
#   COMPOSER_AUTH  - Generated from GitHub + GitLab + Magento tokens in proper JSON format
#                    Format: {"github-oauth":{...},"gitlab-token":{...},"http-basic":{"repo.magento.com":{...}}}
#
# Usage:
#   load_bw_secrets         # Load and display status
#   load_bw_secrets --quiet # Load silently
#
# Note: This function is automatically called by 'bw unlock'
load_bw_secrets() {
    local quiet=false
    if [[ "$1" == "--quiet" ]]; then
        quiet=true
    fi

    # Check if bw is available
    if ! command -v bw &>/dev/null; then
        [[ "$quiet" == false ]] && echo "⚠ Bitwarden CLI not installed"
        return 1
    fi

    # Check if logged in and unlocked
    local status=$(command bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [[ "$status" != "unlocked" ]]; then
        [[ "$quiet" == false ]] && echo "⚠ Bitwarden is locked. Please unlock first with: bw unlock"
        return 1
    fi

    # GitHub token (from custom field "Token" in "Github" item)
    # Accepts both "token" and "Token" field names for flexibility
    local github_token=$(command bw get item db6b3004-7194-4175-b4ff-b37f00ea56ad 2>/dev/null | jq -r '.fields[]? | select(.name == "token" or .name == "Token") | .value' 2>/dev/null)
    if [[ -n "$github_token" && "$github_token" != "null" ]]; then
        export GITHUB_TOKEN="$github_token"
        echo "$github_token" > "/run/user/$(id -u)/bw-github-token"
        chmod 600 "/run/user/$(id -u)/bw-github-token"
        [[ "$quiet" == false ]] && echo "   🔑 GITHUB_TOKEN loaded"
    fi

    # GitLab token (from custom field "token" in "Gitlab" item)
    local gitlab_token=$(command bw get item 8cff5d6b-ba18-484b-add5-b37f00f82acc 2>/dev/null | jq -r '.fields[]? | select(.name == "token" or .name == "Token") | .value' 2>/dev/null)
    if [[ -n "$gitlab_token" && "$gitlab_token" != "null" ]]; then
        export GITLAB_TOKEN="$gitlab_token"
        echo "$gitlab_token" > "/run/user/$(id -u)/bw-gitlab-token"
        chmod 600 "/run/user/$(id -u)/bw-gitlab-token"
        [[ "$quiet" == false ]] && echo "   🔑 GITLAB_TOKEN loaded"
    fi

    # Magento repo credentials (from "Magento Repository Access" item)
    local magento_item=$(command bw get item f8192a75-1052-4038-b7b5-aee4007a9051 2>/dev/null)
    local magento_user=$(echo "$magento_item" | jq -r '.login.username // empty' 2>/dev/null)
    local magento_pass=$(echo "$magento_item" | jq -r '.login.password // empty' 2>/dev/null)
    if [[ -n "$magento_user" && -n "$magento_pass" ]]; then
        [[ "$quiet" == false ]] && echo "   🔑 Magento repo credentials loaded"
    fi

    # Composer auth (generated from GitHub + GitLab + Magento tokens)
    # Build proper Composer auth.json format
    local has_composer_auth=false
    if [[ -n "$github_token" && "$github_token" != "null" ]] || \
       [[ -n "$gitlab_token" && "$gitlab_token" != "null" ]] || \
       [[ -n "$magento_user" && -n "$magento_pass" ]]; then
        has_composer_auth=true
    fi

    if [[ "$has_composer_auth" == true ]]; then
        local composer_auth='{'

        # Add GitHub OAuth if token exists
        if [[ -n "$github_token" && "$github_token" != "null" ]]; then
            composer_auth+='"github-oauth":{"github.com":"'"$github_token"'"}'
        fi

        # Add GitLab token if exists (self-hosted only)
        if [[ -n "$gitlab_token" && "$gitlab_token" != "null" ]]; then
            [[ "$composer_auth" != '{' ]] && composer_auth+=','
            composer_auth+='"gitlab-token":{'
            # Use self-hosted GitLab domain if GITLAB_HOST is set, otherwise default to gitlab.com
            if [[ -n "$GITLAB_HOST" ]]; then
                composer_auth+='"'"$GITLAB_HOST"'":"'"$gitlab_token"'"'
            else
                composer_auth+='"gitlab.com":"'"$gitlab_token"'"'
            fi
            composer_auth+='}'
        fi

        # Add Magento repo http-basic auth if credentials exist
        if [[ -n "$magento_user" && -n "$magento_pass" ]]; then
            [[ "$composer_auth" != '{' ]] && composer_auth+=','
            composer_auth+='"http-basic":{"repo.magento.com":{"username":"'"$magento_user"'","password":"'"$magento_pass"'"}}'
        fi

        composer_auth+='}'

        export COMPOSER_AUTH="$composer_auth"
        echo "$composer_auth" > "/run/user/$(id -u)/bw-composer-auth"
        chmod 600 "/run/user/$(id -u)/bw-composer-auth"
        [[ "$quiet" == false ]] && echo "   📦 COMPOSER_AUTH loaded (GitHub + GitLab + Magento)"
    fi

    if [[ "$quiet" == false ]]; then
        echo ""
        echo "✅ Development secrets loaded and saved to tmpfs"
    fi
}

# Bitwarden CLI with enhanced shortcuts
# Overrides the official 'bw' command to provide convenient shortcuts
# while maintaining full compatibility with all original commands.
#
# How it works:
#   - Shortcut commands (get, copy, unlock, etc.) are handled by this function
#   - All other commands are passed through to the original 'bw' CLI
#   - Original CLI available via: command bw <args>
#
# Shortcut Commands:
#   bw unlock|u              - Unlock vault, save session, load all secrets
#   bw lock                  - Lock vault and clear all cached data
#   bw get|g <name>          - Get password for item (clean output)
#   bw copy|c <name>         - Copy password to clipboard
#   bw search|find|f <text>  - Search items by name
#   bw list|ls|l             - List all item names (sorted)
#   bw sync                  - Sync with server
#   bw status|s              - Show vault status
#   bw help|h                - Show help
#
# Pass-through Commands (unchanged):
#   bw create item ...       - All official bw commands work normally
#   bw edit item ...
#   bw delete item ...
#   bw generate ...
#   ... and all others
#
# Examples:
#   bw unlock                # Unlock once, use everywhere
#   bw get Github            # Get GitHub password
#   bw c gitlab              # Copy GitLab password to clipboard
#   bw f amazon              # Search for items containing "amazon"
#   bw create item ...       # Create new item (original bw command)
bw() {
    local cmd="${1:-list}"

    case "$cmd" in
        # Shortcut commands (enhanced functionality)
        get|g)
            shift
            command bw get item "$@" 2>/dev/null | grep -o '"password":"[^"]*"' | cut -d'"' -f4
            ;;
        copy|c)
            shift
            local password=$(command bw get item "$@" 2>/dev/null | grep -o '"password":"[^"]*"' | cut -d'"' -f4)
            if [[ -n "$password" ]]; then
                echo -n "$password" | xclip -selection clipboard 2>/dev/null || echo -n "$password" | pbcopy 2>/dev/null
                echo "✓ Password copied to clipboard"
            else
                echo "⚠ Item not found: $*"
                return 1
            fi
            ;;
        search|find|f)
            shift
            command bw list items --search "$@" 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4
            ;;
        list|ls|l)
            shift
            command bw list items 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | sort
            ;;
        unlock|u)
            shift
            echo "🔓 Unlocking Bitwarden vault..."
            # Use declare -g to make it global (visible to parent shell)
            declare -g BW_SESSION=$(command bw unlock --raw)
            if [[ -n "$BW_SESSION" ]]; then
                export BW_SESSION
                # Store session in tmpfs (auto-cleared on logout/shutdown/reboot)
                local BW_SESSION_FILE="/run/user/$(id -u)/bw-session"
                echo "$BW_SESSION" > "$BW_SESSION_FILE"
                chmod 600 "$BW_SESSION_FILE"
                echo ""
                echo "✅ Bitwarden unlocked successfully!"
                echo "📦 Session stored in tmpfs (auto-cleared on logout)"
                echo ""
                # Auto-load secrets and save to tmpfs
                load_bw_secrets
            else
                echo ""
                echo "❌ Failed to unlock Bitwarden"
                return 1
            fi
            ;;
        lock)
            shift
            command bw lock
            unset BW_SESSION GITHUB_TOKEN GITLAB_TOKEN COMPOSER_AUTH
            # Clear all Bitwarden files from tmpfs (session + tokens + composer auth)
            rm -f "/run/user/$(id -u)"/bw-*
            echo "🔒 Bitwarden locked (session, tokens, and Composer auth cleared)"
            ;;
        sync)
            shift
            command bw sync
            echo "✓ Bitwarden vault synced"
            ;;
        status|s)
            shift
            command bw status
            ;;
        help|h)
            cat << 'EOF'
bw - Bitwarden CLI with shortcuts

Shortcut commands:
  bw [get|g] <name>         Get password for item
  bw copy|c <name>          Copy password to clipboard
  bw search|f <pattern>     Search for items by name
  bw list|ls|l              List all item names
  bw unlock|u               Unlock vault and export session
  bw lock                   Lock vault and clear tokens
  bw sync                   Sync vault with server
  bw status|s               Show vault status
  bw help|h                 Show this help

Examples:
  bw get "GitHub Token"     # Get GitHub token password
  bw c gitlab               # Copy first matching gitlab item
  bw f github               # Search for items containing "github"
  bw unlock                 # Unlock vault
  bw sync                   # Sync with Bitwarden server

All other commands:
  bw create item ...        # Pass through to original bw CLI
  bw edit item ...          # Pass through to original bw CLI
  bw <any-command> ...      # Pass through to original bw CLI
EOF
            ;;
        *)
            # Pass through to original bw CLI for all other commands
            # This maintains full compatibility with the official Bitwarden CLI
            command bw "$@"
            ;;
    esac
}
