# Script Organization Guide

Complete guide to scripts and utilities in this dotfiles repository.

**Last Updated:** 2025-10-20

---

## Directory Structure

```
dotfiles/
├── bin/                       # User utilities (stowed to ~/bin)
│   └── bin/
│       ├── docker-clean       # Docker cleanup utility
│       ├── dotfiles-backup    # Quick dotfiles backup
│       ├── dotfiles-update    # Update and restow dotfiles
│       └── switch-theme       # Oh-my-posh theme switcher
│
├── scripts/                   # Installation & maintenance (NOT stowed)
│   ├── setup/
│   │   ├── bootstrap.sh       # Automated initial setup
│   │   ├── install-docker.sh  # Docker Engine installation
│   │   ├── install-fonts.sh   # Nerd Fonts installation
│   │   ├── install-ghostty.sh # Ghostty terminal installation
│   │   ├── install-node.sh    # Node.js + npm globals
│   │   └── install-uv-tools.sh # UV Python tools
│   │
│   ├── maintenance/
│   │   ├── verify-installation.sh  # Verify dotfiles installation
│   │   └── verify-auth.sh          # Verify authentication setup
│   │
│   └── utils/
│       ├── manual-backup.sh        # Manual backup utility
│       └── legacy-ghostty/         # Deprecated scripts (reference only)
│
└── [other stow packages...]
```

---

## Script Categories

### 1. User Utilities (`bin/`)

**Location:** `~/dotfiles/bin/bin/` → Stowed to `~/bin/`
**In PATH:** ✅ Yes (added by `.bash/path`)
**Purpose:** Daily-use utilities you can run from anywhere

#### Available Commands

| Command | Description | Usage |
|---------|-------------|-------|
| `dotfiles-update` | Pull latest changes and restow | `dotfiles-update` |
| `dotfiles-backup` | Create timestamped backup | `dotfiles-backup [dir]` |
| `docker-clean` | Clean Docker cache and images | `docker-clean [--all]` |
| `switch-theme` | Change oh-my-posh theme | `switch-theme` |

**Example Usage:**
```bash
# Update dotfiles from git
dotfiles-update

# Create quick backup
dotfiles-backup

# Clean Docker (keep images)
docker-clean

# Clean Docker (remove all)
docker-clean --all

# Switch prompt theme
switch-theme
```

---

### 2. Setup Scripts (`scripts/setup/`)

**Location:** `~/dotfiles/scripts/setup/`
**In PATH:** ❌ No (run with explicit path)
**Purpose:** One-time installation and setup

#### bootstrap.sh
**Purpose:** Automated dotfiles installation and configuration

**What it does:**
1. Checks prerequisites (git, stow)
2. Optionally installs Homebrew
3. Detects and handles conflicts
4. Installs all dotfiles packages via stow
5. Verifies installation
6. Creates machine-specific config files

**Usage:**
```bash
cd ~/dotfiles
./scripts/setup/bootstrap.sh
```

**When to use:**
- Fresh machine setup
- Initial dotfiles installation
- After cloning dotfiles to new system

---

#### install-docker.sh
**Purpose:** Install Docker Engine via official repository

**What it does:**
1. Removes old Docker packages
2. Adds Docker's GPG key and repository
3. Installs Docker CE, CLI, and plugins
4. Adds user to docker group
5. Enables Docker service

**Usage:**
```bash
cd ~/dotfiles
./scripts/setup/install-docker.sh
# Log out and back in for group changes
```

**Installed:**
- Docker CE 28.5.1
- Docker Compose v2.40.1
- Docker Buildx v0.29.1

---

#### install-fonts.sh
**Purpose:** Download and install Nerd Fonts

**What it does:**
1. Downloads JetBrainsMono, FiraCode, Meslo
2. Extracts to `~/.local/share/fonts/`
3. Updates font cache

**Usage:**
```bash
cd ~/dotfiles
./scripts/setup/install-fonts.sh
```

**Installed:** 186 font files (Nerd Fonts v3.2.1)

---

#### install-node.sh
**Purpose:** Install Node.js via fnm and global npm packages

**What it does:**
1. Installs Node.js 20 (default) and 22 via fnm
2. Sets Node 20 as default version
3. Installs global npm packages (@anthropic-ai/claude-code)

**Usage:**
```bash
cd ~/dotfiles
./scripts/setup/install-node.sh
```

