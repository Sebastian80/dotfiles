# Script Organization Guide

Complete guide to scripts and utilities in this dotfiles repository.

**Last Updated:** 2026-09-12

---

## Directory Structure

```text
dotfiles/
├── bin/                            # User utilities (stowed to ~/bin)
│   └── bin/
│       ├── claude-agent-watch      # Render a Claude Code subagent transcript live
│       ├── display-scale           # Scale the external monitor (mixed-DPI X11)
│       ├── docker-clean            # Docker cleanup utility
│       ├── dotfiles-backup         # Quick dotfiles backup
│       ├── dotfiles-update         # Update and restow dotfiles
│       ├── herdr-action-palette    # Fuzzy-pick and run any herdr plugin action
│       ├── herdr-launch            # Open/focus the chromeless Herdr Ghostty window
│       ├── herdr-tool-tab          # Run a tool in a new focused herdr tab
│       ├── jira-my-tickets         # List my unresolved Jira tickets, one per line
│       ├── switch-theme            # Oh-my-posh theme switcher
│       └── window-to-screen        # Move a window to another monitor
│
├── scripts/                   # Installation & maintenance (NOT stowed)
│   ├── setup/
│   │   ├── bootstrap.sh       # Automated initial setup
│   │   ├── install-claude.sh  # Claude Code via Anthropic's installer
│   │   ├── install-docker.sh  # Docker Engine installation
│   │   ├── install-fonts.sh   # Nerd Fonts installation
│   │   ├── install-ghostty.sh # Ghostty terminal installation
│   │   ├── install-node.sh    # Node.js + npm globals (--ai for the AI agent CLIs)
│   │   ├── install-pi.sh      # pi coding agent + its sandbox extension
│   │   ├── plank-use-overrides.sh  # Point Plank dock launchers at ~/.local overrides
│   │   └── uninstall.sh       # Remove all dotfiles and installed components
│   │
│   ├── maintenance/
│   │   ├── lint.sh                 # shellcheck + ruff + markdownlint + codespell
│   │   ├── verify-installation.sh  # Verify dotfiles installation
│   │   ├── verify-auth.sh          # Verify authentication setup
│   │   └── claude-settings-sync.sh # Sync live Claude settings to the tracked reference
│   │
│   └── utils/
│       ├── manual-backup.sh        # Manual backup utility
│       └── pre-reinstall-backup.sh # Snapshot home + system config before a reinstall
│
└── [other stow packages...]
```

---

## Script Categories

### 1. User Utilities (`bin/`)

**Location:** `~/dotfiles/bin/bin/` → Stowed to `~/bin/`
**In PATH:** ✅ Yes (added by `.bash/path.bash`)
**Purpose:** Daily-use utilities you can run from anywhere

#### Available Commands

| Command | Description | Usage |
|---------|-------------|-------|
| `dotfiles-update` | Pull latest changes and restow | `dotfiles-update` |
| `dotfiles-backup` | Create timestamped backup | `dotfiles-backup [dir]` |
| `docker-clean` | Clean Docker cache and images | `docker-clean [--all]` |
| `switch-theme` | Change oh-my-posh theme | `switch-theme` |
| `claude-agent-watch` | Render a Claude Code subagent transcript live, for a herdr/tmux pane | `claude-agent-watch <agent-name\|file.jsonl>` |
| `display-scale` | Scale the external monitor down to match the laptop panel (X11 transform) | `display-scale [factor]` |
| `window-to-screen` | Move a window to another monitor without a title bar to drag | `window-to-screen [next\|prev\|MONITOR]` |
| `herdr-launch` | Open, or focus, the maximized chromeless Herdr Ghostty window | `herdr-launch` |
| `herdr-tool-tab` | Run a command in a new focused herdr tab named after it | `herdr-tool-tab LABEL COMMAND...` |
| `herdr-action-palette` | Fuzzy-pick and run any herdr plugin action (prefix+space) | `herdr-action-palette` |
| `jira-my-tickets` | Print my unresolved Jira tickets as `KEY<TAB>summary [status]` | `jira-my-tickets [MAX]` |

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

- Docker CE, Docker Compose, Docker Buildx (latest stable versions)

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

**Installed:** JetBrainsMono, FiraCode, Meslo (Nerd Fonts, latest version)

---

#### install-ghostty.sh

**Purpose:** Install the Ghostty terminal emulator on Linux

**What it does:**

