# System Configuration Files

This directory contains system-level configuration files that require root access to install.

## Files

### sudoers.d/homebrew-path
Adds Homebrew paths to sudo's secure_path, allowing Homebrew-installed tools (bat, eza, fd, rg, etc.) to work with sudo commands.

**Installation:**
```bash
sudo install -m 0440 ~/.config/sudoers.d/homebrew-path /etc/sudoers.d/homebrew-path
sudo visudo -c  # Validate configuration
```

**Why needed:**
By default, sudo uses a restricted PATH for security. This configuration adds Homebrew's bin directories so that aliased commands (like `sudo cat` → `bat`, `sudo ls` → `eza`) work correctly.

**Security note:**
This is safe because:
1. Homebrew paths are user-controlled but still validated by sudo
2. Only affects PATH, not sudo authentication
3. Standard practice for systems using Homebrew
4. Maintains sudo's security model

## Installation via Stow

The sudoers file should be manually installed (not stowed) because:
1. It requires root privileges
2. Incorrect permissions (must be 0440) can lock you out
3. Should be validated with `visudo -c` before activation

Add this to your installation script or Makefile.

## Verification

After installation, verify the sudoers configuration is working properly:

### 1. Check file is installed

```bash
ls -la /etc/sudoers.d/homebrew-path
# Should show: -r--r----- 1 root root 147 <date> /etc/sudoers.d/homebrew-path
```

### 2. Verify permissions are correct

```bash
stat -c '%a %U:%G' /etc/sudoers.d/homebrew-path
# Should show: 440 root:root
```

### 3. Validate syntax with visudo

```bash
sudo visudo -c
# Should show: /etc/sudoers: parsed OK
#              /etc/sudoers.d/homebrew-path: parsed OK
```

### 4. Check PATH includes Homebrew

```bash
sudo env | grep PATH
# Should include: /home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin
```

### 5. Test with aliased commands

```bash
# Test bat (aliased from cat)
sudo which bat
# Should return: /home/linuxbrew/.linuxbrew/bin/bat

sudo bat --version
# Should work without "command not found"

# Test eza (aliased from ls)
sudo which eza
# Should return: /home/linuxbrew/.linuxbrew/bin/eza

sudo eza --version
# Should work without "command not found"
```

### 6. Full verification using Makefile

The dotfiles include a verification target:

```bash
cd ~/dotfiles
make verify-auth
# Checks all authentication components including system configuration
```

## Troubleshooting

### Issue: "sudo: unable to resolve host"

**Symptom:**
```
sudo: unable to resolve host <hostname>: Name or service not known
```

**Solution:**
This is unrelated to the homebrew-path configuration. Add your hostname to `/etc/hosts`:

```bash
echo "127.0.1.1 $(hostname)" | sudo tee -a /etc/hosts
```

### Issue: "visudo: syntax error" after installation

**Symptom:**
```
sudo visudo -c
>>> /etc/sudoers.d/homebrew-path: syntax error near line X <<<
```

**Solution:**
1. Remove the broken file immediately:
   ```bash
   sudo rm /etc/sudoers.d/homebrew-path
   ```

2. Check the source file for issues:
   ```bash
   cat ~/dotfiles/system/.config/sudoers.d/homebrew-path
   ```

3. Reinstall with correct content:
   ```bash
   cd ~/dotfiles
   make install-system
   ```

### Issue: Homebrew commands still not found with sudo

**Symptom:**
```bash
sudo bat --version
sudo: bat: command not found
```

**Diagnosis:**
```bash
# Check if file exists
ls -la /etc/sudoers.d/homebrew-path

# Check PATH with sudo
sudo env | grep PATH

# Check if Homebrew is in the PATH
echo $PATH | grep linuxbrew
```

**Solution 1:** File not installed
```bash
cd ~/dotfiles
make install-system
```

**Solution 2:** Wrong permissions
```bash
sudo chmod 0440 /etc/sudoers.d/homebrew-path
sudo visudo -c
```

**Solution 3:** Homebrew not in user PATH
```bash
# Add to ~/.bashrc if missing
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
source ~/.bashrc
```

### Issue: "Permission denied" when running make install-system

**Symptom:**
```bash
make install-system
Permission denied
```

**Solution:**
The Makefile target requires sudo privileges. Enter your password when prompted:

```bash
make install-system
# Enter password when prompted
```

Or run with sudo explicitly:
```bash
sudo make install-system
```

### Issue: Locked out of sudo after installation

**Symptom:**
```bash
sudo ls
sudo: /etc/sudoers.d/homebrew-path is mode 0644, should be 0440
sudo: no valid sudoers sources found, quitting
```

**Solution:**
Boot into recovery mode and fix permissions:

1. Reboot and select "Advanced options" > "Recovery mode"
2. Select "root" (drop to root shell prompt)
3. Remount filesystem as writable:
   ```bash
   mount -o remount,rw /
   ```
4. Fix permissions:
   ```bash
   chmod 0440 /etc/sudoers.d/homebrew-path
   visudo -c
   ```
5. Reboot:
   ```bash
   reboot
   ```

**Prevention:**
Always use the Makefile target (`make install-system`) which sets correct permissions automatically.

## Uninstallation

To remove the sudoers configuration:

### Option 1: Using sudo rm (Recommended)

```bash
sudo rm /etc/sudoers.d/homebrew-path
sudo visudo -c  # Verify configuration is still valid
```

### Option 2: Using visudo (Safest)

```bash
sudo visudo -f /etc/sudoers.d/homebrew-path
# Delete all lines, save, and exit
sudo visudo -c  # Verify
```

### Verification after removal

```bash
# Should NOT include Homebrew paths
sudo env | grep PATH

# Should show "command not found"
sudo bat --version
sudo eza --version
```

### After uninstallation

Aliased commands will no longer work with sudo:

```bash
# These will fail after uninstallation:
sudo cat file.txt    # Won't use bat
sudo ls              # Won't use eza

# But will work without sudo:
cat file.txt         # Uses bat
ls                   # Uses eza
```

To restore functionality, reinstall:
```bash
cd ~/dotfiles
make install-system
```

## Quick Reference

| Command | Purpose |
|---------|---------|
| `make install-system` | Install sudoers configuration |
| `sudo visudo -c` | Validate sudoers syntax |
| `sudo env \| grep PATH` | Check PATH with sudo |
| `sudo which <tool>` | Check if tool is found by sudo |
| `ls -la /etc/sudoers.d/` | List all sudoers drop-in files |
| `sudo rm /etc/sudoers.d/homebrew-path` | Uninstall configuration |

## Related Documentation

- **Main README:** `~/dotfiles/README.md` - Overview of dotfiles
- **Installation Guide:** `~/dotfiles/INSTALLATION.md` - Step 5: Install System Configurations
- **Makefile:** `~/dotfiles/Makefile` - See `install-system` target
- **Sudoers Manual:** `man sudoers` - Full sudoers documentation
