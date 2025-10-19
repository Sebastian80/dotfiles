# Ghostty + Oh My Posh Setup Guide

## Quick Reference

### Reload Ghostty Config
Press `Ctrl+Shift+,` to reload the configuration without restarting.

### Oh My Posh Theme Management

#### List Available Themes
Visit [https://ohmyposh.dev/docs/themes](https://ohmyposh.dev/docs/themes) to browse all themes with previews.

#### Switch to a Different Theme
Edit `~/.bashrc` and change line 132:

```bash
# Current theme
eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/iterm2.omp.json)"

# Popular alternatives:
# eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/catppuccin.omp.json)"
# eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/powerlevel10k_rainbow.omp.json)"
# eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/dracula.omp.json)"
# eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/spaceship.omp.json)"
# eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/tokyo.omp.json)"
# eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/bubbles.omp.json)"
```

Then reload your bashrc:
```bash
source ~/.bashrc
```

#### Create a Custom Theme
Export your current theme to customize it:

```bash
oh-my-posh config export --output ~/.config/oh-my-posh/my-custom-theme.omp.json
```

Then edit `my-custom-theme.omp.json` and update your bashrc to use it.

#### Preview a Theme Before Applying
```bash
oh-my-posh print preview
```

#### Enable Live Reload for Theme Development
```bash
oh-my-posh enable reload
```

This will automatically reload your theme when you save changes to the config file.

---

## Current Setup

### Ghostty Configuration
- **Location**: `~/.config/ghostty/config`
- **Theme**: Catppuccin (Mocha for dark, Latte for light)
- **Font**: JetBrains Mono 13pt with Nerd Font support
- **Transparency**: 92% opacity with blur enabled
- **Shell Integration**: Enabled for smart features

### Oh My Posh Configuration
- **Location**: Configured in `~/.bashrc` (line 132)
- **Current Theme**: iterm2
- **Themes Directory**: `~/.config/oh-my-posh/themes/`

---

## Popular Oh My Posh Themes

### 1. **catppuccin** (Highly Recommended!)
Modern, pastel color scheme that matches Ghostty's theme perfectly.
```bash
eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/catppuccin.omp.json)"
```

### 2. **powerlevel10k_rainbow**
Colorful, feature-rich theme inspired by Powerlevel10k.
```bash
eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/powerlevel10k_rainbow.omp.json)"
```

### 3. **tokyo**
Clean, modern theme with Tokyo-inspired colors.
```bash
eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/tokyo.omp.json)"
```

### 4. **dracula**
Popular dark theme with excellent contrast.
```bash
eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/dracula.omp.json)"
```

### 5. **bubbles**
Fun, rounded segments with playful design.
```bash
eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/bubbles.omp.json)"
```

### 6. **spaceship**
Minimalist, sleek design inspired by Spaceship prompt.
```bash
eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/spaceship.omp.json)"
```

---

## Ghostty Theme Options

Edit `~/.config/ghostty/config` and change the theme line:

### Dark Themes
```ini
theme = Catppuccin Mocha           # Soft pastels (current)
theme = TokyoNight                 # Modern blues/purples
theme = Monokai Pro                # Professional, high contrast
theme = Dracula                    # Popular dark theme
theme = GitHub Dark Default        # GitHub's dark theme
theme = Nord                       # Cool Nordic palette
```

### Light Themes
```ini
theme = Catppuccin Latte           # Soft light theme (current)
theme = Ayu Light                  # Clean, minimal
theme = GitHub Light Default       # GitHub's light theme
theme = One Half Light             # Balanced and bright
```

### Auto-Switch (Current Setup)
```ini
theme = dark:Catppuccin Mocha,light:Catppuccin Latte
```

---

## Optional Enhancements

### 1. Install Better Terminal Tools

#### eza (Modern ls replacement)
```bash
sudo apt install eza
alias ls='eza --icons'
alias ll='eza --icons -la'
alias tree='eza --tree --icons'
```

#### bat (Better cat with syntax highlighting)
```bash
sudo apt install bat
alias cat='batcat'
```

#### fzf (Fuzzy finder)
```bash
sudo apt install fzf
# Add to ~/.bashrc:
eval "$(fzf --bash)"
```

#### ripgrep (Fast grep replacement)
```bash
sudo apt install ripgrep
```

### 2. Add These to ~/.bashrc

```bash
# Better directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git shortcuts (if you use git)
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# System
alias update='sudo apt update && sudo apt upgrade'
alias ports='netstat -tulanp'

# Modern tools (if installed)
alias ls='eza --icons'
alias ll='eza --icons -la'
alias cat='batcat'
```

### 3. Bash Customization

Add to `~/.bashrc` for better history:

```bash
# Better history
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T '
shopt -s histappend
```

---

## Troubleshooting

### Icons Not Showing in Oh My Posh
Ghostty has Nerd Fonts built-in, so this should work automatically. If you still have issues:
1. Make sure you're using JetBrains Mono (already configured)
2. Restart Ghostty completely

### Theme Colors Look Wrong
1. Reload Ghostty config: `Ctrl+Shift+,`
2. Or restart Ghostty
3. Check that your terminal is set to use true color

### Oh My Posh Not Loading
Check that this line is at the end of `~/.bashrc`:
```bash
eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/iterm2.omp.json)"
```

---

## Next Steps

1. **Try Different Themes**: Browse [Oh My Posh themes](https://ohmyposh.dev/docs/themes) and experiment!
2. **Customize Ghostty**: Edit `~/.config/ghostty/config` - try different transparency levels, fonts, or colors
3. **Install Better Tools**: Consider adding eza, bat, fzf for enhanced terminal experience
4. **Create Custom Theme**: Export and modify an Oh My Posh theme to make it yours

---

## Resources

- [Ghostty Documentation](https://ghostty.org/docs)
- [Oh My Posh Documentation](https://ohmyposh.dev/docs)
- [Oh My Posh Themes Gallery](https://ohmyposh.dev/docs/themes)
- [Nerd Fonts](https://www.nerdfonts.com/)

---

Enjoy your beautiful terminal setup!
