# Yazi Terminal File Manager Guide

## 🚀 Quick Start

### Opening Yazi

**Keyboard Shortcut:**
- **Ctrl+O** - Opens yazi instantly (from anywhere on command line)

**Commands:**
```bash
y          # Opens yazi, changes directory on exit
yy         # Same as y
fm         # Same as y (file manager)
```

---

## ⌨️ Essential Keybindings

### Navigation
```
j/k         - Move down/up
h/l         - Go back / Enter directory (or open file)
gg          - Go to top
G           - Go to bottom
~           - Go to home directory
```

### Selection & Operations
```
Space       - Select/deselect file (multi-select)
v           - Visual mode (select multiple)
a           - Select all
V           - Inverse selection

y           - Copy (yank) selected files
x           - Cut selected files
p           - Paste files
d           - Delete selected files
r           - Rename file
```

### Tabs
```
t           - Create new tab
1-9         - Switch to tab 1-9
[           - Previous tab
]           - Next tab
```

### Search & Filter
```
/           - Search in current directory
f           - Filter (show only matching files)
```

### Preview & View
```
Enter       - Open file with default program
i           - Preview mode (toggle)
```

### Quit
```
q           - Quit and change directory (to current location)
Q           - Quit WITHOUT changing directory
```

---

## 🎨 What Makes Yazi Special

### 1. **Built-in Previews** (No Configuration!)

**Markdown files:**
- Beautifully rendered with syntax highlighting
- Shows headings, lists, code blocks

**Images:**
- Sharp, high-quality preview
- PNG, JPG, GIF, WebP, etc.

**Code files:**
- Syntax highlighting for 100+ languages
- Python, JavaScript, Rust, Go, etc.

**PDFs:**
- First page preview
- Quick navigation

**Videos:**
- Thumbnail preview
- Shows video info

**Archives:**
- Shows contents of zip, tar, etc.
- No need to extract

---

## 💡 Pro Tips

### 1. **Multi-file Operations**
```bash
# Select multiple files with Space
Space, Space, Space
# Then:
y    # Copy all selected
p    # Paste elsewhere
```

### 2. **Quick Navigation**
```bash
~    # Jump to home
g    # Then press:
     c - ~/.config
     d - ~/Downloads
     D - ~/Desktop
```

### 3. **Search and Open**
```bash
/keyword    # Search
n           # Next result
Enter       # Open file
```

### 4. **Bulk Rename**
```bash
# Select multiple files
Space, Space, Space
# Press: r
# Opens editor to rename all at once!
```

---

## 🎯 Common Workflows

### **Browse and Edit Code**
```
Ctrl+O       # Open yazi
/config      # Search for config files
Enter        # Opens in $EDITOR (micro)
```

### **Copy Files Between Directories**
```
Ctrl+O       # Open yazi
Space        # Select files
y            # Yank (copy)
h            # Go back
l            # Enter target directory
p            # Paste
```

### **Preview Images/PDFs**
```
Ctrl+O       # Open yazi
j/k          # Navigate
# Preview shows automatically!
```

### **Quick Directory Jump**
```
y            # Open yazi
j/k          # Navigate to directory
q            # Quit and change to that directory
```

---

## ⚙️ Configuration (Optional)

Yazi config is at: `~/.config/yazi/`

**Files:**
- `yazi.toml` - Main configuration
- `keymap.toml` - Custom keybindings
- `theme.toml` - Color scheme

**But honestly?** The defaults are perfect!

---

## 🆚 Comparison with Ranger

| Feature | Ranger | Yazi |
|---------|--------|------|
| Markdown preview | ❌ Needs setup | ✅ Beautiful |
| Image preview | ⚠️ Manual config | ✅ Sharp, instant |
| Speed | ⚠️ Can freeze | ✅ Async, fast |
| Configuration | ❌ Required | ✅ Works out of box |
| Memory | 28MB | 38MB |
| Modern | ❌ 2013 | ✅ 2025 |

---

## 🐛 Troubleshooting

### **Images don't show**
Yazi automatically uses the best available protocol:
- Ghostty supports image preview natively
- Should work out of the box

### **Can't open files**
Set your editor:
```bash
export EDITOR=micro
export VISUAL=micro
```
(Already in your ~/.bashrc)

### **Yazi not found after install**
```bash
source ~/.bashrc
```

---

## 📚 Advanced Features

### **Shell Commands**
```
:          # Execute shell command
:!ls -la   # Run command and see output
```

### **Bookmarks**
```
m          # Create bookmark
'          # Go to bookmark
```

### **Sorting**
```
s          # Sort menu
    m - modified time
    a - alphabetically
    s - size
```

---

## 🎓 Learning Curve

**Familiar from Vim?** You already know it!
- `hjkl` navigation
- `gg/G` for top/bottom
- `/` for search
- Visual mode with `v`

**New to Vim?** Still easy!
- Arrow keys work too
- Mouse support (click to select)
- Tab to auto-complete

---

## 🔗 Resources

- **Official Docs:** https://yazi-rs.github.io/
- **Keybindings:** Press `?` in yazi for help
- **This Guide:** `~/.config/ghostty/YAZI_GUIDE.md`

---

Enjoy your blazing-fast file manager! 🚀