1. Prompts for install method: snap, Ubuntu `.deb` (community-maintained), or build from source
2. For `.deb`: pulls the latest release from the `mkasberg/ghostty-ubuntu` GitHub releases and installs it via `apt`
3. For build-from-source: checks/installs build dependencies (zig, etc.) and compiles
4. Cleans up temp files on exit

**Usage:**

```bash
cd ~/dotfiles
./scripts/setup/install-ghostty.sh
```

**When to use:**

- Fresh machine where Ghostty isn't available via Homebrew
- Upgrading Ghostty to a newer community build than what's in the repos

---

#### install-claude.sh

**Purpose:** Install Claude Code with Anthropic's own installer

**What it does:**

1. Skips silently when `claude` is already on PATH, since Claude Code updates itself
2. Downloads `https://claude.ai/install.sh` to a temp file and runs that file, so a truncated
   download cannot execute half a script
3. Verifies `claude` is on PATH afterwards

**Usage:**

```bash
cd ~/dotfiles
./scripts/setup/install-claude.sh           # install when missing
./scripts/setup/install-claude.sh --check   # report what is installed
./scripts/setup/install-claude.sh --force latest
```

The installer places a versioned build under `~/.local/share/claude/versions` and links
`~/.local/bin/claude` at it. Nothing here is stowed. Usually run through `make install-ai`.

---

#### install-node.sh

**Purpose:** Install Node.js via fnm and global npm packages

**What it does:**

1. Loads `fnm env`, so npm is fnm's and not Homebrew's
2. Installs Node.js 22 and 24 via fnm
3. Sets Node 24 as default version
4. Installs the base global npm packages with detailed output

**Usage:**

```bash
cd ~/dotfiles
./scripts/setup/install-node.sh        # Node versions + base globals
./scripts/setup/install-node.sh --ai   # only the AI agent CLIs
```

**Installed:**

- Node.js v24 (default)
- Node.js v22

**NPM Global Packages:**

| Package | Command | Description | Set |
|---------|---------|-------------|-----|
| pnpm | `pnpm` | Fast, disk-efficient package manager | base |
| @openai/codex | `codex` | OpenAI Codex CLI, also the codex MCP server | `--ai` |
| @google/gemini-cli | `gemini` | Google Gemini CLI | `--ai` |
| agent-browser | `agent-browser` | Browser automation CLI for AI agents | `--ai` |
| repomix | `repomix` | Pack a repository into a single AI-friendly file | `--ai` |

Claude Code is not installed here: it uses its own installer
(`curl -fsSL https://claude.ai/install.sh | bash`) and self-updates.

---

#### install-pi.sh

**Purpose:** Install the pi coding agent and provision its sandbox extension

**What it does:**

1. Installs `@earendil-works/pi-coding-agent` globally under fnm's Node
2. Installs every pi package listed in the stowed `settings.json`
3. Copies the sandbox extension out of pi's own examples and pins
   `@anthropic-ai/sandbox-runtime` forward, past a critical `shell-quote` advisory

**Usage:**

```bash
cd ~/dotfiles
./scripts/setup/install-pi.sh          # install / re-provision
./scripts/setup/install-pi.sh --check  # report what is installed, change nothing
```

Usually run through `make install-ai`, which adds the AI CLIs and the herdr agent integrations.

---

#### uninstall.sh

**Purpose:** Safely remove all dotfiles and installed components

**What it does:**

1. Scans for installed components (stowed dotfiles, Homebrew, Ghostty, fonts, etc.)
2. Shows what will be removed
3. Asks for confirmation before proceeding
4. Unstows all packages, removes components, restores system defaults

**Usage:**

```bash
cd ~/dotfiles
./scripts/setup/uninstall.sh          # Full uninstall (with confirmation)
./scripts/setup/uninstall.sh --dry-run # Preview only, no changes
```

---

### 3. Maintenance Scripts (`scripts/maintenance/`)

**Location:** `~/dotfiles/scripts/maintenance/`
**In PATH:** ❌ No (run with explicit path)
**Purpose:** Verification and system checks

#### lint.sh

**Purpose:** Lint and spellcheck every tracked script and this repo's documentation

**What it does:**

1. Collects tracked scripts by extension, plus the extensionless ones in `bin/` by shebang,
   and tracked Markdown
2. Runs `bash -n` and shellcheck over the shell scripts, ruff over the Python ones,
   markdownlint over the docs, and codespell over all of them