**Installed:**
- Node.js v20 (default)
- Node.js v22
- @anthropic-ai/claude-code (Claude Code CLI)

---

#### install-uv-tools.sh
**Purpose:** Install Python CLI tools via uv

**What it does:**
1. Installs claude-code-tools via uv tool
2. Verifies installation

**Usage:**
```bash
cd ~/dotfiles
./scripts/setup/install-uv-tools.sh
```

**Installed:**
- claude-code-tools (provides: tmux-cli, aichat, env-safe, gdoc2md, md2gdoc, vault)

---

### 3. Maintenance Scripts (`scripts/maintenance/`)

**Location:** `~/dotfiles/scripts/maintenance/`
**In PATH:** ❌ No (run with explicit path)
**Purpose:** Verification and system checks

#### verify-installation.sh
**Purpose:** Comprehensive dotfiles installation verification

**What it checks:**
- Prerequisites (git, stow, Homebrew)
- Repository status
- All 15 stow packages (bash, bin, git, gtk, ghostty, oh-my-posh, yazi, micro, htop, btop, eza, fzf, glow, lazygit, lazydocker, ripgrep)
- 22 critical symlinks (includes ~/bin utilities and tool configs)
- Broken symlinks
- Homebrew packages
- Key tools availability (13 tools including gh, glab, composer, bw)
- Shell configuration (PATH, Homebrew, ~/bin)
- Authentication setup (Bitwarden, tokens, SSH agent)
- System configuration (sudoers)
- Security (no secrets committed)
- Documentation completeness

**Usage:**
```bash
cd ~/dotfiles
./scripts/maintenance/verify-installation.sh
```

**Output:** Pass/Warn/Fail report with detailed analysis

---

#### verify-auth.sh
**Purpose:** Comprehensive authentication setup verification

**What it checks:**
- Bitwarden CLI installation and session
- Development tokens (GITHUB_TOKEN, GITLAB_TOKEN, COMPOSER_AUTH)
- SSH agent (Bitwarden SSH Agent)
- GitHub CLI (gh) configuration and authentication
- GitLab CLI (glab) configuration for self-hosted instance
- Composer authentication
- tmpfs storage (RAM-only secrets in /run/user/$UID/)
- System configuration (Homebrew sudoers)

**Usage:**
```bash
cd ~/dotfiles
./scripts/maintenance/verify-auth.sh

# Or via Makefile
make verify-auth
```

**Output:** Comprehensive authentication status with color-coded results

**When to use:**
- After initial authentication setup
- Troubleshooting authentication issues
- Verifying Bitwarden integration
- Checking token availability

---

### 4. Utility Scripts (`scripts/utils/`)

**Location:** `~/dotfiles/scripts/utils/`
**In PATH:** ❌ No (run with explicit path)
**Purpose:** Miscellaneous helper scripts

#### manual-backup.sh
**Purpose:** Manual backup with custom options

**Usage:**
```bash
cd ~/dotfiles
./scripts/utils/manual-backup.sh
```

---

#### legacy-ghostty/ (Deprecated)
**Purpose:** Historical reference only

**Contents:**
- `install-simple.sh` - Old APT installation
- `install-terminal-tools.sh` - Manual downloads
- `install-glow.sh` - Glow installer
- `install-yazi.sh` - Yazi installer

**Status:** ❌ Deprecated - Use Homebrew and bootstrap.sh instead

See `scripts/utils/legacy-ghostty/README.md` for details.

---

## PATH Configuration

### How ~/bin Gets Added to PATH

From `~/.bash/path`:
```bash
if [ -d "$HOME/bin" ]; then
    export PATH="$HOME/bin:$PATH"
fi
```

**After sourcing ~/.bashrc:**
```bash
$ which dotfiles-update
/home/sebastian/bin/dotfiles-update

$ which docker-clean
/home/sebastian/bin/docker-clean
```

---

## Adding New Scripts

### User Utility (Daily Use)

1. Create script in `~/dotfiles/bin/bin/`:
```bash
cd ~/dotfiles/bin/bin
nano my-script
chmod +x my-script
```

2. Restow bin package:
```bash
cd ~/dotfiles
stow -R bin
```

3. Test:
```bash
which my-script
my-script --help
```

---

### Setup Script (Installation)

1. Create in `~/dotfiles/scripts/setup/`:
```bash
cd ~/dotfiles/scripts/setup
nano install-something.sh
chmod +x install-something.sh
```

