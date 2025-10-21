#!/bin/bash
# Dotfiles Verification Script
# Checks that all packages are properly installed and stowed

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Functions
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
error() { echo -e "${RED}[ERROR]${NC} $1"; FAILED=$((FAILED + 1)); }
success() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
section() { echo -e "\n${BLUE}===${NC} $1 ${BLUE}===${NC}"; }

# Check if script is run from dotfiles directory
if [[ ! -f "$(pwd)/verify-installation.sh" ]]; then
    error "Please run this script from the dotfiles directory"
    echo "  cd ~/dotfiles && ./verify-installation.sh"
    exit 1
fi

DOTFILES_DIR="$(pwd)"

echo ""
section "Dotfiles Installation Verification"
echo ""

# 1. Check Prerequisites
section "Prerequisites"

# Check git
if command -v git &> /dev/null; then
    success "Git is installed: $(git --version)"
else
    error "Git is NOT installed"
fi

# Check stow
if command -v stow &> /dev/null; then
    success "GNU Stow is installed: $(stow --version | head -n1)"
else
    error "GNU Stow is NOT installed"
fi

# Check Homebrew
if command -v brew &> /dev/null; then
    success "Homebrew is installed: $(brew --version | head -n1)"
else
    warn "Homebrew is NOT installed (optional but recommended)"
fi

# 2. Check Dotfiles Repository
section "Repository Status"

if [[ -d ".git" ]]; then
    success "Git repository initialized"
    COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    info "Total commits: $COMMITS"

    # Check for remote
    if git remote -v | grep -q "origin"; then
        success "Git remote 'origin' is configured"
        git remote -v | head -n1 | sed 's/^/  /'
    else
        warn "No git remote configured (push to GitHub pending)"
    fi
else
    error "Not a git repository"
fi

# 3. Check Stow Packages
section "Stow Packages"

PACKAGES=(bash git gtk ghostty oh-my-posh yazi micro htop btop)

for package in "${PACKAGES[@]}"; do
    if [[ -d "$package" ]]; then
        # Check if package is stowed (has symlinks pointing to it)
        if find ~ ~/.config -maxdepth 2 -type l -lname "*dotfiles/$package/*" 2>/dev/null | grep -q .; then
            success "Package '$package' is stowed"
        else
            error "Package '$package' exists but is NOT stowed"
        fi
    else
        error "Package '$package' directory does NOT exist"
    fi
done

# 4. Verify Specific Symlinks
section "Critical Symlinks"

verify_symlink() {
    local target="$1"
    local expected="$2"

    if [[ -L "$target" ]]; then
        local actual=$(readlink -f "$target")
        local expected_full=$(readlink -f "$expected")
        if [[ "$actual" == "$expected_full" ]]; then
            success "✓ $target → $(readlink "$target")"
        else
            error "✗ $target points to wrong location"
            echo "    Expected: $expected_full"
            echo "    Actual: $actual"
        fi
    else
        if [[ -e "$target" ]]; then
            error "✗ $target exists but is NOT a symlink"
        else
            error "✗ $target does NOT exist"
        fi
    fi
}

# Home directory symlinks
verify_symlink ~/.bashrc "$DOTFILES_DIR/bash/.bashrc"
verify_symlink ~/.bash_profile "$DOTFILES_DIR/bash/.bash_profile"
verify_symlink ~/.profile "$DOTFILES_DIR/bash/.profile"
verify_symlink ~/.bash "$DOTFILES_DIR/bash/.bash"
verify_symlink ~/.gitconfig "$DOTFILES_DIR/git/.gitconfig"

# Config directory symlinks
verify_symlink ~/.config/ghostty "$DOTFILES_DIR/ghostty/.config/ghostty"
verify_symlink ~/.config/oh-my-posh "$DOTFILES_DIR/oh-my-posh/.config/oh-my-posh"
verify_symlink ~/.config/yazi "$DOTFILES_DIR/yazi/.config/yazi"
verify_symlink ~/.config/micro "$DOTFILES_DIR/micro/.config/micro"
verify_symlink ~/.config/htop "$DOTFILES_DIR/htop/.config/htop"
verify_symlink ~/.config/btop "$DOTFILES_DIR/btop/.config/btop"
verify_symlink ~/.config/git "$DOTFILES_DIR/git/.config/git"
verify_symlink ~/.config/gtk-3.0/bookmarks "$DOTFILES_DIR/gtk/.config/gtk-3.0/bookmarks"
verify_symlink ~/.config/gtk-4.0/gtk.css "$DOTFILES_DIR/gtk/.config/gtk-4.0/gtk.css"

