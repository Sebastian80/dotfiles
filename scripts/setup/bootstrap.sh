#!/bin/bash
# Dotfiles Bootstrap Script
# Automated setup for Sebastian's dotfiles with GNU Stow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Unicode symbols (work without Nerd Fonts)
CHECK="✓"
CROSS="✗"
ARROW="→"
STAR="★"
WARN="⚠"
ROCKET="🚀"
PACKAGE="📦"
GEAR="⚙️"
SPARKLE="✨"
CLOCK="⏳"

# Functions
info() { echo -e "${GREEN}${CHECK}${NC} $1"; }
warn() { echo -e "${YELLOW}${WARN}${NC}  $1"; }
error() { echo -e "${RED}${CROSS}${NC} $1"; }
step() { echo -e "${BLUE}${ARROW}${NC} ${BOLD}$1${NC}"; }
success() { echo -e "${GREEN}${SPARKLE} $1${NC}"; }
working() { echo -e "${CYAN}${GEAR}${NC}  $1"; }

# Determine dotfiles directory
# This script can be run from dotfiles root or from scripts/setup/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If script is in scripts/setup/, go up two levels to find dotfiles root
if [[ "$SCRIPT_DIR" == */scripts/setup ]]; then
    DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
    DOTFILES_DIR="$SCRIPT_DIR"
fi

# Verify we're in the dotfiles directory by checking for Brewfile
if [[ ! -f "$DOTFILES_DIR/Brewfile" ]]; then
    error "Could not find dotfiles directory"
    error "Please run this script from ~/dotfiles or ~/dotfiles/scripts/setup/"
    error "  cd ~/dotfiles && ./scripts/setup/bootstrap.sh"
    exit 1
fi

# Change to dotfiles directory
cd "$DOTFILES_DIR" || exit 1

# Display banner
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${MAGENTA}Sebastian's Dotfiles Bootstrap${NC}                           ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${ROCKET} Modern CLI tools & configs with GNU Stow              ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
step "Starting installation..."
echo ""

# Check prerequisites
step "Checking prerequisites..."

# Check for git
if ! command -v git &> /dev/null; then
    error "Git is not installed. Please install it first:"
    echo "  sudo apt update && sudo apt install -y git"
    exit 1
fi
info "Git found: $(git --version)"

# Check for stow
if ! command -v stow &> /dev/null; then
    warn "GNU Stow is not installed."
    read -p "Would you like to install it now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Installing GNU Stow..."
        sudo apt update && sudo apt install -y stow
        info "GNU Stow installed successfully"
    else
        error "GNU Stow is required. Please install it manually:"
        echo "  sudo apt update && sudo apt install -y stow"
        exit 1
    fi
fi
info "GNU Stow found: $(stow --version | head -n1)"

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    warn "Homebrew is not installed."
    echo "Homebrew is required to install modern CLI tools (bat, eza, fzf, etc.)"
    read -p "Would you like to install Homebrew now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        step "Installing Homebrew dependencies..."

        # Install system dependencies first (prevents password prompts during Homebrew install)
        if command -v apt &> /dev/null; then
            info "Installing build tools (requires sudo)..."
            sudo apt update -qq
            sudo apt install -y build-essential procps curl file git
            info "✓ System dependencies installed"
        fi

        echo ""
        step "Installing Homebrew..."
        info "This will take 2-3 minutes..."

        # Install Homebrew non-interactively to prevent terminal corruption
        export NONINTERACTIVE=1
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for this session
        if [ -d "/home/linuxbrew/.linuxbrew" ]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            info "✓ Homebrew installed successfully"
        else
            error "Homebrew installation may have failed. Please check the output above."
            warn "You can try manually: NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        fi
    else
        warn "Skipping Homebrew installation. You can install it later:"
        echo "  sudo apt install -y build-essential procps curl file git"
        echo "  NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    fi
else
    info "Homebrew found: $(brew --version | head -n1)"
fi

# Install Homebrew packages
if command -v brew &> /dev/null; then
    echo ""
    step "Homebrew Packages Installation"
    echo ""
    # Count packages in Brewfile
    PACKAGE_COUNT=$(grep -cE '^\s*brew\s+' "$DOTFILES_DIR/Brewfile" 2>/dev/null || echo "0")
    echo -e "${PACKAGE} ${BOLD}The Brewfile contains $PACKAGE_COUNT packages:${NC}"
    echo "  Modern CLI tools (bat, eza, fzf, ripgrep, yazi)"
    echo "  Development tools (gh, glab, composer, fnm, uv)"
    echo "  Prompt engine (oh-my-posh)"
    echo "  Password manager (bitwarden-cli)"
    echo ""
    echo -e "${CLOCK} ${YELLOW}Installation time: 5-10 minutes${NC}"
    echo ""
    read -p "Install Homebrew packages now? (recommended) (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        step "Installing Homebrew packages from Brewfile..."
        echo ""
        info "Installing $PACKAGE_COUNT packages... (this may take 5-10 minutes)"
        echo ""

        # Install and capture output
        if brew bundle install --file="$DOTFILES_DIR/Brewfile"; then
            echo ""
            info "✓ Homebrew packages installed successfully"
        else
            echo ""
            warn "Some packages failed to install."
            warn "This is often OK - some packages may not be available on your system."
            warn "You can retry later with: brew bundle install --file=~/dotfiles/Brewfile"
        fi
    else
        warn "Skipping Homebrew package installation."
        echo "You can install them later with:"
        echo "  brew bundle install --file=~/dotfiles/Brewfile"
    fi
