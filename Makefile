# Dotfiles Makefile - GNU Stow Management
# Usage: make help

.PHONY: help install uninstall update link unlink list test clean

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
NC     := \033[0m # No Color

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
	@stow -v bash bin git gtk ghostty oh-my-posh yazi micro htop btop
	@echo "$(GREEN)✓ Installation complete$(NC)"
	@echo "Run 'source ~/.bashrc' to reload shell"

uninstall: ## Uninstall all dotfiles (remove symlinks)
	@echo "$(YELLOW)Removing all dotfiles symlinks...$(NC)"
	@stow -D -v bash bin git gtk ghostty oh-my-posh yazi micro htop btop
	@echo "$(GREEN)✓ Uninstallation complete$(NC)"

update: ## Update dotfiles (restow after git pull)
	@echo "$(GREEN)Updating dotfiles from git...$(NC)"
	@git pull --rebase
	@echo "$(GREEN)Restowing packages...$(NC)"
	@stow -R -v bash bin git gtk ghostty oh-my-posh yazi micro htop btop
	@echo "$(GREEN)✓ Update complete$(NC)"

link: install ## Alias for install

unlink: uninstall ## Alias for uninstall

list: ## List all stow packages
	@echo "$(GREEN)Available packages:$(NC)"
	@ls -d */ | grep -v '.git' | sed 's|/||' | awk '{print "  - " $$1}'

test: ## Test stow (dry run, shows what would be created)
	@echo "$(YELLOW)Dry run - showing what would be created:$(NC)"
	@stow -n -v bash bin git gtk ghostty oh-my-posh yazi micro htop btop

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
