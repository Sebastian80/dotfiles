#!/bin/bash
# Dotfiles Bootstrap Script
# Automated setup for Sebastian's dotfiles with GNU Stow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check if running from dotfiles directory
if [[ ! -f "$(pwd)/bootstrap.sh" ]]; then
    error "Please run this script from the dotfiles directory"
    error "cd ~/dotfiles && ./bootstrap.sh"
    exit 1
fi

DOTFILES_DIR="$(pwd)"

step "Starting dotfiles installation..."
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
        info "Installing Homebrew (this may take a few minutes)..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for this session
        if [ -d "/home/linuxbrew/.linuxbrew" ]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            info "Homebrew installed successfully"
        else
            error "Homebrew installation may have failed. Please check the output above."
        fi
    else
        warn "Skipping Homebrew installation. You can install it later:"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    fi
else
    info "Homebrew found: $(brew --version | head -n1)"
fi

echo ""
step "Checking for conflicts..."

# List of packages to install
PACKAGES=(bash git gtk ghostty oh-my-posh yazi micro htop btop)

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

            # Backup conflicting files
            for package in "${PACKAGES[@]}"; do
                if [[ -d "$package" ]]; then
                    stow -n -v "$package" 2>&1 | grep "existing target" | while read -r line; do
                        # Extract filename from stow output
                        file=$(echo "$line" | sed -n 's/.*existing target is \([^:]*\).*/\1/p')
                        if [[ -n "$file" && -e "$HOME/$file" ]]; then
                            # Create parent directory in backup
                            mkdir -p "$BACKUP_DIR/$(dirname "$file")"
                            # Move file to backup
                            mv "$HOME/$file" "$BACKUP_DIR/$file"
                            info "Backed up: $file"
                        fi
                    done
                fi
            done
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

echo ""
step "Installation complete!"
echo ""
info "Your dotfiles have been installed successfully."
echo ""
echo "Next steps:"
echo "  1. Reload your shell: source ~/.bashrc"
echo "  2. Review the configuration files"
echo "  3. Add machine-specific settings to ~/.bash/local"
echo "  4. (Optional) Install recommended system packages:"
echo "     sudo apt install -y nala"
echo "  5. Install Homebrew packages:"
echo "     brew bundle install --file=~/dotfiles/Brewfile"
echo "  6. Install Nerd Fonts (required for oh-my-posh icons):"
echo "     ~/dotfiles/install-fonts.sh"
echo "  7. (Optional) Install Docker Engine:"
echo "     ~/dotfiles/install-docker.sh"
echo ""
info "For more information, see README.md"
echo ""

# Ask if user wants to reload shell
read -p "Would you like to reload the shell now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Reloading shell..."
    exec bash
fi