fi

echo ""

# Check if bash-completion@2 is installed (critical for our bash config)
if command -v brew &> /dev/null && ! brew list bash-completion@2 &> /dev/null; then
    echo ""
    warn "WARNING: bash-completion@2 is not installed!"
    warn "Your bash config requires this package to work properly."
    echo ""
    echo "The dotfiles assume Homebrew packages are installed."
    echo "Without them, many features won't work (completions, modern tools, etc.)"
    echo ""
    read -p "Do you want to install Homebrew packages now before continuing? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if brew bundle install --file="$DOTFILES_DIR/Brewfile"; then
            info "✓ Homebrew packages installed"
        else
            warn "Some packages failed. Continuing anyway..."
        fi
    else
        warn "Continuing without Homebrew packages. Some features may not work."
        warn "Install later with: brew bundle install --file=~/dotfiles/Brewfile"
        echo ""
        read -p "Press Enter to continue..." -r
    fi
fi

echo ""
step "Checking for conflicts..."

# List of packages to install (all 15 user-facing packages)
PACKAGES=(bash bin git gtk ghostty oh-my-posh yazi micro htop btop eza fzf glow lazygit lazydocker ripgrep)

# Check for conflicts
CONFLICTS=0
for package in "${PACKAGES[@]}"; do
    if [[ -d "$package" ]]; then
        # Perform dry run to check for conflicts
        if ! stow -n -v "$package" &> /dev/null; then
            warn "Package '$package' has conflicts"
            CONFLICTS=$((CONFLICTS + 1))
        fi
    fi
done

if [[ $CONFLICTS -gt 0 ]]; then
    echo ""
    warn "Found $CONFLICTS package(s) with conflicts."
    echo ""
    echo "Options:"
    echo "  1. Backup existing files and continue"
    echo "  2. Adopt existing files into dotfiles repo"
    echo "  3. Exit and resolve manually"
    echo ""
    read -p "Choose option (1/2/3): " -n 1 -r
    echo

    case $REPLY in
        1)
            # Backup existing files
            BACKUP_DIR="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
            info "Creating backup in $BACKUP_DIR"
            mkdir -p "$BACKUP_DIR"

            # Backup conflicting files by parsing stow dry-run output
            for package in "${PACKAGES[@]}"; do
                if [[ -d "$package" ]]; then
                    # Get list of conflicting files
                    conflicts=$(stow -n -v "$package" 2>&1 | grep "existing target is neither" | sed 's/.*existing target is neither a link nor a directory: //' || true)

                    if [[ -n "$conflicts" ]]; then
                        while IFS= read -r file; do
                            file=$(echo "$file" | tr -d '\n\r')
                            if [[ -n "$file" && -e "$HOME/$file" ]]; then
                                # Create parent directory in backup
                                mkdir -p "$BACKUP_DIR/$(dirname "$file")"
                                # Move file to backup
                                if mv "$HOME/$file" "$BACKUP_DIR/$file" 2>/dev/null; then
                                    info "Backed up: $file"
                                fi
                            fi
                        done <<< "$conflicts"
                    fi
                fi
            done
            echo ""
            info "Backup complete. Files saved to: $BACKUP_DIR"
            ;;
        2)
            # Adopt existing files
            info "Adopting existing files into dotfiles repo..."
            for package in "${PACKAGES[@]}"; do
                if [[ -d "$package" ]]; then
                    stow --adopt "$package" 2>&1 | grep -v "^BUG" || true
                fi
            done
            warn "Files have been adopted. Review changes with 'git diff' before committing."
            ;;
        3)
            info "Exiting. Please resolve conflicts manually."
            echo ""
            echo "You can check conflicts with: stow -n -v <package>"
            echo "Example: stow -n -v bash"
            exit 0
            ;;
        *)
            error "Invalid option. Exiting."
            exit 1
            ;;
    esac
fi

echo ""
step "Installing dotfiles packages..."

