#!/bin/bash
# Dotfiles Uninstall Script
# Safely remove Sebastian's dotfiles and all installed components

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

# Unicode symbols
CHECK="✓"
CROSS="✗"
ARROW="→"
WARN="⚠"
TRASH="🗑️"
CLEAN="🧹"
SPARKLE="✨"

# Functions
info() { echo -e "${GREEN}${CHECK}${NC} $1"; }
warn() { echo -e "${YELLOW}${WARN}${NC}  $1"; }
error() { echo -e "${RED}${CROSS}${NC} $1"; }
step() { echo -e "${BLUE}${ARROW}${NC} ${BOLD}$1${NC}"; }
success() { echo -e "${GREEN}${SPARKLE} $1${NC}"; }
removing() { echo -e "${CYAN}${TRASH}${NC}  $1"; }

# Determine dotfiles directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$SCRIPT_DIR" == */scripts/setup ]]; then
    DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
    DOTFILES_DIR="$SCRIPT_DIR"
fi

# Display banner
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${MAGENTA}Dotfiles Uninstall Script${NC}                                ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${CLEAN} Safely remove all dotfiles and components             ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Dry run mode
DRY_RUN=false
if [[ "$1" == "--dry-run" || "$1" == "-n" ]]; then
    DRY_RUN=true
    warn "DRY RUN MODE - No changes will be made"
    echo ""
fi

# Detect what's installed
step "Scanning installed components..."
echo ""

FOUND_ITEMS=()

# Check for stowed dotfiles
if [[ -L "$HOME/.bashrc" ]] || [[ -L "$HOME/.gitconfig" ]]; then
    FOUND_ITEMS+=("stowed_dotfiles")
    info "Found: Stowed dotfiles (symlinks detected)"
fi

# Check for Homebrew
if command -v brew &>/dev/null; then
    FOUND_ITEMS+=("homebrew")
    BREW_PACKAGES=$(brew list --formula 2>/dev/null | wc -l)
    info "Found: Homebrew with $BREW_PACKAGES packages"
fi

# Check for Ghostty
if command -v ghostty &>/dev/null; then
    FOUND_ITEMS+=("ghostty")
    GHOSTTY_PATH=$(command -v ghostty)

    # Detect installation method
    GHOSTTY_METHOD="unknown"
    if snap list ghostty &>/dev/null 2>&1; then
        GHOSTTY_METHOD="snap"
    elif [[ "$GHOSTTY_PATH" == /snap/* ]]; then
        GHOSTTY_METHOD="snap"
    elif dpkg -l ghostty &>/dev/null 2>&1; then
        GHOSTTY_METHOD="apt"
    elif rpm -q ghostty &>/dev/null 2>&1; then
        GHOSTTY_METHOD="rpm"
    elif pacman -Q ghostty &>/dev/null 2>&1; then
        GHOSTTY_METHOD="pacman"
    elif [[ "$GHOSTTY_PATH" == /usr/local/* ]]; then
        GHOSTTY_METHOD="source-system"
    elif [[ "$GHOSTTY_PATH" == */.local/* ]]; then
        GHOSTTY_METHOD="source-user"
    fi

    info "Found: Ghostty at $GHOSTTY_PATH ($GHOSTTY_METHOD)"
fi

# Check for Nerd Fonts
if [[ -d "$HOME/.local/share/fonts/NerdFonts" ]]; then
    FOUND_ITEMS+=("nerd_fonts")
    info "Found: Nerd Fonts"
fi

# Check for backup directories
if compgen -G "$HOME/dotfiles-backup-*" > /dev/null; then
    FOUND_ITEMS+=("backups")
    BACKUP_COUNT=$(ls -d "$HOME/dotfiles-backup-"* 2>/dev/null | wc -l)
    info "Found: $BACKUP_COUNT backup directory(ies)"
fi

# Check for config directories
CONFIG_DIRS=()
for dir in ghostty htop yazi micro btop lazygit lazydocker gtk-3.0 gtk-4.0; do
    if [[ -d "$HOME/.config/$dir" ]]; then
        CONFIG_DIRS+=("$dir")
    fi
done
if [[ ${#CONFIG_DIRS[@]} -gt 0 ]]; then
    FOUND_ITEMS+=("config_dirs")
    info "Found: ${#CONFIG_DIRS[@]} config directories"
fi

# Check for system configuration
if [[ -f /etc/sudoers.d/homebrew-path ]]; then
    FOUND_ITEMS+=("system_config")
    info "Found: System configuration (Homebrew sudoers)"
fi

# Check for machine-specific config
if [[ -f "$HOME/.bash/local" ]]; then
    FOUND_ITEMS+=("bash_local")
    info "Found: Machine-specific config (~/.bash/local)"
fi

echo ""

# If nothing found, exit
if [[ ${#FOUND_ITEMS[@]} -eq 0 ]]; then
    success "No dotfiles installation detected - system is clean!"
    exit 0
fi

# Show what will be removed
echo -e "${BOLD}The following will be removed:${NC}"
echo ""

for item in "${FOUND_ITEMS[@]}"; do
    case $item in
        stowed_dotfiles)
            echo -e "  ${TRASH} Stowed dotfiles symlinks:"
            echo "    - ~/.bashrc, ~/.bash_profile, ~/.bash/"
            echo "    - ~/.gitconfig"
            echo "    - ~/.config/ghostty, ~/.config/yazi, ~/.config/htop, etc."
            echo "    - ~/.local/bin/* (custom scripts)"
            ;;
        homebrew)
            echo -e "  ${TRASH} Homebrew installation:"
            echo "    - /home/linuxbrew/.linuxbrew/"
            echo "    - All $BREW_PACKAGES installed packages"
            echo "    - ~/.cache/Homebrew"
            ;;
        ghostty)
            echo -e "  ${TRASH} Ghostty terminal emulator:"
            echo "    - $GHOSTTY_PATH (installed via: $GHOSTTY_METHOD)"
            ;;
        nerd_fonts)
            echo -e "  ${TRASH} Nerd Fonts:"
            echo "    - ~/.local/share/fonts/NerdFonts/"
            ;;
        backups)
            echo -e "  ${TRASH} Backup directories:"
            echo "    - ~/dotfiles-backup-*/"
            ;;
        config_dirs)
            echo -e "  ${TRASH} Configuration directories:"
            for dir in "${CONFIG_DIRS[@]}"; do
                echo "    - ~/.config/$dir"
            done
            ;;
        system_config)
            echo -e "  ${TRASH} System configuration:"
            echo "    - /etc/sudoers.d/homebrew-path (Homebrew sudo PATH)"
            ;;
        bash_local)
            echo -e "  ${TRASH} Machine-specific config:"
            echo "    - ~/.bash/local"
            ;;
    esac
    echo ""
