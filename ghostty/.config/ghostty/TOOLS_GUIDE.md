# Terminal Enhancement Tools Guide
# =================================

This guide covers all the amazing CLI tools that enhance your Ghostty terminal experience.

## 🚀 Quick Start

### Installation

Run one of these commands:

```bash
# Simple installation (apt packages only)
~/.config/ghostty/install-simple.sh

# Full installation (includes eza, glow, viu from GitHub)
~/.config/ghostty/install-terminal-tools.sh
```

### Enable Tools in Your Shell

Add this line to your `~/.bashrc` (after the Oh My Posh line):

```bash
source ~/.bash_terminal_tools
```

Then reload:
```bash
source ~/.bashrc
```

---

## 📦 Tools Overview

### 1. **bat** - Better `cat` with Syntax Highlighting

Beautiful file viewer with syntax highlighting and Git integration.

**Usage:**
```bash
# View a file
bat filename.py

# View with line numbers
bat -n filename.js

# View specific lines
bat -r 10:50 file.txt

# Compare files side by side
bat file1.js file2.js
```

**Supported Languages:** 200+ languages including Python, JavaScript, Rust, Go, etc.

---

### 2. **eza** - Modern `ls` Replacement

Modern ls with icons, Git status, and beautiful colors.

**Usage:**
```bash
# Basic listing with icons
ls

# Long format with Git status
ll

# Show all files including hidden
la

# Tree view (2 levels)
lt

# Tree view (3 levels)
lt3

# Sort by size
eza -lS

# Sort by modified time
eza -lt modified

# Show only directories
eza -D
```

**Icons:** Works perfectly with Ghostty's built-in Nerd Fonts!

---

### 3. **glow** - Markdown Viewer

Render beautiful markdown in your terminal.

**Usage:**
```bash
# View markdown file
glow README.md

# View with pager (for long files)
glow -p documentation.md

# View README in current directory
readme

# Fetch and view from URL
glow https://raw.githubusercontent.com/user/repo/main/README.md

# List and select from markdown files
glow
```

**Styles:** Dark, light, notty, pink, dracula (configure with `glow config`)

---

### 4. **fzf** - Fuzzy Finder

Interactive fuzzy file finder with preview.

**Usage:**
```bash
# Find files (Ctrl+T)
<Ctrl+T>

# Command history (Ctrl+R)
<Ctrl+R>

# Change directory (Alt+C)
<Alt+C>

# Find and edit file
fe

# Change directory interactively
fcd

# Search with preview
search <query>

# Find process and kill
ps aux | fzf | awk '{print $2}' | xargs kill
```

**Preview:** Shows file contents with bat syntax highlighting!

---

### 5. **ranger** - Terminal File Manager

Visual file manager with vi-like keybindings.

**Usage:**
```bash
# Open ranger
ranger

# Open and cd on exit
r

# Navigation:
#   j/k     - Move down/up
#   h/l     - Parent directory / Enter directory
#   gg/G    - Top/bottom
#   /       - Search
#   Space   - Select file
#   yy      - Copy
#   dd      - Cut
#   pp      - Paste
#   q       - Quit
```

**Features:** File preview, image preview (with w3m), bulk operations

---

### 6. **ripgrep (rg)** - Fast grep

Blazingly fast search tool that respects .gitignore.

**Usage:**
```bash
# Search for pattern
rg "function"

# Search in specific file types
rg "TODO" -t py

# Search case-insensitive
rg -i "error"

# Show context (3 lines before/after)
rg -C 3 "import"

# Search for whole word
rg -w "test"

# Count matches
rg -c "error"
```

**Speed:** Often 5-10x faster than grep!

---

### 7. **fd** - Fast find

Simple, fast, and user-friendly alternative to find.

**Usage:**
```bash
# Find files
fd pattern

# Find only files
fd -t f pattern

# Find only directories
fd -t d pattern

# Search hidden files
fd -H pattern

# Execute command on results
fd pattern -x bat {}

# Exclude directories
fd pattern -E node_modules
```

---

### 8. **viu / chafa** - Image Viewers

Display images directly in your terminal.

**Usage:**
```bash
# View image with viu
viu image.png

# View with specific width
viu -w 50 image.jpg

# View image with chafa
chafa image.png

# Animated GIF
chafa animation.gif
```

**Supported:** PNG, JPG, GIF, WebP, etc.

---

### 9. **preview** Function

Smart file preview that detects file type.

