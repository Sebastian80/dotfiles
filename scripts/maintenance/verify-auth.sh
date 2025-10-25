#!/bin/bash
# Verify Authentication Setup
# Comprehensive check of Bitwarden, tokens, SSH agent, and CLI tools

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }
section() { echo -e "\n${CYAN}===${NC} $1 ${CYAN}===${NC}"; }

section "Authentication Verification"
echo ""

# 1. Bitwarden CLI
section "Bitwarden CLI"

if command -v bw &>/dev/null; then
    success "bw CLI installed"
    info "Version: $(bw --version)"
else
    error "bw CLI not found"
    echo "  Install: brew install bitwarden-cli"
fi
echo ""

# 2. Bitwarden Session
section "Bitwarden Session"

if [[ -n "$BW_SESSION" ]]; then
    success "BW_SESSION active"
    # Check session is valid
    if bw unlock --check &>/dev/null; then
        success "Session is valid"
    else
        warn "Session may be expired (run: bw unlock)"
    fi
else
    error "BW_SESSION not set (run: bw unlock)"
fi
echo ""

# 3. Development Tokens
section "Development Tokens"

if [[ -n "$GITHUB_TOKEN" ]]; then
    success "GITHUB_TOKEN loaded"
    TOKEN_LEN=${#GITHUB_TOKEN}
    info "Length: $TOKEN_LEN characters"
else
    error "GITHUB_TOKEN not set"
fi

if [[ -n "$GITLAB_TOKEN" ]]; then
    success "GITLAB_TOKEN loaded"
    TOKEN_LEN=${#GITLAB_TOKEN}
    info "Length: $TOKEN_LEN characters"
else
    error "GITLAB_TOKEN not set"
fi

if [[ -n "$GITLAB_HOST" ]]; then
    success "GITLAB_HOST set: $GITLAB_HOST"
    if [[ "$GITLAB_HOST" == "git.netresearch.de" ]]; then
        success "Using self-hosted GitLab (recommended)"
    fi
else
    warn "GITLAB_HOST not set (defaults to gitlab.com)"
    info "Set in ~/.bash/exports/bitwarden.bash if using self-hosted GitLab"
fi

if [[ -n "$COMPOSER_AUTH" ]]; then
    success "COMPOSER_AUTH loaded"
    # Validate JSON
    if echo "$COMPOSER_AUTH" | jq empty 2>/dev/null; then
        success "COMPOSER_AUTH is valid JSON"
        # Check domains
        if echo "$COMPOSER_AUTH" | jq -e '.["github-oauth"]["github.com"]' &>/dev/null; then
            success "GitHub OAuth configured"
        fi
        if echo "$COMPOSER_AUTH" | jq -e '.["gitlab-token"]' &>/dev/null; then
            GITLAB_DOMAIN=$(echo "$COMPOSER_AUTH" | jq -r '.["gitlab-token"] | keys[0]')
            success "GitLab token configured for: $GITLAB_DOMAIN"
        fi
    else
        error "COMPOSER_AUTH is invalid JSON"
    fi
else
    error "COMPOSER_AUTH not set"
fi
echo ""

# 4. SSH Agent
section "SSH Agent"

if [[ -S "$HOME/.bitwarden-ssh-agent.sock" ]]; then
    success "Bitwarden SSH agent socket found"
else
    error "SSH agent socket not found"
    echo "  Enable in Bitwarden Desktop: Settings → Options → SSH Agent"
fi

if [[ -n "$SSH_AUTH_SOCK" ]]; then
    success "SSH_AUTH_SOCK set: $SSH_AUTH_SOCK"
    # List SSH keys
    if command -v ssh-add &>/dev/null; then
        KEY_COUNT=$(ssh-add -l 2>/dev/null | grep -v "no identities" | wc -l)
        if [[ $KEY_COUNT -gt 0 ]]; then
            success "SSH keys loaded: $KEY_COUNT"
        else
            warn "No SSH keys loaded"
        fi
    fi
else
    error "SSH_AUTH_SOCK not set"
fi
echo ""

# 5. GitHub CLI (gh)
section "GitHub CLI (gh)"

if [[ -f "$HOME/.config/gh/config.yml" ]]; then
    success "gh config exists"
else
    error "gh config not found"
fi

if command -v gh &>/dev/null; then
    success "gh CLI installed"

    # Check git protocol
    GIT_PROTOCOL=$(gh config get git_protocol 2>/dev/null || echo "not set")
    if [[ "$GIT_PROTOCOL" == "ssh" ]]; then
        success "gh using SSH protocol"
    else
        warn "gh not configured for SSH (current: $GIT_PROTOCOL)"
        echo "  Set with: gh config set git_protocol ssh"
    fi

    # Check authentication
    if gh auth status &>/dev/null; then
        success "gh authenticated"
    else
        warn "gh not authenticated"
    fi
else
    warn "gh CLI not installed"
fi
echo ""

# 6. GitLab CLI (glab)
section "GitLab CLI (glab)"

if [[ -f "$HOME/.config/glab-cli/config.yml" ]]; then
    success "glab config exists"

    # Check host configuration
    if grep -q "host: git.netresearch.de" "$HOME/.config/glab-cli/config.yml" 2>/dev/null; then
        success "glab configured for git.netresearch.de"
    else
        warn "glab not configured for self-hosted GitLab"
    fi
else
    error "glab config not found"
fi

if command -v glab &>/dev/null; then
    success "glab CLI installed"

    # Check authentication
    if glab auth status &>/dev/null; then
        success "glab authenticated"
    else
        warn "glab not authenticated"
    fi
else
    warn "glab CLI not installed"
fi
echo ""

# 7. Composer
section "Composer Authentication"

if command -v composer &>/dev/null; then
    success "Composer installed"

    # Test GitHub authentication
    if [[ -n "$COMPOSER_AUTH" ]]; then
        if echo "$COMPOSER_AUTH" | jq -e '.["github-oauth"]["github.com"]' &>/dev/null; then
            success "GitHub OAuth token configured"
        else
            warn "GitHub OAuth token not configured"
        fi

        if echo "$COMPOSER_AUTH" | jq -e '.["gitlab-token"]' &>/dev/null; then
            success "GitLab token configured"
        else
            warn "GitLab token not configured"
        fi
    fi
else
    warn "Composer not installed (brew install composer)"
fi
echo ""

# 8. tmpfs Storage
section "tmpfs Storage (RAM-only secrets)"

TMPFS_DIR="/run/user/${UID:-$(id -u)}"

if [[ -d "$TMPFS_DIR" ]]; then
    success "tmpfs directory exists: $TMPFS_DIR"
else
    error "tmpfs directory not found"
fi

check_tmpfs_file() {
    local file="$1"
    local desc="$2"

    if [[ -f "$TMPFS_DIR/$file" ]]; then
        success "$desc stored in tmpfs"
    else
        warn "$desc not in tmpfs"
    fi
}

check_tmpfs_file "bw-session" "Bitwarden session"
check_tmpfs_file "bw-github-token" "GitHub token"
check_tmpfs_file "bw-gitlab-token" "GitLab token"
check_tmpfs_file "bw-composer-auth" "Composer auth"
echo ""

# 9. System Configuration
section "System Configuration"

if [[ -f /etc/sudoers.d/homebrew-path ]]; then
    success "Homebrew sudoers configuration installed"

    # Check permissions
    PERMS=$(stat -c '%a' /etc/sudoers.d/homebrew-path 2>/dev/null)
    if [[ "$PERMS" == "440" ]]; then
        success "Permissions correct (440)"
    else
        error "Permissions incorrect: $PERMS (should be 440)"
    fi

    # Verify PATH with sudo
    if sudo env | grep -q "/home/linuxbrew/.linuxbrew/bin"; then
        success "Homebrew PATH available with sudo"
    else
        warn "Homebrew PATH not available with sudo"
    fi
else
    warn "Homebrew sudoers configuration not installed"
    echo "  Install with: make install-system"
fi
echo ""

# Summary
section "Summary"
echo ""
info "For detailed setup instructions, see:"
echo "  - INSTALLATION.md (Step 7: Configure Authentication)"
echo "  - SECRET_MANAGEMENT.md (Complete authentication guide)"
echo "  - system/README.md (System configuration details)"
echo ""
info "Quick commands:"
echo "  bw unlock                  # Unlock Bitwarden and load tokens"
echo "  make verify-auth           # Run this verification"
echo "  make install-system        # Install system configurations"
echo ""
