#!/bin/bash
# check-branch-conflicts.sh
# Checks for multi-agent conflicts before allocating a worktree
# Usage: check-branch-conflicts.sh <repo> <branch>

REPO=$1
BRANCH=$2

if [ -z "$REPO" ] || [ -z "$BRANCH" ]; then
    echo "Usage: check-branch-conflicts.sh <repo> <branch>"
    echo "Example: check-branch-conflicts.sh hazina feature/chunk-set-summaries"
    exit 1
fi

echo "=== Multi-Agent Conflict Detection ==="
echo "Repository: $REPO"
echo "Branch: $BRANCH"
echo ""

EXIT_CODE=0

# Check 1: Git worktrees
echo "1. Checking git worktrees..."
WORKTREE=$(git -C /c/Projects/$REPO worktree list 2>/dev/null | grep "$BRANCH" || true)
if [ -n "$WORKTREE" ]; then
    echo "❌ CONFLICT: Branch has active worktree"
    echo ""
    echo "$WORKTREE"
    echo ""
    EXIT_CODE=1
else
    echo "✅ No worktree found"
fi

echo ""

# Check 2: instances.map.md
echo "2. Checking instances.map.md..."
INSTANCE=$(grep "$BRANCH" /c/scripts/_machine/instances.map.md 2>/dev/null || true)
if [ -n "$INSTANCE" ]; then
    echo "❌ CONFLICT: Branch in instances map"
    echo ""
    echo "$INSTANCE"
    echo ""
    EXIT_CODE=1
else
    echo "✅ No instance found"
fi

echo ""

# Check 3: Pool status
echo "3. Checking pool for branch mentions..."
POOL=$(grep "$BRANCH" /c/scripts/_machine/worktrees.pool.md 2>/dev/null || true)
if [ -n "$POOL" ]; then
    echo "ℹ️  Branch found in pool:"
    echo ""
    echo "$POOL"
    echo ""
    # Check if it's marked BUSY
    if echo "$POOL" | grep -q "BUSY"; then
        echo "⚠️  Pool shows BUSY status"
        EXIT_CODE=1
    fi
else
    echo "✅ No pool entry"
fi

echo ""

# Check 4: Recent activity
echo "4. Checking recent activity log..."
RECENT_ACTIVITY=$(tail -50 /c/scripts/_machine/worktrees.activity.md 2>/dev/null | grep "$BRANCH" | tail -5 || true)
if [ -n "$RECENT_ACTIVITY" ]; then
    echo "ℹ️  Recent activity for this branch:"
    echo ""
    echo "$RECENT_ACTIVITY"
    echo ""
else
    echo "✅ No recent activity"
fi

echo ""
echo "=== CONFLICT CHECK COMPLETE ==="
echo ""

if [ "$EXIT_CODE" -eq 1 ]; then
    echo "🚨 CONFLICTS DETECTED 🚨"
    echo ""
    echo "There is already another agent working in this branch."
    echo ""
    echo "I will NOT proceed with allocation to avoid conflicts."
    echo ""
    echo "Recommended actions:"
    echo "1. Choose a different branch name"
    echo "2. Wait for the other agent to complete and release"
    echo "3. Check with user if one of the agents should take over"
    echo ""
    exit 1
else
    echo "✅ No conflicts detected - safe to allocate"
    echo ""
    exit 0
fi