done

# Confirmation prompt
if [[ "$DRY_RUN" == false ]]; then
    echo -e "${BOLD}${RED}WARNING: This action cannot be undone!${NC}"
    echo ""
    echo "Your shell will be restored to system defaults."
    echo "Original files in backup directories will be kept for manual review."
    echo ""
    read -p "Are you sure you want to uninstall everything? (yes/no) " -r
    echo ""

    if [[ ! "$REPLY" == "yes" ]]; then
        info "Uninstall cancelled"
        exit 0
    fi
fi

# Start uninstall process
echo ""
step "Starting uninstall process..."
echo ""

# Function to execute or simulate
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${CYAN}[DRY RUN]${NC} $1"
    else
        eval "$1"
    fi
}

# 1. Unstow dotfiles
if [[ " ${FOUND_ITEMS[@]} " =~ " stowed_dotfiles " ]]; then
    step "Unstowing dotfiles..."

    if [[ -d "$DOTFILES_DIR" ]]; then
        cd "$DOTFILES_DIR"
        PACKAGES=(bash bin git gtk ghostty oh-my-posh yazi micro htop btop fzf eza lazygit lazydocker glow)

        for package in "${PACKAGES[@]}"; do
            if [[ -d "$package" ]]; then
                removing "Unstowing: $package"
                run_cmd "stow -D '$package' 2>/dev/null || true"
            fi
        done
        info "Dotfiles unstowed"
    else
        warn "Dotfiles directory not found, skipping unstow"
    fi
    echo ""
fi

# 2. Remove Homebrew
if [[ " ${FOUND_ITEMS[@]} " =~ " homebrew " ]]; then
    step "Uninstalling Homebrew..."

    if command -v brew &>/dev/null && [[ "$DRY_RUN" == false ]]; then
        removing "Removing all Homebrew packages..."
        brew list --formula 2>/dev/null | xargs brew uninstall --force 2>/dev/null || true
        info "All packages removed"
    fi

    removing "Removing Homebrew installation..."
    run_cmd "sudo rm -rf /home/linuxbrew/.linuxbrew"
    run_cmd "rm -rf ~/.linuxbrew"
    run_cmd "rm -rf ~/.cache/Homebrew"
    info "Homebrew uninstalled"
    echo ""
fi

