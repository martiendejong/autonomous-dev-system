#!/bin/bash
# Complete worktree release with full verification
# Usage: complete-release.sh agent-XXX

AGENT=$1

if [ -z "$AGENT" ]; then
  echo "Usage: complete-release.sh agent-XXX"
  exit 1
fi

echo "=== Completing release for $AGENT ==="

# Step 1: Clean directory
echo "Step 1: Cleaning worktree directory..."
rm -rf "C:/Projects/worker-agents/$AGENT"/*
if [ $? -eq 0 ]; then
  echo "✅ Directory cleaned"
else
  echo "❌ Failed to clean directory"
  exit 1
fi

# Step 2: Prune all repos
echo ""
echo "Step 2: Pruning git worktree references..."
for repo in client-manager hazina artrevisionist; do
  if [ -d "C:/Projects/$repo" ]; then
    echo "  Pruning $repo..."
    git -C "C:/Projects/$repo" worktree prune -v
  fi
done
echo "✅ Git references pruned"

# Step 3: Verify empty
echo ""
echo "Step 3: Verification..."
if [ -z "$(ls -A "C:/Projects/worker-agents/$AGENT/")" ]; then
  echo "✅ Directory is empty"
else
  echo "⚠️  WARNING: Directory not empty after cleanup"
  ls -la "C:/Projects/worker-agents/$AGENT/"
  exit 1
fi

# Step 4: Check pool status
echo ""
echo "Step 4: Checking pool status..."
pool_status=$(grep "| $AGENT |" C:/scripts/_machine/worktrees.pool.md | cut -d'|' -f5 | tr -d ' ')
echo "  Pool status: $pool_status"

if [ "$pool_status" != "FREE" ]; then
  echo "⚠️  WARNING: Pool status is not FREE (found: $pool_status)"
  echo "  Manual update required in worktrees.pool.md"
fi

echo ""
echo "✅ Release complete for $AGENT"
echo ""
echo "Next steps:"
echo "1. Update worktrees.pool.md timestamp (if not already updated)"
echo "2. Log release in worktrees.activity.md"
echo "3. Commit tracking files to scripts repo"
