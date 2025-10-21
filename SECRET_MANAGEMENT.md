# Secret Management Strategy - 2025 Best Practices

**Last Updated:** 2025-10-20
**Research Validated:** ✅ Current industry standards

---

## Table of Contents

1. [Critical Principles](#critical-principles)
2. [Architecture Overview](#architecture-overview)
3. [SSH Key Management](#ssh-key-management)
4. [Development Secrets (Pass + GPG)](#development-secrets-pass--gpg)
5. [Company vs Personal Boundaries](#company-vs-personal-boundaries)
6. [Implementation Guide](#implementation-guide)
7. [Backup & Recovery](#backup--recovery)
8. [References & Resources](#references--resources)

---

## Critical Principles

### 🔴 The Golden Rule: Separate Company and Personal Secrets

```
┌─────────────────────────────────────────────┐
│ NEVER MIX COMPANY AND PERSONAL SECRETS     │
├─────────────────────────────────────────────┤
│ Company Bitwarden → Work secrets ONLY      │
│ Personal solution → YOUR personal secrets  │
└─────────────────────────────────────────────┘
```

**Why This Matters:**
- **Job Changes:** Leave company → lose access → lose personal tokens
- **Privacy:** Personal side projects shouldn't be in company vault
- **Legal:** Company may claim ownership of secrets in their systems
- **Policy Changes:** Company can change access policies at any time
- **Audit Logs:** Company can see when you access what

---

## Architecture Overview

```
┌───────────────────────────────────────────────────────────┐
│ SECRET MANAGEMENT ARCHITECTURE                            │
├───────────────────────────────────────────────────────────┤
│                                                           │
│ SSH Keys → ~/.ssh/ (encrypted with passphrases)          │
│   │                                                       │
│   ├─ Backup: GPG-encrypted tarballs                      │
│   ├─ Storage: Local filesystem only                      │
│   └─ Managed: Separate from password managers            │
│                                                           │
│ Development Secrets → Pass + GPG + Git                   │
│   │                                                       │
│   ├─ GitHub/GitLab tokens                                │
│   ├─ Composer auth.json                                  │
│   ├─ API keys (Jira, Confluence, etc.)                   │
│   ├─ Database credentials                                │
│   ├─ SSH key passphrases                                 │
│   └─ Any scriptable/automatable secrets                  │
│                                                           │
│ Personal Accounts → 1Password Personal (optional)        │
│   │                                                       │
│   ├─ Banking, shopping, subscriptions                    │
│   ├─ Personal email accounts                             │
│   ├─ Social media credentials                            │
│   └─ General web logins                                  │
│                                                           │
│ Work Secrets → Company Bitwarden                         │
│   │                                                       │
│   ├─ Company-issued credentials                          │
│   ├─ Shared team secrets                                 │
│   ├─ Work service accounts                               │
│   └─ Company-specific tokens                             │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

---

## SSH Key Management

### Current Best Practices (2025)

**Algorithm:** Ed25519 (modern, secure, fast)
**Encryption:** AES-256 with strong passphrase
**Rotation:** Every 2 years, embed year in filename

### Generating Keys

```bash
# Generate Ed25519 key with current year in name
ssh-keygen -t ed25519 \
  -C "sebastian@$(hostname)-$(date +%Y)" \
  -f ~/.ssh/id_ed25519_github_2025

# Repeat for each service/machine
ssh-keygen -t ed25519 -C "sebastian@$(hostname)-2025" -f ~/.ssh/id_ed25519_gitlab_2025
ssh-keygen -t ed25519 -C "sebastian@$(hostname)-2025" -f ~/.ssh/id_ed25519_work_2025
```

### SSH Directory Structure

```
~/.ssh/
├── config                           # SSH client config (safe to version)
├── id_ed25519_github_2025          # Private key (NEVER share)
├── id_ed25519_github_2025.pub      # Public key (safe to share)
├── id_ed25519_gitlab_2025          # Private key
├── id_ed25519_gitlab_2025.pub      # Public key
├── id_ed25519_work_2025            # Private key
├── id_ed25519_work_2025.pub        # Public key
└── authorized_keys                  # Incoming SSH (optional)
```

### SSH Config Example

```ssh
# ~/.ssh/config

# GitHub Personal
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_2025
    IdentitiesOnly yes

# GitLab Personal
Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_ed25519_gitlab_2025
    IdentitiesOnly yes

# Work GitLab
Host gitlab.company.com
    HostName gitlab.company.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work_2025
    IdentitiesOnly yes

# Default settings for all hosts
Host *
    AddKeysToAgent yes
    UseKeychain yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### Key Management Best Practices

✅ **DO:**
- Use different key per service (GitHub, GitLab, work servers)
- Use different key per machine (laptop, desktop, VM)
- Rotate every 2 years (embed year in filename)
- Use strong passphrase on each private key (16+ characters)
- Use ssh-agent for convenience (automatically loads keys)
- Keep GPG-encrypted backups
- Store SSH config in dotfiles/stow

❌ **DO NOT:**
- Store private keys in password managers (Bitwarden, 1Password, etc.)
- Store private keys in Git (even encrypted repos)
- Use same key for personal and work
- Use RSA keys (Ed25519 is superior)
- Share private keys via email, Slack, cloud storage
- Leave private keys unencrypted (no passphrase)

### Backup Strategy

```bash
# Create encrypted backup of entire .ssh directory
tar -czf - ~/.ssh | gpg -c --cipher-algo AES256 > ~/backups/ssh_backup_$(date +%Y%m%d).tar.gz.gpg

# Store backup on:
# - External encrypted USB drive
# - Personal encrypted cloud storage (NOT company cloud)
# - Secure local backup system
```

### Recovery Process

```bash
# Decrypt and restore
gpg -d ~/backups/ssh_backup_20251020.tar.gz.gpg | tar -xzf - -C ~/

# Set correct permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
chmod 644 ~/.ssh/config
```

---

## Development Secrets (Pass + GPG)

### Why Pass?

**Pass** (the Standard Unix Password Manager) is the recommended tool for development secrets:

✅ **Advantages:**
- **Simple & Transparent:** GPG-encrypted files in Git - you see exactly what's happening
- **Local Control:** No cloud dependencies, you control everything
- **Git Integration:** Built-in version control and sync
- **Unix Philosophy:** Composable with shell scripts and tools
- **Team-Ready:** Multi-GPG-key support for shared secrets
- **Open Source:** Auditable, no vendor lock-in
- **Free:** No subscription costs

📊 **Comparison with Alternatives:**

| Feature | Pass | Bitwarden CLI | 1Password CLI |
|---------|------|---------------|---------------|
| Biometric unlock | ❌ | ❌ (session tokens) | ✅ Touch ID |
| Git integration | ✅ Built-in | ❌ | ❌ |
| Team sharing | ✅ Multi-GPG | ✅ Enterprise | ✅ Enterprise |
| Script-friendly | ✅ Simple | ⚠️ Complex | ✅ Good |
| Speed | ✅ Fast | ❌ Slow (server calls) | ✅ Fast |
| Cost | Free | $10/user/mo | $8/user/mo |
| Open Source | ✅ | ✅ | ❌ |

### Installation

```bash
# Install pass
brew install pass

# Install pass extensions (optional)
brew install pass-otp  # For TOTP/2FA codes
```

### Setup

```bash
# 1. Create GPG key (if you don't have one)
gpg --full-generate-key
# Choose: (1) RSA and RSA, 4096 bits, no expiration
# Use strong passphrase!

# 2. Get your GPG key ID
gpg --list-secret-keys --keyid-format=long
# Look for: sec   rsa4096/YOUR_KEY_ID

# 3. Initialize pass
pass init YOUR_KEY_ID

# 4. Enable Git integration
pass git init

# 5. Add remote (private Git repo - GitHub/GitLab)
pass git remote add origin git@github.com:yourusername/password-store.git

# 6. Initial push
pass git push -u origin main
```

### Directory Structure

```
~/.password-store/
├── .git/                        # Git repository
├── .gpg-id                      # GPG key ID used for encryption
│
├── dev/
│   ├── github/
│   │   ├── personal-token.gpg
│   │   └── work-token.gpg
│   ├── gitlab/
│   │   └── token.gpg
│   ├── jira/
│   │   └── api-key.gpg
│   ├── confluence/
│   │   └── api-token.gpg
│   └── composer/
│       └── auth.json.gpg
│
├── ssh/
│   ├── github-passphrase.gpg
│   ├── gitlab-passphrase.gpg
│   └── work-passphrase.gpg
│
├── databases/
│   ├── postgres-local.gpg
│   └── mysql-dev.gpg
│
└── personal/
    ├── email-accounts.gpg
    └── backup-codes.gpg
```

### Usage Examples

```bash
# Store a secret (interactive prompt)
pass insert dev/github/token

# Store multiline secret (like auth.json)
pass insert -m dev/composer/auth
# Paste content, then Ctrl+D

# Retrieve secret
pass show dev/github/token

# Copy to clipboard (auto-clears after 45s)
pass -c dev/github/token

# Generate random password
pass generate dev/newservice/password 32

# Edit existing secret
pass edit dev/github/token

# Remove secret
pass rm dev/oldservice/token

# Search for secrets
pass grep "github"

# Show directory tree
pass

# Git operations
pass git status
pass git log
pass git push
pass git pull
```

### Integration with Shell Scripts

#### In ~/.bash/tools or ~/.bash/functions

```bash
# Function to load secrets into environment
load_dev_secrets() {
    export GITHUB_TOKEN=$(pass show dev/github/token)
    export GITLAB_TOKEN=$(pass show dev/gitlab/token)
    export JIRA_API_KEY=$(pass show dev/jira/api-key)
    export COMPOSER_AUTH=$(pass show dev/composer/auth)
    echo "✓ Development secrets loaded"
}

# Function to unload secrets
unload_dev_secrets() {
    unset GITHUB_TOKEN
    unset GITLAB_TOKEN
    unset JIRA_API_KEY
    unset COMPOSER_AUTH
    echo "✓ Development secrets unloaded"
}

# Quick access aliases
alias pass-github='pass -c dev/github/token'
alias pass-gitlab='pass -c dev/gitlab/token'
alias pass-composer='pass show dev/composer/auth'
```

#### Usage in Projects

```bash
# In your project scripts
#!/bin/bash

# Load GitHub token from pass
GITHUB_TOKEN=$(pass show dev/github/token)

# Use in API calls
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user/repos
```

#### Composer Integration

```bash
# Store Composer auth
pass insert -m dev/composer/auth
# Paste your auth.json content

# Load for composer commands
export COMPOSER_AUTH=$(pass show dev/composer/auth)
composer install
```

### Team Sharing (Advanced)

```bash
# Initialize with multiple GPG keys for team
pass init 0x1234ABCD 0x5678EFGH

# Different folders can have different keys
cd ~/.password-store/personal
pass init 0x1234ABCD  # Only your key

cd ~/.password-store/team
pass init 0x1234ABCD 0x5678EFGH  # You + teammate
```

### Backup & Sync

```bash
# Push changes to remote
pass git push

# Pull changes from another machine
pass git pull

# Full backup (including GPG keys)
gpg --export-secret-keys YOUR_KEY_ID > ~/backups/gpg-secret.key
gpg --export YOUR_KEY_ID > ~/backups/gpg-public.key
tar -czf ~/backups/password-store.tar.gz ~/.password-store/
```

---

## Company vs Personal Boundaries

### Use Company Bitwarden For:

✅ **Work-Related Only:**
- Company-issued credentials (email, SSO, etc.)
- Shared team secrets (deploy keys, service accounts)
- Company service accounts (AWS, Azure, etc.)
- Work-related API tokens that belong to company
- Credentials for company-owned infrastructure

### Use Personal Solution (Pass/1Password) For:

✅ **Your Personal/Development:**
- Personal GitHub/GitLab accounts and tokens
- Personal project API keys
- Development tool credentials
- Personal email accounts
- Side project secrets
- SSH key passphrases for personal keys
- Personal learning platform accounts

### Gray Areas - Default to Personal:

When in doubt, ask: "If I leave this company tomorrow, do I need this secret?"
- If YES → Personal solution
- If NO → Company Bitwarden

**Examples:**
- GitHub personal account token for side projects → **Personal**
- GitHub token for company repos → **Company**
- Personal domain registrar → **Personal**
- Company domain registrar → **Company**

---

## Implementation Guide

### Phase 1: Set Up Pass (Week 1)

```bash
# 1. Install
brew install pass

# 2. Create/verify GPG key
gpg --list-secret-keys

# If no key exists:
gpg --full-generate-key

# 3. Initialize pass
pass init $(gpg --list-secret-keys --keyid-format=long | grep sec | awk '{print $2}' | cut -d'/' -f2)

# 4. Create directory structure
pass insert -m dev/README << 'EOF'
Development secrets directory
Store API tokens, keys, and credentials here
EOF

# 5. Set up Git
pass git init
pass git remote add origin git@github.com:yourusername/password-store-private.git
pass git push -u origin main
```

### Phase 2: Migrate Secrets (Week 1-2)

```bash
# Migrate from old machine or recreate
pass insert dev/github/token          # GitHub personal access token
pass insert dev/gitlab/token          # GitLab personal access token
pass insert dev/jira/api-key         # Jira API key
pass insert -m dev/composer/auth     # Composer auth.json

# Store SSH passphrases (optional, but useful)
pass insert ssh/github-passphrase
pass insert ssh/gitlab-passphrase
```

### Phase 3: Generate SSH Keys (Week 2)

```bash
# GitHub
ssh-keygen -t ed25519 -C "sebastian@$(hostname)-2025" -f ~/.ssh/id_ed25519_github_2025

# GitLab
ssh-keygen -t ed25519 -C "sebastian@$(hostname)-2025" -f ~/.ssh/id_ed25519_gitlab_2025

# Work
ssh-keygen -t ed25519 -C "sebastian@$(hostname)-2025" -f ~/.ssh/id_ed25519_work_2025

# Add public keys to services
cat ~/.ssh/id_ed25519_github_2025.pub  # Copy to GitHub settings
cat ~/.ssh/id_ed25519_gitlab_2025.pub  # Copy to GitLab settings
```

### Phase 4: SSH Config Stow Package (Week 2)

```bash
# Create SSH stow package structure
mkdir -p ~/dotfiles/ssh/.ssh

# Create config file
cat > ~/dotfiles/ssh/.ssh/config << 'EOF'
# GitHub Personal
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_2025
    IdentitiesOnly yes

# GitLab Personal
Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_ed25519_gitlab_2025
    IdentitiesOnly yes

# Default settings
Host *
    AddKeysToAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

# Stow the SSH config (NOT the keys!)
cd ~/dotfiles
stow ssh

# Verify
ls -la ~/.ssh/config  # Should be symlink to dotfiles
```

### Phase 5: Shell Integration (Week 2)

Add to `~/dotfiles/bash/.bash/tools`:

```bash
# Pass integration functions
if command -v pass &> /dev/null; then
    # Load development secrets
    load_dev_secrets() {
        export GITHUB_TOKEN=$(pass show dev/github/token 2>/dev/null)
        export GITLAB_TOKEN=$(pass show dev/gitlab/token 2>/dev/null)
        export JIRA_API_KEY=$(pass show dev/jira/api-key 2>/dev/null)
        export COMPOSER_AUTH=$(pass show dev/composer/auth 2>/dev/null)
        echo "✓ Development secrets loaded into environment"
    }

    # Unload secrets from environment
    unload_dev_secrets() {
        unset GITHUB_TOKEN GITLAB_TOKEN JIRA_API_KEY COMPOSER_AUTH
        echo "✓ Development secrets cleared from environment"
    }

    # Quick clipboard access
    alias pass-gh='pass -c dev/github/token'
    alias pass-gl='pass -c dev/gitlab/token'
    alias pass-jira='pass -c dev/jira/api-key'

    # Show pass tree
    alias pass-tree='pass'
fi
```

### Phase 6: Create Backup Scripts (Week 3)

Create `~/dotfiles/backup-secrets.sh`:

```bash
#!/bin/bash
# Backup script for secrets

BACKUP_DIR="$HOME/backups/secrets"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "Creating encrypted backups..."

# Backup SSH directory (encrypted)
echo "→ Backing up SSH keys..."
tar -czf - ~/.ssh | gpg -c --cipher-algo AES256 > "$BACKUP_DIR/ssh_$DATE.tar.gz.gpg"

# Backup GPG keys
echo "→ Backing up GPG keys..."
gpg --export-secret-keys --armor > "$BACKUP_DIR/gpg_secret_$DATE.asc"
gpg --export --armor > "$BACKUP_DIR/gpg_public_$DATE.asc"

# Backup password store (already encrypted)
echo "→ Backing up password store..."
tar -czf "$BACKUP_DIR/password_store_$DATE.tar.gz" ~/.password-store/

echo ""
echo "✓ Backups created in $BACKUP_DIR"
echo ""
echo "IMPORTANT: Store these backups on:"
echo "  - External encrypted USB drive"
echo "  - Personal encrypted cloud storage"
echo "  - Secure off-site location"
echo ""
echo "DO NOT store on company systems!"
```

---

## Backup & Recovery

### What to Backup

1. **SSH Keys** (encrypted)
2. **GPG Keys** (public and private)
3. **Password Store** (~/.password-store/)
4. **SSH Config** (already in dotfiles/stow)

### Backup Schedule

- **Monthly:** Full backup to external drive
- **After key generation:** Immediate backup
- **Before key rotation:** Backup old keys before deletion

### Backup Storage Locations

✅ **Safe:**
- Encrypted external USB drive (stored off-site)
- Personal encrypted cloud storage (Mega, Tresorit, etc.)
- Personal NAS with encryption
- Secure personal backup service

❌ **Unsafe:**
- Company cloud storage (Dropbox, OneDrive, etc.)
- Unencrypted USB drives
- Company-managed systems
- Email attachments

### Recovery Procedure

#### Scenario 1: New Machine Setup

```bash
# 1. Install essentials
sudo apt update && sudo apt install gnupg pass git

# 2. Restore GPG keys
gpg --import ~/backups/gpg_public_20251020.asc
gpg --import ~/backups/gpg_secret_20251020.asc

# 3. Trust your key
gpg --edit-key YOUR_KEY_ID
# Type: trust, then 5 (ultimate), then quit

# 4. Clone password store
git clone git@github.com:yourusername/password-store-private.git ~/.password-store

# 5. Restore SSH keys (if needed)
gpg -d ~/backups/ssh_20251020.tar.gz.gpg | tar -xzf - -C ~/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
```

#### Scenario 2: Key Compromise

```bash
# 1. Generate new keys immediately
ssh-keygen -t ed25519 -C "sebastian@$(hostname)-2025" -f ~/.ssh/id_ed25519_github_2025_NEW

# 2. Update services (GitHub, GitLab, etc.)
# Add new public key, remove old key

# 3. Revoke old GPG key (if compromised)
gpg --gen-revoke YOUR_OLD_KEY_ID > revocation_cert.asc
gpg --import revocation_cert.asc
gpg --send-keys YOUR_OLD_KEY_ID

# 4. Create new GPG key and re-encrypt password store
pass init NEW_GPG_KEY_ID
```

---

## References & Resources

### Official Documentation
- **Pass:** https://www.passwordstore.org/
- **SSH Best Practices:** https://www.brandonchecketts.com/archives/ssh-ed25519-key-best-practices-for-2025
- **GPG Documentation:** https://gnupg.org/documentation/

### Tools
- **pass** - Unix password manager
- **pass-otp** - TOTP/2FA extension for pass
- **qtpass** - GUI for pass (optional)
- **browserpass** - Browser extension for pass
- **Android Password Store** - Mobile app for pass

### Key Algorithms (2025)
- **SSH:** Ed25519 (modern, secure, fast)
- **GPG:** RSA 4096 or Ed25519
- **Avoid:** DSA, RSA < 2048, ECDSA (government concerns)

### Security Principles
1. **Defense in Depth:** Multiple layers of security
2. **Least Privilege:** Minimal necessary access
3. **Zero Trust:** Verify everything, trust nothing
4. **Key Rotation:** Regular key updates (2-year cycle)
5. **Separation of Concerns:** Personal vs work secrets

### Key Rotation Schedule
| Key Type | Rotation Interval | Next Rotation |
|----------|------------------|---------------|
| SSH Keys | 2 years | 2027 |
| GPG Keys | 3-5 years | 2028-2030 |
| API Tokens | 6-12 months | As needed |
| Passwords | 3-6 months | As needed |

---

## Quick Reference Commands

### Pass Commands
```bash
pass                          # Show all passwords
pass show dev/github/token    # Display secret
pass -c dev/github/token      # Copy to clipboard
pass insert dev/new/secret    # Add new secret
pass generate service/pw 32   # Generate password
pass edit dev/github/token    # Edit secret
pass rm dev/old/secret        # Remove secret
pass git push                 # Sync to remote
pass git pull                 # Sync from remote
pass grep "github"            # Search secrets
```

### SSH Commands
```bash
ssh-keygen -t ed25519 -C "comment" -f ~/.ssh/keyname
ssh-add ~/.ssh/keyname        # Add key to agent
ssh-add -l                    # List loaded keys
ssh-copy-id -i key.pub user@host
```

### GPG Commands
```bash
gpg --list-keys               # List public keys
gpg --list-secret-keys        # List private keys
gpg --export -a KEY_ID        # Export public key
gpg --export-secret-key -a    # Export private key
gpg --import keyfile          # Import key
gpg -c file                   # Encrypt file
gpg -d file.gpg               # Decrypt file
```

---

## Action Items

- [ ] Install pass and create GPG key
- [ ] Initialize password store with Git
- [ ] Migrate development secrets to pass
- [ ] Generate Ed25519 SSH keys for each service
- [ ] Create SSH config in dotfiles/stow
- [ ] Add shell integration functions
- [ ] Create backup script
- [ ] Perform initial encrypted backup
- [ ] Store backup in secure location
- [ ] Document recovery process
- [ ] Test recovery on test VM/container
- [ ] Set calendar reminder for key rotation (2027)

---

**Document Version:** 1.0
**Author:** Sebastian
**Last Review:** 2025-10-20
**Next Review:** 2026-01-01
