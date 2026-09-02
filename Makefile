# Dotfiles Makefile - GNU Stow Management
# Usage: make help

.PHONY: help install uninstall update link unlink list test clean

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
CYAN   := \033[0;36m
RED    := \033[0;31m
NC     := \033[0m # No Color

# Package list - all stow packages to manage (DRY: defined once, used everywhere)
PACKAGES := bash bin claude git gtk ghostty oh-my-posh tmux yazi micro htop btop eza fzf glow lazygit lazydocker ripgrep

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo ""
	@echo "$(GREEN)Dotfiles Management - GNU Stow$(NC)"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

install: ## Install all dotfiles (create symlinks)
	@echo "$(GREEN)Installing all dotfiles...$(NC)"
	@stow -v $(PACKAGES)
	@echo "$(GREEN)✓ Installation complete$(NC)"
	@echo ""
	@echo "$(YELLOW)Manual step required:$(NC)"
	@echo "  Install system config: make install-system"
	@echo "  Then reload shell: source ~/.bashrc"

uninstall: ## Uninstall all dotfiles (remove symlinks)
	@echo "$(YELLOW)Removing all dotfiles symlinks...$(NC)"
	@stow -D -v $(PACKAGES)
	@echo "$(GREEN)✓ Uninstallation complete$(NC)"

update: ## Update dotfiles (restow after git pull)
	@echo "$(GREEN)Updating dotfiles from git...$(NC)"
	@git pull --rebase
	@echo "$(GREEN)Restowing packages...$(NC)"
	@stow -R -v $(PACKAGES)
	@echo "$(GREEN)✓ Update complete$(NC)"

link: install ## Alias for install

unlink: uninstall ## Alias for uninstall

list: ## List all stow packages
	@echo "$(GREEN)Available packages:$(NC)"
	@ls -d */ | grep -v '.git' | sed 's|/||' | awk '{print "  - " $$1}'

test: ## Test stow (dry run, shows what would be created)
	@echo "$(YELLOW)Dry run - showing what would be created:$(NC)"
	@stow -n -v $(PACKAGES)

clean: ## Clean up broken symlinks in home directory
	@echo "$(YELLOW)Finding broken symlinks in home directory...$(NC)"
	@find ~ -maxdepth 1 -xtype l -print | while read -r link; do \
		echo "  Removing broken symlink: $$link"; \
		rm "$$link"; \
	done
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

# Individual package targets
bash: ## Install bash configuration only
	@stow -v bash

bin: ## Install user scripts only
	@stow -v bin

git: ## Install git configuration only
	@stow -v git

ghostty: ## Install ghostty configuration only
	@stow -v ghostty

oh-my-posh: ## Install oh-my-posh configuration only
	@stow -v oh-my-posh

yazi: ## Install yazi configuration only
	@stow -v yazi

micro: ## Install micro configuration only
	@stow -v micro

htop: ## Install htop configuration only
	@stow -v htop

btop: ## Install btop configuration only
	@stow -v btop

claude: ## Install Claude Code configuration only
	@stow -v claude

gtk: ## Install GTK theme configuration only
	@stow -v gtk

# Git shortcuts
status: ## Show git status
	@git status

commit: ## Quick commit (prompts for message)
	@read -p "Commit message: " msg; \
	git add -A && git commit -m "$$msg"

push: ## Push to remote
	@git push

pull: ## Pull from remote
	@git pull --rebase

sync: ## Sync with remote (pull + push)
	@git pull --rebase && git push

# System configuration (requires sudo)
install-system: ## Install system-level configurations (requires sudo)
	@echo "$(GREEN)Installing system configurations...$(NC)"
	@echo "$(YELLOW)This requires sudo privileges$(NC)"
	@sudo install -m 0440 system/.config/sudoers.d/homebrew-path /etc/sudoers.d/homebrew-path
	@sudo visudo -c
	@echo "$(GREEN)✓ System configuration installed$(NC)"
	@echo "Homebrew tools now work with sudo"

.PHONY: verify-auth
verify-auth:  ## Verify authentication setup
	@echo "$(CYAN)=== Authentication Verification ===$(NC)"
	@echo ""
	@echo "$(YELLOW)Checking Bitwarden CLI...$(NC)"
	@command -v bw >/dev/null && echo "$(GREEN)✓$(NC) bw CLI installed" || echo "$(RED)✗$(NC) bw CLI not found"
	@echo ""
	@echo "$(YELLOW)Checking Bitwarden session...$(NC)"
	@test -n "$$BW_SESSION" && echo "$(GREEN)✓$(NC) BW_SESSION active" || echo "$(RED)✗$(NC) BW_SESSION not set (run: bw unlock)"
	@echo ""
	@echo "$(YELLOW)Checking development tokens...$(NC)"
	@test -n "$$GITHUB_TOKEN" && echo "$(GREEN)✓$(NC) GITHUB_TOKEN loaded" || echo "$(RED)✗$(NC) GITHUB_TOKEN not set"
	@test -n "$$GITLAB_TOKEN" && echo "$(GREEN)✓$(NC) GITLAB_TOKEN loaded" || echo "$(RED)✗$(NC) GITLAB_TOKEN not set"
	@test -n "$$COMPOSER_AUTH" && echo "$(GREEN)✓$(NC) COMPOSER_AUTH loaded" || echo "$(RED)✗$(NC) COMPOSER_AUTH not set"
	@echo ""
	@echo "$(YELLOW)Checking SSH agent...$(NC)"
	@test -S "$$HOME/.bitwarden-ssh-agent.sock" && echo "$(GREEN)✓$(NC) Bitwarden SSH agent socket found" || echo "$(RED)✗$(NC) SSH agent socket not found"
	@test -n "$$SSH_AUTH_SOCK" && echo "$(GREEN)✓$(NC) SSH_AUTH_SOCK set" || echo "$(RED)✗$(NC) SSH_AUTH_SOCK not set"
	@echo ""
	@echo "$(YELLOW)Checking gh CLI configuration...$(NC)"
	@test -f "$$HOME/.config/gh/config.yml" && echo "$(GREEN)✓$(NC) gh config exists" || echo "$(RED)✗$(NC) gh config not found"
	@command -v gh >/dev/null && gh config get git_protocol 2>/dev/null | grep -q ssh && echo "$(GREEN)✓$(NC) gh using SSH protocol" || echo "$(YELLOW)⚠$(NC) gh not configured for SSH"
	@echo ""
	@echo "$(YELLOW)Checking glab CLI configuration...$(NC)"
	@test -f "$$HOME/.config/glab-cli/config.yml" && echo "$(GREEN)✓$(NC) glab config exists" || echo "$(RED)✗$(NC) glab config not found"
	@grep -q "host: git.netresearch.de" "$$HOME/.config/glab-cli/config.yml" 2>/dev/null && echo "$(GREEN)✓$(NC) glab configured for git.netresearch.de" || echo "$(YELLOW)⚠$(NC) glab not configured for self-hosted GitLab"
	@echo ""
