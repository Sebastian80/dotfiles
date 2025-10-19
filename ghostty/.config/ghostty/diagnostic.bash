#!/bin/bash
# Ghostty Diagnostic Script
# This will be run as the shell in Ghostty to diagnose issues

LOGFILE="/tmp/ghostty-diagnostic-$(date +%s).log"
exec 2>"$LOGFILE"
set -x

echo "=== GHOSTTY DIAGNOSTIC START ===" | tee -a "$LOGFILE"
echo "Timestamp: $(date)" | tee -a "$LOGFILE"
echo ""  | tee -a "$LOGFILE"

echo "=== ENVIRONMENT ===" | tee -a "$LOGFILE"
echo "GHOSTTY_RESOURCES_DIR: ${GHOSTTY_RESOURCES_DIR:-NOT SET}" | tee -a "$LOGFILE"
echo "GHOSTTY_BIN_DIR: ${GHOSTTY_BIN_DIR:-NOT SET}" | tee -a "$LOGFILE"
echo "TERM: $TERM" | tee -a "$LOGFILE"
echo "SHELL: $SHELL" | tee -a "$LOGFILE"
echo "PATH (first 5 entries): $(echo $PATH | tr ':' '\n' | head -5 | tr '\n' ':')" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

echo "=== OH-MY-POSH ===" | tee -a "$LOGFILE"
echo "oh-my-posh location: $(which oh-my-posh 2>&1)" | tee -a "$LOGFILE"
if command -v oh-my-posh &>/dev/null; then
    echo "oh-my-posh version: $(oh-my-posh --version 2>&1)" | tee -a "$LOGFILE"
else
    echo "oh-my-posh NOT FOUND in PATH" | tee -a "$LOGFILE"
fi
echo "" | tee -a "$LOGFILE"

echo "=== BASHRC LOADING ===" | tee -a "$LOGFILE"
echo "Loading ~/.bashrc..." | tee -a "$LOGFILE"
source ~/.bashrc 2>&1 | tee -a "$LOGFILE"
echo "Bashrc loaded" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

echo "=== AFTER BASHRC ===" | tee -a "$LOGFILE"
echo "_omp_ftcs_marks: ${_omp_ftcs_marks:-NOT SET}" | tee -a "$LOGFILE"
echo "PS1 length: ${#PS1}" | tee -a "$LOGFILE"
echo "PS1 (first 200 chars): ${PS1:0:200}" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

echo "=== PROMPT TEST ===" | tee -a "$LOGFILE"
echo "Attempting to render prompt..." | tee -a "$LOGFILE"
eval "$PS1" 2>&1 | cat -v | head -10 | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

echo "=== DIAGNOSTIC COMPLETE ===" | tee -a "$LOGFILE"
echo "Log saved to: $LOGFILE" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"
echo "Press Enter to start normal bash, or Ctrl+C to exit and view log"
read

# Start normal interactive bash
exec bash -i
