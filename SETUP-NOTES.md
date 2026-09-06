# System Setup Reference

## Keyboard Encoding (Ghostty + Bash)

Ghostty follows the fixterms spec and sends Ctrl+[ / Ctrl+I / Ctrl+M as CSI u sequences so they stay
distinguishable from Esc / Tab / Enter. Everything else already arrives as the legacy byte, and apps that
want more (Claude Code, herdr) switch the terminal into the kitty keyboard protocol themselves.

**Files**:
- `~/.config/ghostty/config` - five keybind overrides, each commented with its reason
- `~/.inputrc` - `skip-csi-sequence` so readline swallows CSI sequences bash has no binding for
  (e.g. Shift+Enter at a bash prompt) instead of inserting them as text

**Rules of thumb**:
- Do not add `text:` overrides for Ctrl+letter, Alt+digit or arrow chords: they are byte-identical
  without one, and inside Claude Code or herdr they hide the modifier from the app (verified 2026-09-06
  with a raw-key probe in both encodings).
- fzf does not speak CSI u, which is why the three fixterms keys are mapped back to control bytes.
- Comments must be on separate lines in Ghostty config, not inline.

**Reload**: `Ctrl+Shift+R` in Ghostty, `exec bash` for readline.

---

## fzf Usage

### Three Modes

| Key | Searches | Action | Preview Toggle |
|-----|----------|--------|----------------|
| **Ctrl+T** | Files + Dirs | Insert path | `Ctrl+/` |
| **Ctrl+R** | Command history | Insert command | `Ctrl+/` |
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

### fzf shows CSI codes
fzf does not use readline and cannot parse CSI u. Ctrl+[ / Ctrl+I / Ctrl+M are mapped back to control
bytes in the Ghostty config; other modified chords have no fzf binding anyway.

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