# Install each package
for package in "${PACKAGES[@]}"; do
    if [[ -d "$package" ]]; then
        info "Stowing $package..."
        if stow -v "$package"; then
            info "✓ $package installed successfully"
        else
            error "✗ Failed to install $package"
        fi
    else
        warn "Package $package not found, skipping..."
    fi
done

echo ""
step "Verifying installation..."

# Verify symlinks were created
VERIFIED=0
FAILED=0

verify_link() {
    if [[ -L "$1" ]]; then
        info "✓ $1 -> $(readlink "$1")"
        VERIFIED=$((VERIFIED + 1))
    else
        warn "✗ $1 is not a symlink"
        FAILED=$((FAILED + 1))
    fi
}

verify_link "$HOME/.bashrc"
verify_link "$HOME/.bash_profile"
verify_link "$HOME/.gitconfig"
verify_link "$HOME/.config/ghostty"
verify_link "$HOME/.config/oh-my-posh"

echo ""
if [[ $FAILED -eq 0 ]]; then
    info "All verifications passed! ($VERIFIED/$VERIFIED)"
else
    warn "Some verifications failed ($VERIFIED/$(($VERIFIED + $FAILED)))"
fi

echo ""
step "Post-installation tasks..."

# Check for machine-specific local config
if [[ ! -f "$HOME/.bash/local" ]]; then
    info "Creating empty .bash/local for machine-specific config..."
    touch "$HOME/.bash/local"
    echo "# Machine-specific bash configuration" > "$HOME/.bash/local"
    echo "# This file is git-ignored" >> "$HOME/.bash/local"
fi

# Install system configuration
echo ""
step "System Configuration"
echo ""
info "System configuration adds Homebrew paths to sudo's secure_path."
echo "This allows Homebrew tools (bat, eza, etc.) to work with sudo commands."
echo ""
warn "This requires sudo privileges (you'll be prompted for password)."
echo ""
read -p "Install system configuration now? (recommended) (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    step "Installing system configuration..."
    if make -C "$DOTFILES_DIR" install-system; then
        info "✓ System configuration installed successfully"
    else
        error "Failed to install system configuration"
        echo "You can install it later with:"
        echo "  cd ~/dotfiles && make install-system"
    fi
else
    warn "Skipping system configuration."
    echo "You can install it later with:"
    echo "  cd ~/dotfiles && make install-system"
fi

# Install Ghostty Terminal Emulator
echo ""
step "Ghostty Terminal Emulator"
echo ""
info "Ghostty is a modern, fast GPU-accelerated terminal emulator."
echo "Your dotfiles include Ghostty configuration in ~/.config/ghostty"
echo ""
if command -v ghostty &> /dev/null; then
    GHOSTTY_VERSION=$(ghostty --version 2>&1 | head -1 || echo "installed")
    info "Ghostty is already installed: $GHOSTTY_VERSION"
else
    echo "Ghostty is not currently installed."
    echo ""
    read -p "Install Ghostty terminal emulator? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -x "$DOTFILES_DIR/scripts/setup/install-ghostty.sh" ]]; then
            if "$DOTFILES_DIR/scripts/setup/install-ghostty.sh"; then
                info "✓ Ghostty installed successfully"
            else
                warn "Ghostty installation encountered issues. Check output above."
                echo "You can install it later with:"
                echo "  ~/dotfiles/scripts/setup/install-ghostty.sh"
            fi
        else
            error "Ghostty installation script not found at: scripts/setup/install-ghostty.sh"
        fi
    else
        warn "Skipping Ghostty installation."
        echo "You can install it later with:"
        echo "  ~/dotfiles/scripts/setup/install-ghostty.sh"
    fi
fi

# Install Nerd Fonts
echo ""
step "Nerd Fonts Installation"
echo ""
info "Nerd Fonts are required for oh-my-posh icons and beautiful terminal UI."
echo "Without them, you'll see missing/broken icons in your prompt."
echo ""
echo "Available fonts:"
echo "  • JetBrainsMono Nerd Font (recommended)"
echo "  • FiraCode Nerd Font"
echo "  • Hack Nerd Font"
echo "  • And many more..."
echo ""
read -p "Install Nerd Fonts now? (recommended) (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ -x "$DOTFILES_DIR/scripts/setup/install-fonts.sh" ]]; then
        step "Installing Nerd Fonts..."
        if "$DOTFILES_DIR/scripts/setup/install-fonts.sh"; then
            info "✓ Nerd Fonts installed successfully"
        else
            warn "Font installation encountered issues. Check output above."
            echo "You can install them later with:"
            echo "  ~/dotfiles/scripts/setup/install-fonts.sh"
        fi
    else
        error "Font installation script not found at: scripts/setup/install-fonts.sh"
    fi
else
    warn "Skipping Nerd Fonts installation."
    echo "You can install them later with:"
    echo "  ~/dotfiles/scripts/setup/install-fonts.sh"
