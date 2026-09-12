# Secret Management with Bitwarden - 2025

**Last Updated:** 2026-09-12
**System:** Integrated Bitwarden (Desktop + Browser + CLI + SSH Agent)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Components](#components)
3. [Biometric Unlock Setup](#biometric-unlock-setup)
4. [CLI Integration](#cli-integration)
5. [SSH Key Management](#ssh-key-management)
6. [Session Management](#session-management)
7. [Token Loading](#token-loading)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

This system uses **Bitwarden** as a unified secret management solution with four integrated components:

```text
┌─────────────────────────────────────────────────────────────┐
│ BITWARDEN INTEGRATED ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐                                      │
│  │ Desktop App      │  ← Biometric unlock (fingerprint)    │
│  │ (Bitwarden.deb)  │  ← Master vault                      │
│  └────────┬─────────┘  ← Polkit + fprintd integration     │
│           │                                                 │
│           ├──→ Native Messaging ──→ Browser Extension      │
│           │                                                 │
│           ├──→ SSH Agent Socket ──→ SSH Client             │
│           │    (~/.bitwarden-ssh-agent.sock)               │
│           │                                                 │
│           └──→ Unlock Signal ────→ CLI (bw command)        │
│                                                             │
│  ┌──────────────────┐                                      │
│  │ Enhanced CLI     │  ← Custom bash wrapper               │
│  │ (bw function)    │  ← Session in tmpfs                  │
│  └────────┬─────────┘  ← Shortcuts (u/l/g/c)              │
│           │                                                 │
│           ├──→ BW_SESSION ────→ bw-session                │
│           ├──→ GITHUB_TOKEN ──→ bw-github-token           │
│           ├──→ GITLAB_TOKEN ──→ bw-gitlab-token           │
│           └──→ COMPOSER_AUTH ─→ bw-composer-auth          │
│                                 (all in /run/user/$UID/)  │
│                                                             │
│  All tokens in tmpfs (RAM-only, cleared on logout)         │
└─────────────────────────────────────────────────────────────┘
```

### Key Benefits

✅ **Single Unlock**: Fingerprint unlock for desktop app unlocks everything
✅ **Browser Integration**: Native messaging for browser extension
✅ **SSH Management**: Bitwarden SSH agent manages all SSH keys
✅ **CLI Automation**: Enhanced `bw` command with session management
✅ **Secure Storage**: Tokens in tmpfs (RAM-only, auto-cleared)
✅ **Cross-Terminal**: Session shared across all terminal windows

---

## Components

### 1. Bitwarden Desktop App

**Package:** `bitwarden.deb` (from official website, NOT Flatpak/Snap)
**Location:** Installed system-wide via dpkg
**Unlock:** Fingerprint (fprintd + polkit integration)

**Features:**

- Master vault storage
- Biometric unlock (fingerprint reader)
- Native messaging for browser extension
- SSH agent socket
- Background process (remains unlocked)

**Installation:**

```bash
# Download from https://bitwarden.com/download/
# Quote the URL: an unquoted & splits the command and backgrounds the first half.
wget "https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=deb" -O Bitwarden.deb
sudo dpkg -i Bitwarden.deb
```

### 2. Browser Extension

**Browser:** Google Chrome (.deb package, NOT Flatpak)
**Extension:** Bitwarden Browser Extension
**Communication:** Native messaging → Desktop app

**Why .deb Chrome?**

- Flatpak Chrome blocks native messaging (sandboxing)
- .deb version allows IPC with desktop app
- Enables biometric unlock in browser

**Setup:**

1. Install Chrome .deb: `sudo dpkg -i google-chrome-stable_current_amd64.deb`
2. Install Bitwarden extension from Chrome Web Store
3. Enable "Unlock with biometrics" in extension settings
4. Use fingerprint to unlock instead of master password

### 3. Bitwarden CLI

**Package:** `bitwarden-cli` (Homebrew)
**Command:** `bw` (enhanced with custom wrapper)
**Config:** `~/.bash/functions/bitwarden.bash`

**Installation:**

```bash
brew install bitwarden-cli
```

**Enhanced Features** (via bash wrapper):

- `bw unlock` or `bw u` - Unlock and save session to tmpfs
- `bw lock` - Lock and clear all tokens
- `bw get` or `bw g` - Get password from item
- `bw copy` or `bw c` - Copy password to clipboard
- Auto-loads tokens on unlock (GITHUB_TOKEN, etc.)

### 4. Bitwarden SSH Agent

**Socket:** `~/.bitwarden-ssh-agent.sock`
**Config:** `~/.bash/exports/bitwarden.bash`

**Features:**

- Manages all SSH keys stored in Bitwarden vault
- No need for ssh-agent or keychain
- Keys decrypted on demand with biometric unlock
- Integrated with SSH client via SSH_AUTH_SOCK

**Configuration:**

```bash
# Automatically configured in exports/bitwarden.bash
export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
```

---

## Biometric Unlock Setup

### Prerequisites

1. **Fingerprint Reader**: Hardware fingerprint scanner
2. **fprintd**: Fingerprint authentication daemon
3. **Chrome .deb**: NOT Flatpak (blocks native messaging)
4. **Bitwarden Desktop**: .deb package

### Step 1: Install fprintd

```bash
sudo apt update
sudo apt install fprintd libpam-fprintd
```

### Step 2: Enroll Fingerprints

```bash
# Enroll your fingerprints
fprintd-enroll

# Verify enrollment
fprintd-list $USER
```

### Step 3: Configure PAM for Polkit

Polkit uses PAM for authentication. Add fingerprint support:

```bash
# Check current PAM config
cat /etc/pam.d/polkit-1

# Should include (automatically added by libpam-fprintd):
# auth sufficient pam_fprintd.so
# auth required pam_unix.so
```

### Step 4: Test Biometric Unlock

1. Open Bitwarden desktop app
2. Lock the vault
3. Click unlock
4. Touch fingerprint reader (instead of typing master password)
5. Vault should unlock with fingerprint

### Step 5: Configure Browser Extension

1. Install Bitwarden extension in Chrome
2. Go to Settings → Options
3. Enable "Unlock with biometrics"
4. Test: Lock extension, unlock with fingerprint

### Troubleshooting Biometric Unlock

**Desktop app doesn't show fingerprint option:**

```bash
# Verify fprintd is running
systemctl status fprintd

# Check enrolled fingerprints
fprintd-list $USER

# Test polkit with fingerprint
pkexec echo "test"  # Should prompt for fingerprint
```

**Browser extension shows "biometrics unavailable":**

- Check Chrome is .deb package (not Flatpak)
- Verify native messaging: `ls ~/.config/google-chrome/NativeMessagingHosts/`
- Restart Chrome completely
- Check desktop app is running

---

## CLI Integration

### Enhanced bw Command

Custom bash wrapper in `~/.bash/functions/bitwarden.bash` enhances the official `bw` CLI.

### File: `~/.bash/functions/bitwarden.bash` (relevant excerpt)

The file is the authority; this is the shape of it, not a copy to keep in sync.

```bash
bw() {
    local cmd="${1:-list}"
    case "$cmd" in
        unlock|u)
            declare -g BW_SESSION=$(command bw unlock --raw)
            # `bw unlock --raw` has shipped broken before, printing a valid-looking token that no
            # later command accepts. Verify the session really unlocks the vault instead of
            # reporting success and discovering the lie on the first secret lookup.
            if [[ -n "$BW_SESSION" ]] && BW_SESSION="$BW_SESSION" command bw unlock --check &>/dev/null; then
                export BW_SESSION
                # umask in a subshell, so the file is never briefly world-readable.
                (umask 077; echo "$BW_SESSION" >| "/run/user/${UID:-$(id -u)}/bw-session")
                load_bw_secrets
            else
                unset BW_SESSION
                return 1
            fi
            ;;
        lock)
            command bw lock
            unset BW_SESSION GITHUB_TOKEN GITLAB_TOKEN COMPOSER_AUTH
            rm -f "/run/user/${UID:-$(id -u)}/"bw-*
            ;;
        get|g|copy|c|search|find|f|list|ls|l|sync|status|s|help|h)
            : # shortcuts, see the file
            ;;
        *)
            command bw "$@"  # Pass-through to the original CLI
            ;;
    esac
}
```

### Usage Examples

```bash
# Unlock vault (stores session in tmpfs, loads dev tokens)
bw unlock
# or shortcut:
bw u

# Get password from item
bw get "GitHub"
# or shortcut:
bw g "GitHub"

# Copy password to clipboard
bw copy "GitHub"
# or shortcut:
bw c "GitHub"

# Lock vault (clears session and all tokens)
bw lock

# Original CLI commands still work
bw list items
bw create item
bw edit item <id>
```

### Session Persistence

**Session stored in:** `/run/user/$UID/bw-session`
**Characteristics:**

- tmpfs (RAM-only storage)
- Automatically cleared on logout/reboot
- Shared across all terminal windows
- Secure (mode 600, only readable by you)

**Auto-loading on new shells:**

```bash
# In functions/bitwarden.bash
if command -v bw &>/dev/null; then
    _BW_RUNDIR="/run/user/${UID:-$(id -u)}"
    # The session token stays out of shells that belong to Claude Code (it sets CLAUDECODE=1):
    # the agent gets the derived tokens below, never the key to the whole vault.
    [[ -f "$_BW_RUNDIR/bw-session" && -z "${CLAUDECODE:-}" ]] && export BW_SESSION=$(command cat "$_BW_RUNDIR/bw-session")
    [[ -f "$_BW_RUNDIR/bw-github-token" ]] && export GITHUB_TOKEN=$(command cat "$_BW_RUNDIR/bw-github-token")
    # ... bw-gitlab-token (plus GITLAB_HOST) and bw-composer-auth likewise
fi
```

Result: Open new terminal → BW_SESSION automatically loaded → CLI works immediately

### The Claude Code boundary

An agent session is deliberately a tier below a human shell. `CLAUDECODE=1` suppresses the
`BW_SESSION` export, so Claude Code inherits `GITHUB_TOKEN`, `GITLAB_TOKEN` and `COMPOSER_AUTH`
(scoped, revocable) but cannot run `bw get` against the vault itself. Tightening this further, with
agent-scoped tokens and a scrubbing launcher, is designed in `docs/plans/` (untracked: it names
customer projects).

---

## SSH Key Management

### Bitwarden SSH Agent

**How it works:**

1. Store SSH private keys in Bitwarden vault (as "SSH Key" item type)
2. Bitwarden desktop app creates SSH agent socket
3. SSH client uses Bitwarden as SSH agent
4. Keys decrypted on-demand with biometric unlock

### Setup

**1. Enable SSH Agent in Bitwarden Desktop:**

- Open Bitwarden desktop app
- Settings → Options
- Enable "Enable SSH Agent"
- Note socket path: `~/.bitwarden-ssh-agent.sock`

**2. Configure SSH Client:**

File: `~/.bash/exports/bitwarden.bash`

```bash
# Configure SSH to use Bitwarden SSH agent
if [ -S "$HOME/.bitwarden-ssh-agent.sock" ]; then
    export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
fi
```

**3. Add SSH Keys to Bitwarden:**

- Item Type: "SSH Key"
- Private Key: Paste your private key (including passphrase if any)
- Bitwarden will manage decryption

**4. Test:**

```bash
# List keys managed by Bitwarden SSH agent
ssh-add -l

# Use SSH normally
ssh git@github.com
# Bitwarden decrypts key on-demand with fingerprint
```

### Advantages

✅ **No separate ssh-agent needed**
✅ **Keys encrypted in Bitwarden vault**
✅ **Biometric unlock for key access**
✅ **Works across all applications**
✅ **No keys on filesystem** (optional - can delete local copies)

### SSH Key Best Practices

**Key Generation:**

```bash
# Generate Ed25519 key
ssh-keygen -t ed25519 -C "your-email@example.com"

# Store in Bitwarden:
# 1. Copy private key content: cat ~/.ssh/id_ed25519
# 2. Create "SSH Key" item in Bitwarden
# 3. Paste private key
# 4. (Optional) Delete local copy after testing
```

**Multiple Keys:**

- Store each key as separate "SSH Key" item in Bitwarden
- Name them clearly: "GitHub SSH", "GitLab SSH", "Work Server SSH"
- Bitwarden SSH agent automatically provides correct key

---

## Session Management

### Architecture

```text
┌──────────────────────────────────────────────────────┐
│ tmpfs (/run/user/$UID) - RAM-only storage           │
├──────────────────────────────────────────────────────┤
│  bw-session        ← Bitwarden CLI session token    │
│  bw-github-token   ← GitHub personal access token   │
│  bw-gitlab-token   ← GitLab access token            │
│  bw-composer-auth  ← Composer auth JSON             │
└──────────────────────────────────────────────────────┘
         ↓ Cleared automatically on logout/reboot
```

### Session Workflow

1. **Unlock:** `bw unlock`
   - Prompts for master password
   - Generates session token
   - Saves to `/run/user/$UID/bw-session` (mode 600)
   - Calls `load_bw_secrets` to populate environment tokens
   - Tokens saved to tmpfs

2. **New Terminal:**
   - Shell starts, loads `~/.bash/functions/bitwarden.bash`
   - Checks for `/run/user/$UID/bw-session`
   - Auto-loads BW_SESSION
   - Auto-loads GITHUB_TOKEN, GITLAB_TOKEN, etc.
   - CLI works immediately, no re-unlock needed

3. **Lock:** `bw lock`
   - Locks Bitwarden vault
   - Unsets environment variables
   - Deletes all `/run/user/$UID/bw-*` files
   - Session and tokens cleared from memory

4. **Logout/Reboot:**
   - tmpfs automatically cleared
   - All session data removed from RAM
   - No traces left on disk

### Security Properties

✅ **RAM-only**: Never written to disk
✅ **Auto-clear**: Removed on logout/reboot
✅ **Secure permissions**: Mode 600 (only your user)
✅ **Shared safely**: All your terminals, nobody else's
✅ **No persistence**: Session doesn't survive reboot

---

## Token Loading

### Auto-loading Development Tokens

When you run `bw unlock`, the enhanced CLI automatically calls `load_bw_secrets` to populate development tokens.

### Function: `load_bw_secrets` (in `~/.bash/functions/bitwarden.bash`)

```bash
load_bw_secrets() {
    local quiet=false
    # $1 has to tolerate being unset: callers pass nothing, and a `set -u` caller would
    # otherwise abort here instead of loading secrets.
    if [[ "${1:-}" == "--quiet" ]]; then
        quiet=true
    fi

    # Check bw is available, then that the vault is actually unlocked
    if ! command -v bw &>/dev/null; then
        [[ "$quiet" == false ]] && echo "⚠ Bitwarden CLI not installed"
        return 1
    fi
    local status=$(command bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [[ "$status" != "unlocked" ]]; then
        [[ "$quiet" == false ]] && echo "⚠ Bitwarden is locked. Please unlock first with: bw unlock"
        return 1
    fi

    # Each token: read the item, then write the tmpfs copy with umask in a subshell so there
    # is no window where the file exists with default permissions.
    local github_token=$(command bw get item <github-item> 2>/dev/null | \
        jq -r '.fields[]? | select(.name == "token" or .name == "Token") | .value' 2>/dev/null)
    if [[ -n "$github_token" && "$github_token" != "null" ]]; then
        export GITHUB_TOKEN="$github_token"
        (umask 077; echo "$github_token" >| "/run/user/${UID:-$(id -u)}/bw-github-token")
    fi

    # GitLab token (same shape, also exports GITLAB_HOST)
    # Magento repo credentials (login username/password, not a custom field)
    # COMPOSER_AUTH assembled from all three, see the next section

    [[ "$quiet" == false ]] && echo "✅ Development secrets loaded and saved to tmpfs"
}
```

### Supported Tokens

| Token | Env Variable | Source | Purpose |
|-------|--------------|--------|---------|
| GitHub | `GITHUB_TOKEN` | "Github" vault item, custom field `token`/`Token` | GitHub API access, Composer |
| GitLab | `GITLAB_TOKEN` | "Gitlab" vault item, custom field `token`/`Token` | GitLab API access, Composer |
| Magento | (none) | "Magento Repository Access" item, login username/password | `repo.magento.com` Composer auth |
| Composer | `COMPOSER_AUTH` | Assembled from the three above | PHP package auth |

`GITLAB_HOST` is exported alongside `GITLAB_TOKEN` so other tools resolve the self-hosted instance.
The item IDs live in `bash/.bash/functions/bitwarden.bash`; look them up there rather than here, so
there is one place to change when a vault item is replaced.

### Usage

**Automatic (on unlock):**

```bash
bw unlock
# Output:
# ✓ Bitwarden unlocked (session available until logout)
# ✓ GITHUB_TOKEN loaded
# ✓ GITLAB_TOKEN loaded
# ✓ COMPOSER_AUTH loaded
# ✓ Development secrets loaded
```

**Manual (reload tokens):**

```bash
load_bw_secrets
```

**Silent mode:**

```bash
load_bw_secrets --quiet
```

### Adding New Tokens

1. **Store in Bitwarden:**
   - Create item in Bitwarden vault
   - Add custom field named "token" or "Token"
   - Get item ID: `bw list items | jq -r '.[] | select(.name=="YourItem") | .id'`

2. **Add to `load_bw_secrets` function:**

```bash
# Your new token
local your_token=$(bw get item ITEM_ID 2>/dev/null | jq -r '.fields[] | select(.name == "token") | .value' 2>/dev/null)
if [[ -n "$your_token" && "$your_token" != "null" ]]; then
    export YOUR_TOKEN="$your_token"
    echo "$YOUR_TOKEN" > "/run/user/$(id -u)/bw-your-token"
    chmod 600 "/run/user/$(id -u)/bw-your-token"
    [[ "$quiet" == false ]] && echo "✓ YOUR_TOKEN loaded"
fi
```

1. **Add to unlock and unload:**

```bash
# In bw() function, lock case:
unset BW_SESSION GITHUB_TOKEN GITLAB_TOKEN COMPOSER_AUTH YOUR_TOKEN
```

---

## GitHub CLI (gh) Configuration

### Current Setup

The GitHub CLI is configured to use **SSH protocol** for all Git operations.

**Configuration file:** `~/.config/gh/config.yml`

```yaml
git_protocol: ssh  # Uses SSH for git operations (not HTTPS)
```

### Why SSH Protocol?

- **No token needed for git operations** - SSH keys handled by Bitwarden SSH Agent
- **More secure** than HTTPS with token authentication
- **Consistent** with SSH-based workflows
- **Best practice** recommended by GitHub

### Authentication Methods

| Operation | Authentication Method | Token/Key Used |
|-----------|----------------------|----------------|
| Git clone/push/pull | SSH | Bitwarden SSH Agent (SER_SSH ED25519 key) |
| API calls (`gh pr`, `gh issue`, etc.) | HTTPS + OAuth/Token | GITHUB_TOKEN (from Bitwarden) |

### Using gh CLI

```bash
# Git operations use SSH automatically
gh repo clone username/repo
# Internally uses: git clone git@github.com:username/repo.git

# API operations use GITHUB_TOKEN
gh pr list
gh issue create
gh api user

# Check authentication status
gh auth status
# Output:
#   ✓ Logged in to github.com account Sebastian80 (GITHUB_TOKEN)
#   - Git operations protocol: ssh
```

### Configuration Commands

```bash
# View current protocol
gh config get git_protocol
# Output: ssh

# Change to SSH (already set in dotfiles)
gh config set git_protocol ssh

# Change to HTTPS (not recommended)
gh config set git_protocol https
```

### How GITHUB_TOKEN is Used

The `GITHUB_TOKEN` environment variable is used for:

1. **gh CLI API operations** - All `gh` commands that call GitHub API
2. **Composer** - Accessing private GitHub packages
3. **CI/CD** - Can be passed to GitHub Actions

**Not used for:**

- Git clone/push operations (uses SSH keys instead)

### Troubleshooting

**Problem:** gh says "Not logged in"

```bash
# Check if GITHUB_TOKEN is loaded
echo $GITHUB_TOKEN

# If empty, unlock Bitwarden
bw unlock

# Verify authentication
gh auth status
```

**Problem:** gh uses HTTPS instead of SSH for cloning

```bash
# Check protocol
gh config get git_protocol

# Set to SSH
gh config set git_protocol ssh
```

**Problem:** SSH key authentication fails

```bash
# Check SSH agent
echo $SSH_AUTH_SOCK
# Should show: /home/sebastian/.bitwarden-ssh-agent.sock

# List loaded keys
ssh-add -l
# Should show SER_SSH key

# Test GitHub SSH
ssh -T git@github.com
# Should show: Hi Sebastian80! You've successfully authenticated
```

---

## GitLab CLI (glab) Configuration

### Current Setup

The GitLab CLI is configured for **self-hosted GitLab** instance at **git.netresearch.de**.

**Configuration file:** `~/.config/glab-cli/config.yml`

```yaml
git_protocol: ssh  # Uses SSH for git operations
host: git.netresearch.de  # Self-hosted GitLab instance

hosts:
    git.netresearch.de:
        api_protocol: https
        api_host: git.netresearch.de
        token:  # Uses GITLAB_TOKEN environment variable
```

### Self-Hosted GitLab Setup

Your configuration uses a **self-hosted GitLab** instance, not gitlab.com:

- **GitLab URL:** <https://git.netresearch.de>
- **SSH URL:** <git@git.netresearch.de>:group/project.git
- **API Endpoint:** <https://git.netresearch.de/api/v4/>

### Authentication Methods

| Operation | Authentication Method | Token/Key Used |
|-----------|----------------------|----------------|
| Git clone/push/pull | SSH | Bitwarden SSH Agent |
| API calls (`glab mr`, `glab issue`, etc.) | HTTPS + Token | GITLAB_TOKEN (from Bitwarden) |

### How It Works

1. **Git Operations:** Use SSH protocol
   - SSH key managed by Bitwarden SSH Agent
   - Format: `git@git.netresearch.de:group/project.git`

2. **API Operations:** Use GITLAB_TOKEN environment variable
   - Auto-loaded from Bitwarden when running `bw unlock`
   - Stored in tmpfs: `/run/user/$UID/bw-gitlab-token`
   - Bitwarden item ID: `<bw-item-gitlab>`

3. **GITLAB_HOST:** Automatically set when GITLAB_TOKEN is loaded
   - `export GITLAB_HOST="git.netresearch.de"`
   - Tells other tools (like Composer) to use self-hosted instance

### Using glab CLI

```bash
# Ensure Bitwarden is unlocked (loads GITLAB_TOKEN)
bw unlock

# Verify token and host are set
echo $GITLAB_TOKEN
echo $GITLAB_HOST
# Should show: git.netresearch.de

# Use glab normally
glab mr list
glab issue create
glab repo clone group/project
glab api user

# Check authentication status
glab auth status
# Output:
#   ✓ Logged in to git.netresearch.de as sebastian.ertner (GITLAB_TOKEN)
#   ✓ Git operations for git.netresearch.de configured to use ssh protocol
```

### Configuration Commands

```bash
# View current host
glab config get host
# Output: git.netresearch.de

# View git protocol
cat ~/.config/glab-cli/config.yml | grep git_protocol
# Output: git_protocol: ssh

# Set host (already configured in dotfiles)
glab config set --global host git.netresearch.de
```

### How GITLAB_TOKEN is Used

The `GITLAB_TOKEN` environment variable is used for:

1. **glab CLI API operations** - All `glab` commands that call GitLab API
2. **Composer** - Accessing private GitLab packages from git.netresearch.de
3. **CI/CD** - Can be passed to GitLab CI pipelines

**Not used for:**

- Git clone/push operations (uses SSH keys instead)

### GitLab.com vs Self-Hosted

Your setup is configured for **self-hosted GitLab**:

| Aspect | GitLab.com (public) | git.netresearch.de (self-hosted) |
|--------|---------------------|----------------------------------|
| Host | gitlab.com | git.netresearch.de |
| SSH URL | <git@gitlab.com>:user/repo.git | <git@git.netresearch.de>:group/project.git |
| API Endpoint | <https://gitlab.com/api/v4/> | <https://git.netresearch.de/api/v4/> |
| Token Domain | gitlab.com | git.netresearch.de |
| COMPOSER_AUTH | `"gitlab-token":{"gitlab.com":"token"}` | `"gitlab-token":{"git.netresearch.de":"token"}` |

**Your dotfiles automatically configure this** via:

- `GITLAB_HOST` environment variable
- glab config file pointing to git.netresearch.de
- COMPOSER_AUTH using git.netresearch.de (not gitlab.com)

### Troubleshooting

**Problem:** glab says "No GitLab token found"

```bash
# Check if GITLAB_TOKEN is loaded
echo $GITLAB_TOKEN

# If empty, unlock Bitwarden
bw unlock

# Manually load if needed
load_bw_secrets

# Verify
glab auth status
```

**Problem:** glab connects to gitlab.com instead of git.netresearch.de

```bash
# Check GITLAB_HOST
echo $GITLAB_HOST
# Should show: git.netresearch.de

# Check glab config
cat ~/.config/glab-cli/config.yml | grep host
# Should show: host: git.netresearch.de

# Fix if wrong
glab config set --global host git.netresearch.de
```

**Problem:** 401 Unauthorized

```bash
# Check token validity at https://git.netresearch.de/-/user_settings/personal_access_tokens
# Ensure token has these scopes:
# - api (for glab CLI)
# - read_repository
# - write_repository

# Regenerate token if expired, update in Bitwarden
# Then reload:
bw lock && bw unlock
```

**Problem:** SSH authentication fails

```bash
# Check SSH agent
echo $SSH_AUTH_SOCK

# Test GitLab SSH
ssh -T git@git.netresearch.de
# Should show: Welcome to GitLab, @sebastian.ertner!
```

---

## Composer Authentication

### How COMPOSER_AUTH Works

Composer reads the `COMPOSER_AUTH` environment variable to authenticate with package repositories.

**Format:**

```json
{
  "github-oauth": {
    "github.com": "ghp_..."
  },
  "gitlab-token": {
    "git.netresearch.de": "glpat-..."
  },
  "http-basic": {
    "repo.magento.com": { "username": "...", "password": "..." }
  },
  "bearer": {
    "<satis-host>": "glpat-..."
  }
}
```

**Note:** This configuration uses **git.netresearch.de** (self-hosted GitLab), not gitlab.com.

The `bearer` entry appears only when `COMPOSER_SATIS_HOST` is set (in `~/.bash/local.bash`, so the
host stays out of this public repo). The internal Satis sits behind GitLab Pages access control:
unauthenticated it answers with the GitLab sign-in page, composer reports
`"…/users/sign_in" does not contain valid JSON`, and the repository then silently falls back to a
stale cache. It reuses the same GitLab PAT as `gitlab-token`, so there is no separate secret. Having
`gitlab-token` set is not evidence the auth is complete.

### Generated by Bitwarden

The `COMPOSER_AUTH` is **automatically generated** from GitHub and GitLab tokens when you run `bw unlock`:

**Source:** the `load_bw_secrets` function in `~/dotfiles/bash/.bash/functions/bitwarden.bash`

```bash
# Build COMPOSER_AUTH JSON from whichever tokens were found. Each section is appended only when
# its credential exists, and a leading comma is added only once the object is non-empty.
composer_auth='{'
composer_auth+='"github-oauth":{"github.com":"'"$github_token"'"}'
composer_auth+=',"gitlab-token":{"'"$GITLAB_HOST"'":"'"$gitlab_token"'"}'
composer_auth+=',"http-basic":{"repo.magento.com":{"username":"'"$magento_user"'","password":"'"$magento_pass"'"}}'
# Only when COMPOSER_SATIS_HOST is set:
composer_auth+=',"bearer":{"'"$COMPOSER_SATIS_HOST"'":"'"$gitlab_token"'"}'
composer_auth+='}'

export COMPOSER_AUTH="$composer_auth"
(umask 077; echo "$composer_auth" >| "/run/user/${UID:-$(id -u)}/bw-composer-auth")
```

### Using Composer

```bash
# Ensure Bitwarden is unlocked (loads COMPOSER_AUTH)
bw unlock

# Verify COMPOSER_AUTH is set
echo $COMPOSER_AUTH | jq

# Use Composer normally - authentication is automatic
composer install
composer require vendor/package

# Composer will authenticate to:
# - github.com for public/private GitHub packages
# - git.netresearch.de for private GitLab packages
```

### Testing Composer Authentication

```bash
# Check GitHub OAuth access
composer diagnose | grep github
# Expected: github.com oauth access: OK

# Test installing from private repo
composer require your-org/private-package

# Composer will use:
# - github-oauth for GitHub packages
# - gitlab-token for GitLab packages at git.netresearch.de
```

### Environment Variable vs auth.json

Composer supports two authentication methods:

1. **`COMPOSER_AUTH` environment variable** (used by these dotfiles)
   - ✅ Works in all contexts (interactive shells, scripts, CI/CD, Docker)
   - ✅ No file to manage
   - ✅ Auto-loaded from Bitwarden
   - ✅ Stored in tmpfs (RAM-only, auto-cleared)

2. **`~/.composer/auth.json` file** (not used)
   - ❌ Token stored on disk
   - ❌ Manual management required
   - ❌ Doesn't work in Docker containers without volume mount

**The environment variable takes precedence**, so even if you have an `auth.json` file, `COMPOSER_AUTH` will be used.

### Composer + Self-Hosted GitLab

For self-hosted GitLab instances, you must specify the domain in `gitlab-token`:

```json
{
  "gitlab-token": {
    "git.netresearch.de": "glpat-..."
  }
}
```

**Not:**

```json
{
  "gitlab-token": {
    "gitlab.com": "glpat-..."
  }
}
```

This is **automatically handled** by the dotfiles when `GITLAB_HOST` is set.

### Troubleshooting

**Problem:** Composer can't authenticate to GitLab packages

```bash
# Check COMPOSER_AUTH contains git.netresearch.de
echo $COMPOSER_AUTH | jq -r '.["gitlab-token"]'
# Should show: {"git.netresearch.de": "glpat-..."}

# If wrong, reload secrets
bw lock && bw unlock
```

**Problem:** Composer can't find packages from git.netresearch.de

```bash
# Ensure repository is added to composer.json
{
  "repositories": [
    {
      "type": "vcs",
      "url": "https://git.netresearch.de/group/project.git"
    }
  ]
}

# Or add globally
composer config --global repositories.netresearch vcs https://git.netresearch.de/group/project.git
```

---

## Best Practices

### Security

✅ **Use biometric unlock**: Faster and more secure than typing password
✅ **Lock when leaving**: Run `bw lock` before stepping away
✅ **Check session status**: `bw status` shows if vault is locked
✅ **Review token access**: Periodically check what tokens are loaded
✅ **Rotate tokens**: Regenerate API tokens every 6-12 months

### Workflow

**Daily routine:**

```bash
# Morning: Unlock once
bw unlock
# All terminals now have access

# Evening: Lock before shutdown
bw lock
```

**Project work:**

```bash
# Check if unlocked
bw status

# If locked, unlock
bw unlock

# Use tokens automatically
git push  # Uses GITHUB_TOKEN if configured
composer install  # Uses COMPOSER_AUTH
```

### Organization

**Bitwarden Vault Structure:**

```text
Bitwarden Vault
├── 🔐 Login Items
│   ├── GitHub (with custom field "token")
│   ├── GitLab (with custom field "token")
│   └── Composer (with custom field "token")
│
├── 🔑 SSH Keys
│   ├── GitHub SSH (Ed25519 private key)
│   ├── GitLab SSH (Ed25519 private key)
│   └── Work Server SSH (Ed25519 private key)
│
└── 🏢 Folders
    ├── Personal (personal accounts)
    ├── Development (API tokens, dev creds)
    └── Work (company accounts - if using personal Bitwarden)
```

### Backup

**What to backup:**

- Bitwarden vault (automatically synced to cloud)
- Emergency Kit (recovery codes, printed)
- Master password (memorized + written in safe)

**Emergency recovery:**

1. Download Bitwarden app on new machine
2. Login with email + master password
3. Vault syncs automatically
4. Re-enable biometric unlock (re-enroll fingerprints)
5. Run `bw unlock` in terminal

---

## Troubleshooting

### Bitwarden CLI Issues

**Problem:** `bw unlock` shows "Session already unlocked"

```bash
# Force re-unlock
bw lock
bw unlock
```

**Problem:** Session not persisting across terminals

```bash
# Check if session file exists
ls -la /run/user/$(id -u)/bw-session

# Check if auto-load is enabled
grep "BW_SESSION" ~/.bash/functions/bitwarden.bash

# Reload bash config
source ~/.bashrc
```

**Problem:** Tokens not loading

```bash
# Check if load_bw_secrets is defined
type load_bw_secrets

# Manually load tokens
load_bw_secrets

# Check token files
ls -la /run/user/$(id -u)/bw-*
```

### SSH Agent Issues

**Problem:** SSH keys not working

```bash
# Check if SSH agent socket exists
ls -la ~/.bitwarden-ssh-agent.sock

# Check SSH_AUTH_SOCK
echo $SSH_AUTH_SOCK

# List keys from Bitwarden SSH agent
ssh-add -l

# Restart Bitwarden desktop app
# Settings → Enable SSH Agent (toggle off/on)
```

**Problem:** Wrong key being used

```bash
# Check SSH config
cat ~/.ssh/config

# Use IdentitiesOnly to force specific key
# Host github.com
#     IdentitiesOnly yes
#     IdentityFile ~/.ssh/id_ed25519_github
```

### Biometric Unlock Issues

**Problem:** Fingerprint not working in desktop app

```bash
# Check fprintd status
systemctl status fprintd

# List enrolled fingerprints
fprintd-list $USER

# Re-enroll if needed
fprintd-enroll
```

**Problem:** Browser extension can't use biometrics

- Verify Chrome is .deb (not Flatpak): `which google-chrome`
- Check native messaging: `ls ~/.config/google-chrome/NativeMessagingHosts/`
- Restart Chrome completely
- Check desktop app is running and unlocked

---

## Quick Reference

### Common Commands

```bash
# Unlock vault (stores session, loads tokens)
bw unlock          # Full
bw u               # Shortcut

# Lock vault (clears session and tokens)
bw lock

# Check status
bw status

# Get password
bw get "GitHub"    # Full
bw g "GitHub"      # Shortcut

# Copy to clipboard
bw copy "GitHub"   # Full
bw c "GitHub"      # Shortcut

# List items
bw list items

# Search items
bw list items --search github

# Reload tokens manually
load_bw_secrets
```

### File Locations

| File | Purpose |
|------|---------|
| `~/.bash/functions/bitwarden.bash` | Enhanced CLI wrapper |
| `~/.bash/exports/bitwarden.bash` | SSH agent config |
| `~/.bash/completions/bitwarden.bash` | Tab completion |
| `/run/user/$UID/bw-session` | Session token (tmpfs) |
| `/run/user/$UID/bw-*` | Development tokens (tmpfs) |
| `~/.bitwarden-ssh-agent.sock` | SSH agent socket |

---

**Document Version:** 2.1
**Author:** Sebastian
**Last Updated:** 2026-09-12
**System:** Ubuntu 24.04 with Bitwarden integrated setup
