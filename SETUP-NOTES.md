# System Setup Reference

## Keyboard Fixes (Ghostty + Bash)

### CSI u Compatibility Solution

**Issue**: Ghostty uses CSI u protocol; Bash/readline doesn't support it.

**Files Modified**:
- `~/.inputrc` - Readline CSI sequence handling
- `~/.config/ghostty/config` - Terminal keybind overrides

**Solution**:
1. `.inputrc` consumes CSI sequences via `skip-csi-sequence`
2. Ghostty sends legacy ASCII codes for Ctrl+A-Z

```bash
# ~/.inputrc
"\e[": skip-csi-sequence
"\e]": skip-csi-sequence
"\e\\": skip-csi-sequence
```

```toml
# ~/.config/ghostty/config (example)
keybind = ctrl+r=text:\x12  # Reverse search
keybind = ctrl+a=text:\x01  # Beginning of line
```

**Reload**:
```bash
# Reload Ghostty config
Ctrl+Shift+R

# Reload bash
exec bash
```

### Key Behavior

| Key Pattern | Bash | fzf | Terminal Shortcuts |
|-------------|------|-----|-------------------|
| Ctrl+A-Z | Works | Works | N/A |
| Shift+Ctrl+C/V/T | N/A | N/A | Copy/Paste/Tab |
| Other Shift+Ctrl | Ignored | Shows CSI (expected) | N/A |

**Note**: Comments must be on separate lines in Ghostty config, not inline.

---

## fzf Usage

### Three Modes

| Key | Searches | Action | Preview Toggle |
|-----|----------|--------|----------------|
| **Ctrl+T** | Files + Dirs | Insert path | `Ctrl+/` |
| **Ctrl+R** | Command history | Insert command | `?` |
| **Alt+C** | Directories only | cd to directory | Always on |

### Preview Details

**Ctrl+T** (File/Directory):
- Files: Syntax highlighted (bat)
- Directories: Tree structure (eza)
- Binary: "[Binary file]" message

**Ctrl+R** (History):
- Full command with wrapped text
- Default hidden, press `?` to toggle

**Alt+C** (Directory Navigation):
- eza tree preview always visible
- Actually changes directory (cd)

### Preview Scrolling

- `Ctrl+U` - Scroll up (page up)
- `Ctrl+D` - Scroll down (page down)

### Manual Usage

```bash
# File search with preview
find . -type f | fzf --preview 'bat --color=always {}'

# Git log with diff
git log --oneline | fzf --preview 'git show {1}'

# Directory tree
ls -d */ | fzf --preview 'eza --tree {}'
```

**Config Location**: `~/.config/fzf/` (stowed from `~/dotfiles/fzf/`)

---

## Configuration Reload

| Component | How to Reload |
|-----------|---------------|
| Ghostty | `Ctrl+Shift+R` |
| Bash | `exec bash` |
| bashrc/exports | `. ~/.bashrc` |
| inputrc | `exec bash` |

---

## Tools Overview

### bat (Syntax Highlighter)
**Use**: Syntax-highlighted file viewing
**Config**: Uses Homebrew defaults (no custom config)
**Commands**:
```bash
bat file.py                    # View with syntax
bat --style=plain file.txt     # Plain text
```

### eza (Modern ls)
**Use**: Enhanced directory listings
**Config**: Aliased in `~/dotfiles/bash/.bash/aliases`
**Commands**:
```bash
eza --tree                     # Tree view
eza -l --git                   # Long format with git status
eza -la                        # All files, long format
```

### fzf (Fuzzy Finder)
**Use**: Interactive file/command search
**Config**: `~/.config/fzf/config` (UI options) + `~/.bash/exports/fzf.bash` (shell integration)
**Keybindings**: See "fzf Usage" section above
**Integration**: Ctrl+T, Ctrl+R, Alt+C in bash

### yazi (File Manager)
**Use**: Terminal file manager with preview
**Config**: `~/dotfiles/yazi/.config/yazi/yazi.toml`
**Commands**:
```bash
yazi                           # Launch file manager
yazi /path/to/dir              # Open specific directory
```
**Note**: yazi preview is separate from fzf preview (different config files)

---

## Troubleshooting

### Escape sequences visible in bash
```bash
# Check if .inputrc is loaded
bind -v | grep csi
# Should show: "\e[": skip-csi-sequence

# If missing, reload bash
exec bash
```

### Ctrl+R not working
```bash
# Reload Ghostty config
Ctrl+Shift+R (in Ghostty)

# Verify keybind
grep "ctrl+r" ~/.config/ghostty/config
```

### fzf shows CSI codes on Shift+Ctrl
**Expected behavior**: fzf doesn't use readline, receives CSI u directly.
**Solution**: Don't use Shift+Ctrl combinations in fzf (not needed).

### fzf preview not showing
```bash
# Check if bat/eza are installed
which bat eza

# Check FZF environment variables
echo $FZF_CTRL_T_OPTS

# Reload bash exports
. ~/.bashrc
```

---

**Last Updated**: 2025-12-16
**Status**: Production Ready