fi

# Install Docker Engine
echo ""
step "Docker Engine Installation"
echo ""
info "Docker Engine enables container-based development workflows."
echo "Includes Docker Engine, docker-compose plugin, and adds you to docker group."
echo ""
echo "What you get:"
echo "  • Docker Engine (latest from official repository)"
echo "  • Docker Compose plugin (v2 syntax)"
echo "  • containerd runtime"
echo "  • User added to docker group (requires logout/login)"
echo ""
warn "Note: This installs Docker Engine (CLI), not Docker Desktop."
echo ""
read -p "Install Docker Engine now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ -x "$DOTFILES_DIR/scripts/setup/install-docker.sh" ]]; then
        step "Installing Docker Engine..."
        if "$DOTFILES_DIR/scripts/setup/install-docker.sh"; then
            info "✓ Docker Engine installed successfully"
            warn "IMPORTANT: Log out and log back in for docker group to take effect!"
        else
            warn "Docker installation encountered issues. Check output above."
            echo "You can install it later with:"
            echo "  ~/dotfiles/scripts/setup/install-docker.sh"
        fi
    else
        error "Docker installation script not found at: scripts/setup/install-docker.sh"
    fi
else
    warn "Skipping Docker Engine installation."
    echo "You can install it later with:"
    echo "  ~/dotfiles/scripts/setup/install-docker.sh"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  ${SPARKLE} ${BOLD}Installation Complete!${NC}                                ${GREEN}║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}${CYAN}What was installed:${NC}"
echo -e "  ${CHECK} GNU Stow and dotfiles packages (16 configs)"
if command -v brew &> /dev/null && brew list bat &> /dev/null; then
    echo -e "  ${CHECK} Homebrew packages (27 modern CLI tools)"
fi
if [[ -f /etc/sudoers.d/homebrew-path ]]; then
    echo -e "  ${CHECK} System configuration (Homebrew sudo PATH)"
fi
if command -v ghostty &> /dev/null; then
    echo -e "  ${CHECK} Ghostty terminal emulator"
fi
if fc-list | grep -q "NerdFont" 2>/dev/null; then
    echo -e "  ${CHECK} Nerd Fonts"
fi
if command -v docker &> /dev/null; then
    echo -e "  ${CHECK} Docker Engine + docker-compose"
fi
echo ""
echo -e "${BOLD}${BLUE}Next Steps:${NC}"
echo -e "  ${CYAN}1.${NC} Reload your shell: ${MAGENTA}source ~/.bashrc${NC}"
echo -e "  ${CYAN}2.${NC} Review the configuration files"
echo -e "  ${CYAN}3.${NC} Add machine-specific settings to ${MAGENTA}~/.bash/local${NC}"
echo ""
echo -e "${BOLD}${YELLOW}Optional Next Steps:${NC}"
if ! command -v brew &> /dev/null || ! brew list bat &> /dev/null; then
    echo -e "  ${PACKAGE} Install Homebrew packages:"
    echo -e "    ${CYAN}→${NC} ${MAGENTA}brew bundle install --file=~/dotfiles/Brewfile${NC}"
fi
if [[ ! -f /etc/sudoers.d/homebrew-path ]]; then
    echo -e "  ${GEAR} Install system configuration:"
    echo -e "    ${CYAN}→${NC} ${MAGENTA}cd ~/dotfiles && make install-system${NC}"
fi
if ! command -v ghostty &> /dev/null; then
    echo -e "  👻 Install Ghostty terminal emulator (if skipped):"
    echo -e "    ${CYAN}→${NC} ${MAGENTA}~/dotfiles/scripts/setup/install-ghostty.sh${NC}"
fi
if ! fc-list | grep -q "NerdFont" 2>/dev/null; then
    echo -e "  ${STAR} Install Nerd Fonts (if skipped):"
    echo -e "    ${CYAN}→${NC} ${MAGENTA}~/dotfiles/scripts/setup/install-fonts.sh${NC}"
fi
if ! command -v docker &> /dev/null; then
    echo -e "  🐳 Install Docker Engine (if skipped):"
    echo -e "    ${CYAN}→${NC} ${MAGENTA}~/dotfiles/scripts/setup/install-docker.sh${NC}"
fi
echo -e "  🔐 Configure authentication (Bitwarden):"
echo -e "    ${CYAN}→${NC} See ${MAGENTA}INSTALLATION.md${NC} Step 7 or ${MAGENTA}SECRET_MANAGEMENT.md${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${SPARKLE} For more information, see ${MAGENTA}README.md${NC}"
echo -e "${ROCKET} Happy dotfile-ing!"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Ask if user wants to reload shell
read -p "Would you like to reload the shell now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Reloading shell..."
    exec bash
fi