**Usage:**
```bash
# Auto-detect and preview
preview file.py       # Syntax highlighted
preview README.md     # Rendered markdown
preview image.png     # Image in terminal
preview data.json     # Formatted JSON
```

---

### 10. **ncdu** - Disk Usage Analyzer

Interactive disk usage analyzer.

**Usage:**
```bash
# Analyze current directory
ncdu

# Analyze specific directory
ncdu /home

# Navigation:
#   Up/Down - Navigate
#   Enter   - Enter directory
#   d       - Delete file/folder
#   g       - Show graph
#   q       - Quit
```

---

## 🎨 Complete Examples

### Example 1: Find and Edit Files
```bash
# Find JavaScript files and edit the selected one
fe .js
```

### Example 2: Search in Project
```bash
# Search for "TODO" in Python files with context
rg "TODO" -t py -C 3
```

### Example 3: Browse Files Visually
```bash
# Open ranger file manager
r

# Or use fzf with preview
fzf --preview 'bat --color=always {}'
```

### Example 4: View Documentation
```bash
# View README
readme

# View any markdown with style
glow docs/api.md
```

### Example 5: Analyze Directory
```bash
# Show largest files in current directory
largest

# Interactive disk usage
ncdu
```

### Example 6: Work with Images
```bash
# View image in terminal
viu screenshot.png

# Or with chafa
chafa logo.png
```

---

## ⚙️ Configuration

### bat Configuration

Create `~/.config/bat/config`:

```
--theme="Catppuccin Mocha"
--style="numbers,changes,header"
--pager="never"
```

### ranger Configuration

Generate config:
```bash
ranger --copy-config=all
```

Edit `~/.config/ranger/rc.conf` for customization.

### glow Configuration

Set style:
```bash
glow config set style dark
# or
glow config set style dracula
```

---

## 🔥 Pro Tips

### 1. Combine Tools
```bash
# Search and preview
rg "function" -l | fzf --preview 'bat {}'

# Find large files and preview
fd -t f | xargs du -h | sort -rh | head -20 | fzf --preview 'bat {2}'
```

### 2. Use Aliases
```bash
# Already configured in .bash_terminal_tools
cat     # Uses bat
ls      # Uses eza
grep    # Uses ripgrep
find    # Uses fd
```

### 3. FZF Power User
```bash
# Search files and open in editor
fe

# Search history
<Ctrl+R>

# Change directory quickly
fcd
```

### 4. Ranger Tips
- Press `1/2/3/4` to change views
- Use `zh` to toggle hidden files
- Press `S` to open shell in current directory
- Use `!command` to run shell command

### 5. Markdown Everywhere
```bash
# Create and view notes
echo "# Notes" > notes.md
glow notes.md

# View documentation from GitHub
glow https://raw.githubusercontent.com/user/repo/main/README.md
```

---

## 📚 Additional Tools

### Also Installed:

- **tree** - Directory tree view: `tree -L 2`
- **htop** - Interactive process viewer: `htop`
- **jq** - JSON processor: `jq . data.json`
- **tldr** - Simplified man pages: `tldr tar`

---

## 🆘 Help Commands

```bash
# Show all tools help
tools

# Individual tool help
bat --help
eza --help
glow --help
fzf --help
ranger --help
rg --help
fd --help
```

---

## 🔧 Troubleshooting

### bat shows as batcat
On Ubuntu, bat is installed as `batcat`. The alias makes it available as `bat`.

### Icons not showing
Make sure you're using a Nerd Font. Ghostty has them built-in, so this should work automatically.

### ranger doesn't show images
Install `w3m-img`: `sudo apt install w3m-img`

### fzf preview not working
Make sure bat is installed. Check with: `which batcat`

---

## 🚀 Next Steps

1. **Install the tools** using one of the install scripts
2. **Add to bashrc**: `echo 'source ~/.bash_terminal_tools' >> ~/.bashrc`
3. **Reload shell**: `source ~/.bashrc`
4. **Try it out**: Type `tools` to see the help
5. **Experiment**: Try `fe`, `r`, `glow README.md`, etc.

---

## 📖 Resources

- [bat GitHub](https://github.com/sharkdp/bat)
- [eza GitHub](https://github.com/eza-community/eza)
- [glow GitHub](https://github.com/charmbracelet/glow)
- [fzf GitHub](https://github.com/junegunn/fzf)
- [ranger GitHub](https://github.com/ranger/ranger)
- [ripgrep GitHub](https://github.com/BurntSushi/ripgrep)
- [fd GitHub](https://github.com/sharkdp/fd)

---

Enjoy your supercharged terminal! 🎉
