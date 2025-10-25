#!/usr/bin/env bash
# ~/.bash/functions/system.bash
# System information and network functions
#
# Purpose:
#   Quick access to system stats and network information.
#   Useful for monitoring and troubleshooting.
#
# Functions:
#   diskusage - Show disk space usage
#   memusage  - Show memory usage and top consumers
#   cpuusage  - Show CPU usage
#   localip   - Get local IP address
#   publicip  - Get public IP address
#   testnet   - Test internet connectivity

# Show disk usage in human-readable form
# Filters out tmpfs, udev, and loop devices for clarity
# Usage: diskusage
diskusage() {
    df -h | grep -v "tmpfs\|udev\|loop"
}

# Show memory usage
# Displays free/used memory and top 10 memory-consuming processes
# Usage: memusage
memusage() {
    free -h
    echo ""
    echo "Top 10 memory-consuming processes:"
    ps aux --sort=-%mem | head -n 11
}

# Show CPU usage
# Displays current CPU usage via top
# Usage: cpuusage
cpuusage() {
    top -b -n 1 | head -n 20
}

# Get local IP address
# Returns the primary local IP address (first non-loopback)
# Usage: localip
localip() {
    hostname -I | awk '{print $1}'
}

# Get public IP address
# Queries external service to get your public-facing IP
# Usage: publicip
publicip() {
    curl -s https://api.ipify.org && echo
}

# Test internet connection
# Pings Google DNS to check connectivity
# Usage: testnet
testnet() {
    if ping -c 1 google.com &>/dev/null; then
        echo "✓ Internet connection is working"
    else
        echo "✗ No internet connection"
    fi
}