2. Document in PACKAGES.md

3. Run explicitly:
```bash
./scripts/setup/install-something.sh
```

---

### Maintenance Script (Verification)

1. Create in `~/dotfiles/scripts/maintenance/`:
```bash
cd ~/dotfiles/scripts/maintenance
nano check-something.sh
chmod +x check-something.sh
```

2. Call from Makefile if appropriate

---

## Makefile Integration

The Makefile provides shortcuts for common operations:

```bash
make install      # Installs all packages (includes bin/)
make uninstall    # Removes all symlinks
make update       # Git pull + restow
make test         # Dry run
make bin          # Install only bin/ package
```

**Relevant targets:**
```makefile
install: bash bin git gtk ghostty oh-my-posh yazi micro htop btop
uninstall: bash bin git gtk ghostty oh-my-posh yazi micro htop btop
update: bash bin git gtk ghostty oh-my-posh yazi micro htop btop
```

---

## Script Best Practices

### ✅ Good Practices

1. **Shebang:** Always start with `#!/bin/bash`
2. **Error handling:** Use `set -e` to exit on errors
3. **Functions:** Use colored output functions (info, warn, error)
4. **Idempotency:** Safe to run multiple times
5. **Documentation:** Add usage comment at top
6. **Permissions:** Make executable with `chmod +x`

### Example Template

```bash
#!/bin/bash
# script-name - Brief description
# Usage: script-name [options]

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Main logic here
info "Starting..."
# ...
info "✓ Complete!"
```

---

## Troubleshooting

### Scripts not in PATH

**Problem:** `dotfiles-update: command not found`

**Solutions:**
```bash
# 1. Reload shell
source ~/.bashrc

# Or
exec bash

# 2. Verify ~/bin exists
ls -la ~/bin

# 3. Check PATH
echo $PATH | tr ':' '\n' | grep bin

# 4. Restow bin package
cd ~/dotfiles && stow -R bin
```

---

### Permission denied

**Problem:** `bash: ./script: Permission denied`

**Solution:**
```bash
chmod +x ~/dotfiles/bin/bin/script-name
# Or
chmod +x ~/dotfiles/scripts/setup/script-name.sh
```

---

### Script not found after stowing

**Problem:** Stowed but script doesn't appear in ~/bin

**Solution:**
```bash
# Check stow structure
ls -la ~/dotfiles/bin/bin/

# Unstow and restow
cd ~/dotfiles
stow -D bin
stow -v bin

# Verify symlinks
ls -la ~/bin/
```

---

## Migration from Old Structure

### What Changed

**Before:**
```
dotfiles/
├── bootstrap.sh
├── install-docker.sh
├── install-fonts.sh
├── manual-backup.sh
├── verify-installation.sh
└── ghostty/.config/ghostty/
    ├── install-glow.sh
    ├── install-simple.sh
    ├── install-terminal-tools.sh
    └── install-yazi.sh
```

**After:**
```
dotfiles/
├── bin/bin/                 # NEW: User utilities
├── scripts/
│   ├── setup/              # Moved: Installation scripts
│   ├── maintenance/        # Moved: Verification scripts
│   └── utils/
│       └── legacy-ghostty/ # Moved: Old ghostty scripts
```

**Benefits:**
- ✅ Clear separation of concerns
- ✅ User scripts in PATH via ~/bin
- ✅ Installation scripts organized
- ✅ Easy to find and maintain
- ✅ Follows Unix best practices

---

## Quick Reference

| Task | Command |
|------|---------|
| Update dotfiles | `dotfiles-update` |
| Backup dotfiles | `dotfiles-backup` |
| Clean Docker | `docker-clean` |
| Switch theme | `switch-theme` |
| Fresh install | `./scripts/setup/bootstrap.sh` |
| Install Docker | `./scripts/setup/install-docker.sh` |
| Install fonts | `./scripts/setup/install-fonts.sh` |
| Install Node.js | `./scripts/setup/install-node.sh` |
| Install UV tools | `./scripts/setup/install-uv-tools.sh` |
| Verify setup | `./scripts/maintenance/verify-installation.sh` |
| Verify auth | `./scripts/maintenance/verify-auth.sh` or `make verify-auth` |
| Manual backup | `./scripts/utils/manual-backup.sh` |

---

**Document Version:** 1.0
**Last Updated:** 2025-10-20
**Maintained by:** Sebastian