3. Fails on shellcheck errors, on any finding from the other tools, and on shellcheck
   exiting above 1 (which means it never ran); shellcheck's known tail of warnings and
   notes is printed but does not fail

**Usage:**

```bash
make lint                             # every tracked script and doc
./scripts/maintenance/lint.sh FILE    # just these files
```

Excluded by design: `bash/.bash/completions/composer.bash` (vendored Symfony), `SC1090`/`SC1091`
(sources that cannot be followed statically), and a short spelling ignore list (the German Jira
status "Offen" plus Mermaid identifiers from the mermaid skill's references). markdownlint covers
this repo's prose only: `claude/`, `agents/` and `pi/` hold instruction prose for models and
`yazi/` holds vendored flavors, so they are spellchecked but not format-linted. Rules live in
`.markdownlint.jsonc` (120 columns, code blocks and tables exempt).

---

#### verify-installation.sh

**Purpose:** Comprehensive dotfiles installation verification

**What it checks:**

- Prerequisites (git, stow, Homebrew)
- Repository status
- All 20 stow packages (agents, bash, bin, btop, chrome, claude, eza, fzf, ghostty, git, glow, gtk,
  herdr, htop, micro, oh-my-posh, pi, ripgrep, tmux, yazi)
- 19 critical symlinks (includes ~/bin utilities and tool configs)
- Broken symlinks
- Homebrew packages
- Key tools availability (15 tools including gh, glab, composer, bw, docker)
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

#### claude-settings-sync.sh

**Purpose:** Keep the tracked `claude/.claude/settings.reference.json` equal to the live, gitignored `~/.claude/settings.json`

**Usage:**

```bash
./scripts/maintenance/claude-settings-sync.sh          # show drift, exit 1 if any
./scripts/maintenance/claude-settings-sync.sh --apply  # copy live → reference
```

**When to use:**

- After changing Claude Code settings (plugins, permissions, auto mode, model)
- In a session retro, before committing dotfiles

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

#### pre-reinstall-backup.sh

**Purpose:** Copy everything a fresh install cannot regenerate onto an external disk:
`$HOME` minus caches and package stores, root-owned config (NetworkManager
connections, `/etc/hosts`, grub kernel params, custom AppArmor/modprobe/sysctl,
local CAs, apt sources), exported VPN profiles and package inventories.
Re-runs are incremental; a second rsync pass verifies the copy.

**Usage:**

```bash
cd ~/dotfiles
./scripts/utils/pre-reinstall-backup.sh --dry-run /media/$USER/backup   # stats only
./scripts/utils/pre-reinstall-backup.sh /media/$USER/backup             # needs sudo once
```

---

## PATH Configuration

### How ~/bin Gets Added to PATH

From `~/.bash/path.bash`:

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

1. Restow bin package:

```bash
cd ~/dotfiles
stow -R bin
```

1. Test:

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

1. Document it in this file (SCRIPTS.md)

2. Run explicitly:

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

1. Call from Makefile if appropriate

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
# PACKAGES variable (defined once, used by install/uninstall/update):
PACKAGES := bash bin claude git gtk ghostty oh-my-posh tmux yazi micro htop btop eza fzf glow ripgrep herdr pi agents chrome
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

```text
dotfiles/
├── bootstrap.sh
├── install-docker.sh
├── install-fonts.sh
├── manual-backup.sh
├── pre-reinstall-backup.sh
├── verify-installation.sh
└── ghostty/.config/ghostty/
    ├── install-glow.sh
    ├── install-simple.sh
    ├── install-terminal-tools.sh
    └── install-yazi.sh
```

**After:**

```text
dotfiles/
├── bin/bin/                 # NEW: User utilities
├── scripts/
│   ├── setup/              # Moved: Installation scripts
│   ├── maintenance/        # Moved: Verification scripts
│   └── utils/              # Moved: Helper scripts (manual-backup.sh)
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
| Install AI agent tooling | `make install-ai` |
| Install pi only | `./scripts/setup/install-pi.sh` |
| Install Claude Code only | `./scripts/setup/install-claude.sh` |
| Uninstall all | `./scripts/setup/uninstall.sh` |
| Lint scripts and docs | `make lint` |
| Verify setup | `./scripts/maintenance/verify-installation.sh` |
| Verify auth | `./scripts/maintenance/verify-auth.sh` or `make verify-auth` |
| Manual backup | `./scripts/utils/manual-backup.sh` |

---

**Document Version:** 1.2
**Last Updated:** 2026-09-12
**Maintained by:** Sebastian