# 3. Remove Ghostty
if [[ " ${FOUND_ITEMS[@]} " =~ " ghostty " ]]; then
    step "Removing Ghostty..."

    case "$GHOSTTY_METHOD" in
        snap)
            removing "Removing Ghostty Snap package..."
            run_cmd "sudo snap remove ghostty"
            info "Ghostty snap removed"
            ;;
        apt)
            removing "Removing Ghostty .deb package..."
            run_cmd "sudo apt remove -y ghostty"
            run_cmd "sudo apt autoremove -y"
            info "Ghostty package removed"
            ;;
        rpm)
            removing "Removing Ghostty RPM package..."
            run_cmd "sudo dnf remove -y ghostty"
            info "Ghostty package removed"
            ;;
        pacman)
            removing "Removing Ghostty via pacman..."
            run_cmd "sudo pacman -R --noconfirm ghostty"
            info "Ghostty package removed"
            ;;
        source-system)
            removing "Removing Ghostty from /usr/local (requires sudo)..."
            run_cmd "sudo rm -f /usr/local/bin/ghostty"
            run_cmd "sudo rm -rf /usr/local/share/ghostty"
            info "Ghostty source build removed"
            ;;
        source-user)
            removing "Removing Ghostty from ~/.local..."
            run_cmd "rm -f ~/.local/bin/ghostty"
            run_cmd "rm -rf ~/.local/share/ghostty"
            info "Ghostty source build removed"
            ;;
        *)
            warn "Unknown Ghostty installation method, attempting manual removal..."
            GHOSTTY_PATH=$(command -v ghostty 2>/dev/null || echo "")
            if [[ -n "$GHOSTTY_PATH" ]]; then
                removing "Removing from $GHOSTTY_PATH..."
                if [[ "$GHOSTTY_PATH" == /usr/* ]]; then
                    run_cmd "sudo rm -f $GHOSTTY_PATH"
                else
                    run_cmd "rm -f $GHOSTTY_PATH"
                fi
            fi
            ;;
    esac
    echo ""
fi

# 4. Remove Nerd Fonts
if [[ " ${FOUND_ITEMS[@]} " =~ " nerd_fonts " ]]; then
    step "Removing Nerd Fonts..."

    removing "Removing font files..."
    run_cmd "rm -rf ~/.local/share/fonts/NerdFonts"

    if [[ "$DRY_RUN" == false ]]; then
        removing "Updating font cache..."
        fc-cache -f 2>/dev/null || true
    fi

    info "Nerd Fonts removed"
    echo ""
fi

# 5. Remove remaining config directories
if [[ " ${FOUND_ITEMS[@]} " =~ " config_dirs " ]]; then
    step "Cleaning up configuration directories..."

    for dir in "${CONFIG_DIRS[@]}"; do
        removing "Removing ~/.config/$dir"
        run_cmd "rm -rf ~/.config/$dir"
    done

    info "Config directories cleaned"
    echo ""
fi

# 6. Remove system configuration
if [[ " ${FOUND_ITEMS[@]} " =~ " system_config " ]]; then
    step "Removing system configuration..."

    removing "Removing Homebrew sudoers configuration (requires sudo)..."
    run_cmd "sudo rm -f /etc/sudoers.d/homebrew-path"

    info "System configuration removed"
    echo ""
fi

# 7. Remove machine-specific config
if [[ " ${FOUND_ITEMS[@]} " =~ " bash_local " ]]; then
    step "Removing machine-specific config..."

    removing "Removing ~/.bash/local..."
    run_cmd "rm -f ~/.bash/local"

    info "Machine-specific config removed"
    echo ""
fi

# 8. Remove bash configurations (if not already removed by unstow)
step "Cleaning bash configurations..."

if [[ -d "$HOME/.bash" && ! -L "$HOME/.bash" ]]; then
    removing "Removing ~/.bash directory..."
    run_cmd "rm -rf ~/.bash"
fi

for file in .bashrc .bash_profile .bash_logout .inputrc; do
    if [[ -L "$HOME/$file" ]]; then
        removing "Removing symlink: ~/$file"
        run_cmd "rm -f ~/.local/$file"
    fi
done

info "Bash configuration cleaned"
echo ""

# 9. Restore default system files
step "Restoring system defaults..."

if [[ -f /etc/skel/.bashrc ]]; then
    removing "Restoring default .bashrc..."
    run_cmd "cp /etc/skel/.bashrc ~/.bashrc"
fi

if [[ -f /etc/skel/.bash_logout ]]; then
    removing "Restoring default .bash_logout..."
    run_cmd "cp /etc/skel/.bash_logout ~/.bash_logout"
fi

if [[ -f /etc/skel/.profile ]]; then
    removing "Restoring default .profile..."
    run_cmd "cp /etc/skel/.profile ~/.profile"
fi

info "System defaults restored"
echo ""

# 10. Report on backup directories
if [[ " ${FOUND_ITEMS[@]} " =~ " backups " ]]; then
    step "Backup directories..."

    warn "Backup directories are kept for manual review:"
    for backup in "$HOME/dotfiles-backup-"*; do
        if [[ -d "$backup" ]]; then
            echo "  - $backup"
        fi
    done
    echo ""
    echo "You can safely delete these after verifying you don't need the files:"
    echo "  rm -rf ~/dotfiles-backup-*"
    echo ""
fi

# Summary
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${CYAN}║${NC}  ${BOLD}Dry Run Complete - No Changes Made${NC}                       ${CYAN}║${NC}"
else
    echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}Uninstall Complete!${NC}                                      ${CYAN}║${NC}"
fi
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$DRY_RUN" == false ]]; then
    success "All components have been removed"
    echo ""
    info "Next steps:"
    echo "  1. Logout and login again for a clean shell"
    echo "  2. Review backup directories in ~/dotfiles-backup-*"
    echo "  3. Optionally remove the dotfiles repository"
    echo ""
else
    info "Run without --dry-run to perform actual uninstall"
    echo ""
fi
