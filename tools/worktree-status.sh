#!/bin/bash
# Quick worktree status overview
# Usage: worktree-status.sh [-c|--compact]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$1" == "-c" || "$1" == "--compact" ]]; then
    powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/worktree-status.ps1" -Compact
else
    powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/worktree-status.ps1"
fi
