# fzf Configuration

Organized config directory for easy experimentation with fzf settings.

## Structure

```
~/.config/fzf/               # Symlinked to ~/dotfiles/fzf/.config/fzf/
├── config                   # Main fzf options (FZF_DEFAULT_OPTS_FILE)
└── fzf.bash                 # Shell integration (sourced from .bash/exports)
```

## Files

### `config`
- **Shell-agnostic** fzf options (works with bash, zsh, fish)
- Loaded via `FZF_DEFAULT_OPTS_FILE` environment variable
- Contains universal UI settings (layout, borders, keybindings)
- **Edit and reload**: Just run `exec bash` or `source ~/.bash/exports`

### `fzf.bash`
- **Bash-specific** integration
- Sets up mode-specific options (Ctrl+T, Ctrl+R, Alt+C)
- Contains preview commands with bat/eza
- Requires shell logic for tool detection

## Quick Edits

### Change Layout or Colors
```bash
# Edit main config
micro ~/.config/fzf/config

# Or directly in dotfiles
micro ~/dotfiles/fzf/.config/fzf/config

# Reload
exec bash
```

### Change Preview Commands
```bash
# Edit shell integration
micro ~/.config/fzf/fzf.bash

# Reload
exec bash
```

## Configuration Priority

fzf loads options in this order (lowest to highest priority):

1. **FZF_DEFAULT_OPTS_FILE** (`~/.config/fzf/config`)
2. **FZF_DEFAULT_OPTS** (not used, replaced by config file)
3. **Command-line arguments** (when calling fzf directly)

Mode-specific options override defaults:
- `FZF_CTRL_T_OPTS` - File finder (Ctrl+T)
- `FZF_CTRL_R_OPTS` - History search (Ctrl+R)
- `FZF_ALT_C_OPTS` - Directory navigator (Alt+C)

## Examples

### Add History File
```bash
# Edit: ~/.config/fzf/config
# Add:
--history=/home/sebastian/.fzf_history
--history-size=10000
```

### Change Colors (Catppuccin)
```bash
# Edit: ~/.config/fzf/config
# Uncomment the color scheme lines
--color=bg+:#414559,bg:#303446,spinner:#f2d5cf,hl:#e78284
--color=fg:#c6d0f5,header:#e78284,info:#ca9ee6,pointer:#f2d5cf
```

### Customize Preview Height
```bash
# Edit: ~/.config/fzf/fzf.bash
# Change FZF_CTRL_T_OPTS preview window:
--preview-window='right:60%'  # Make preview 60% width
```

## Benefits

✅ **Easy experimentation** - Edit config files directly, reload bash
✅ **Version controlled** - All in ~/dotfiles, tracked by git
✅ **Shell-agnostic base** - Main config works with any shell
✅ **Modular** - Separate universal options from shell-specific
✅ **Stow managed** - Symlinked via stow package

## Migration Note

Previous configuration was inline in `~/dotfiles/bash/.bash/exports`.
Now it's split into:
- Universal options → `~/.config/fzf/config`
- Shell integration → `~/.config/fzf/fzf.bash`

This makes it easier to experiment and share configs across different shells.
