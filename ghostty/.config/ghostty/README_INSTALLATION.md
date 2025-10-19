# Ghostty Terminal Enhancement Tools

## 🎉 What You're Getting

Transform your Ghostty terminal into a powerhouse with these modern CLI tools:

### 📦 Tools Included

| Tool | Purpose | What It Does |
|------|---------|--------------|
| **bat** | File viewer | `cat` with syntax highlighting |
| **eza** | File listing | Modern `ls` with icons & Git status |
| **glow** | Markdown viewer | Beautiful markdown rendering |
| **fzf** | Fuzzy finder | Interactive file/history search |
| **ranger** | File manager | Visual file browser with preview |
| **ripgrep (rg)** | Search | Blazing fast grep alternative |
| **fd** | File finder | Fast & user-friendly find |
| **viu** | Image viewer | Display images in terminal |
| **chafa** | Image viewer | Alternative image display |
| **ncdu** | Disk analyzer | Interactive disk usage |
| **htop** | Process monitor | Better top |
| **jq** | JSON processor | Format & query JSON |

---

## 🚀 Quick Installation (3 Steps)

### Step 1: Install the Tools

Choose one:

**Option A: Simple Install** (recommended for beginners)
```bash
~/.config/ghostty/install-simple.sh
```
This installs only tools available in apt repos.

**Option B: Full Install** (includes latest versions)
```bash
~/.config/ghostty/install-terminal-tools.sh
```
This also downloads eza, glow, and viu from GitHub.

### Step 2: Reload Your Shell
```bash
source ~/.bashrc
```

### Step 3: Try It Out!
```bash
# Show help
tools

# Try some commands
ls                    # Modern ls with icons
bat ~/.bashrc         # View file with syntax highlighting
glow ~/.config/ghostty/TOOLS_GUIDE.md    # Beautiful markdown
```

---

## 📚 Documentation

All guides are in `~/.config/ghostty/`:

- **TOOLS_GUIDE.md** - Complete guide with examples
- **QUICKREF.txt** - Quick reference card
- **SETUP_GUIDE.md** - Ghostty & Oh My Posh setup
- **POPULAR_THEMES.txt** - Theme reference

---

## 🎨 Already Configured

### ✅ Ghostty Configuration
- Location: `~/.config/ghostty/config`
- Theme: Catppuccin (auto-switches dark/light)
- Font: JetBrains Mono with Nerd Fonts
- Features: Transparency, blur, shell integration

### ✅ Oh My Posh
- Location: Configured in `~/.bashrc`
- Current theme: iterm2
- Switch themes: `~/.config/oh-my-posh/switch-theme.sh [theme]`

### ✅ Terminal Tools
- Location: `~/.bash_terminal_tools`
- Auto-loaded: Yes (added to `~/.bashrc`)
- Aliases: Pre-configured for all tools

---

## 💡 Quick Examples

### View Files
```bash
# Syntax-highlighted file viewing
bat script.py

# Markdown rendering
glow README.md
```

### List Files
```bash
# Modern ls with icons
ls

# Long format with Git status
ll

# Tree view
lt
```

### Search & Find
```bash
# Fast search
rg "TODO" -t py

# Find files
fd "config"

# Interactive fuzzy search
Ctrl+T      # Find files
Ctrl+R      # Search history
```

### File Manager
```bash
# Open ranger (visual file browser)
r
```

### Images
```bash
# View image in terminal
viu screenshot.png
```

---

## 🔧 Manual Installation Commands

If scripts don't work, install manually:

```bash
sudo apt update
sudo apt install -y \
    bat \
    fzf \
    ranger \
    ripgrep \
    fd-find \
    tree \
    ncdu \
    htop \
    jq \
    chafa

# Then reload
source ~/.bashrc
```

---

## ⚙️ What Was Modified

1. **Created Files:**
   - `~/.bash_terminal_tools` - Aliases and functions
   - `~/.config/ghostty/config` - Ghostty configuration
   - `~/.config/ghostty/*.md` - Documentation files
   - `~/.config/ghostty/install-*.sh` - Install scripts

2. **Modified Files:**
   - `~/.bashrc` - Added source line for terminal tools (line 134-137)

3. **Nothing Else Changed:**
   - Your system is safe
   - All changes are reversible
   - No system-wide modifications

---

## 🗑️ Uninstall

To remove everything:

```bash
# Remove tools
sudo apt remove bat fzf ranger ripgrep fd-find chafa ncdu htop jq

# Remove configuration
rm ~/.bash_terminal_tools
rm -rf ~/.config/ghostty

# Remove from .bashrc (lines 134-137)
nano ~/.bashrc  # Delete the terminal tools section
```

---

## 🆘 Troubleshooting

### Tools Don't Work After Installation

```bash
# Reload your shell
source ~/.bashrc

# Or open a new terminal
```

### bat shows as batcat

On Ubuntu, `bat` is installed as `batcat`. The alias makes it work as `bat`.

### Icons Not Showing

Ghostty has Nerd Fonts built-in, but if icons don't show:
1. Make sure you're in Ghostty terminal
2. Reload config: `Ctrl+Shift+,`

### Permission Denied on Scripts

```bash
chmod +x ~/.config/ghostty/install-*.sh
```

---

## 📖 Learn More

### Interactive Help
```bash
# Show all commands
tools

# Individual tool help
bat --help
eza --help
glow --help
```

### Documentation
```bash
# Complete guide
cat ~/.config/ghostty/TOOLS_GUIDE.md

# Or view beautifully
glow ~/.config/ghostty/TOOLS_GUIDE.md

# Quick reference
cat ~/.config/ghostty/QUICKREF.txt
```

---

## 🎯 Next Steps

1. **Install the tools** (run one of the install scripts above)
2. **Reload shell**: `source ~/.bashrc`
3. **Try it**: Type `tools` to see help
4. **Explore**: Try `ll`, `bat file`, `glow README.md`, etc.
5. **Read docs**: `glow ~/.config/ghostty/TOOLS_GUIDE.md`

---

## 🌟 Pro Tips

- Type `tools` anytime for help
- Use `Ctrl+T` for interactive file search
- Use `Ctrl+R` for command history search
- Type `r` to open ranger file manager
- All aliases are in `~/.bash_terminal_tools`

---

Enjoy your enhanced terminal experience! 🚀

Got questions? Check the docs in `~/.config/ghostty/`