# 5. Check for Broken Symlinks
section "Broken Symlinks Check"

BROKEN=$(find ~ ~/.config -maxdepth 2 -xtype l 2>/dev/null | wc -l)
if [[ $BROKEN -eq 0 ]]; then
    success "No broken symlinks found"
else
    warn "Found $BROKEN broken symlink(s):"
    find ~ ~/.config -maxdepth 2 -xtype l 2>/dev/null | while read -r link; do
        echo "    $link"
    done
fi

# 6. Check Brewfile Packages
section "Homebrew Packages"

if command -v brew &> /dev/null && [[ -f "Brewfile" ]]; then
    if brew bundle check --file="$DOTFILES_DIR/Brewfile" &> /dev/null; then
        success "All Brewfile packages are installed"
    else
        warn "Some Brewfile packages are missing"
        info "Run: brew bundle install --file=$DOTFILES_DIR/Brewfile"
    fi
else
    warn "Skipping Brewfile check (Homebrew not installed or Brewfile missing)"
fi

# 7. Check Key Tools
section "Key Tools"

check_tool() {
    local cmd="$1"
    local name="$2"

    if command -v "$cmd" &> /dev/null; then
        success "$name is installed"
    else
        warn "$name is NOT installed"
    fi
}

check_tool bat "bat (cat replacement)"
check_tool eza "eza (ls replacement)"
check_tool fzf "fzf (fuzzy finder)"
check_tool rg "ripgrep (grep replacement)"
check_tool yazi "yazi (file manager)"
check_tool micro "micro (text editor)"
check_tool htop "htop (process viewer)"
check_tool btop "btop (resource monitor)"
check_tool gh "gh (GitHub CLI)"
check_tool lazygit "lazygit (git UI)"
check_tool docker "docker (containers)"

# 8. Check Shell Configuration
section "Shell Configuration"

if [[ -f ~/.bash/local ]]; then
    success "Machine-specific config (~/.bash/local) exists"
else
    warn "Machine-specific config (~/.bash/local) not found (optional)"
fi

# Check if Homebrew is in PATH
if echo "$PATH" | grep -q "linuxbrew"; then
    success "Homebrew is in PATH"
else
    warn "Homebrew is NOT in PATH"
fi

# 9. Security Check
section "Security Check"

# Check .gitignore exists
if [[ -f ".gitignore" ]]; then
    success ".gitignore file exists"

    # Check for common secret patterns
    if grep -q "local" .gitignore && grep -q "secret" .gitignore; then
        success ".gitignore includes secret patterns"
    else
        warn ".gitignore may be missing security patterns"
    fi
else
    error ".gitignore file is MISSING"
fi

# Check for accidentally committed secrets
if find . -name "id_rsa" -o -name "id_ed25519" -o -name "*.key" | grep -v ".git" | grep -q .; then
    error "Found potential private keys in repository!"
    find . -name "id_rsa" -o -name "id_ed25519" -o -name "*.key" | grep -v ".git" | while read -r file; do
        echo "    $file"
    done
else
    success "No private keys found in repository"
fi

# 10. Check Documentation
section "Documentation"

check_doc() {
    local file="$1"
    if [[ -f "$file" ]]; then
        success "$file exists"
    else
        warn "$file is missing"
    fi
}

check_doc "README.md"
check_doc "INSTALLATION.md"
check_doc "Brewfile"
check_doc "Makefile"
check_doc "bootstrap.sh"
check_doc "SECRET_MANAGEMENT.md"

# Summary
echo ""
section "Summary"
echo ""

TOTAL=$((PASSED + FAILED + WARNINGS))

echo "  ${GREEN}Passed:${NC}   $PASSED"
echo "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo "  ${RED}Failed:${NC}   $FAILED"
echo "  ${BLUE}Total:${NC}    $TOTAL"
echo ""

if [[ $FAILED -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
        echo "${GREEN}✓ Perfect! Everything is properly installed and configured.${NC}"
        exit 0
    else
        echo "${YELLOW}⚠ Installation is functional but has $WARNINGS warning(s).${NC}"
        exit 0
    fi
else
    echo "${RED}✗ Installation has $FAILED critical issue(s) that need attention.${NC}"
    exit 1
fi
