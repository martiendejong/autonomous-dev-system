#!/bin/bash
# Release all worktrees - commits changes and switches to resting branch
# Usage: worktree-release-all.sh [--dry-run] [--auto] [--no-push] [--seat agent-XXX]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ARGS=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n)
            ARGS="$ARGS -DryRun"
            shift
            ;;
        --auto|-a)
            ARGS="$ARGS -AutoCommit"
            shift
            ;;
        --no-push)
            ARGS="$ARGS -SkipPush"
            shift
            ;;
        --seat|-s)
            ARGS="$ARGS -Seats \"$2\""
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: worktree-release-all.sh [--dry-run] [--auto] [--no-push] [--seat agent-XXX]"
            exit 1
            ;;
    esac
done

eval powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/worktree-release-all.ps1" $ARGS
