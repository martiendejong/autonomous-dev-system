#!/bin/bash
# check-worktree-health.sh - Validate worktree pool health
# Usage: ./check-worktree-health.sh [--fix]

set -e

FIX_MODE=false

if [ "$1" = "--fix" ]; then
  FIX_MODE=true
  echo "⚠️  FIX MODE ENABLED - Will suggest release commands"
  echo ""
fi

echo "=== WORKTREE HEALTH CHECK ==="
echo ""

pool_file="/c/scripts/_machine/worktrees.pool.md"

if [ ! -f "$pool_file" ]; then
  echo "❌ Pool file not found: $pool_file"
  exit 1
fi

STALE_COUNT=0
HEALTHY_COUNT=0
ISSUES_FOUND=()

# Check each BUSY agent
grep "| BUSY |" "$pool_file" | while IFS='|' read -r _ seat _ _ worktree_root _ repo branch timestamp notes; do
  seat=$(echo "$seat" | xargs)
  repo=$(echo "$repo" | xargs)
  branch=$(echo "$branch" | xargs)
  timestamp=$(echo "$timestamp" | xargs)

  echo "━━━ Checking $seat ━━━"
  echo "  Repo: $repo"
  echo "  Branch: $branch"
  echo "  Last activity: $timestamp"

  STALE=false
  ISSUES=""

  # Check 1: Does agent directory exist?
  if [ ! -d "/c/Projects/worker-agents/$seat" ]; then
    echo "  ❌ Directory missing: /c/Projects/worker-agents/$seat"
    STALE=true
    ISSUES="$ISSUES\n  - Directory missing"
  else
    echo "  ✅ Directory exists"
  fi

  # Check 2: Does git repo exist in worktree?
  for r in $(echo $repo | tr '+' ' '); do
    if [ ! -d "/c/Projects/worker-agents/$seat/$r/.git" ]; then
      echo "  ❌ Git repo missing: $r"
      STALE=true
      ISSUES="$ISSUES\n  - Git repo $r missing"
    else
      echo "  ✅ Git repo exists: $r"

      # Check 3: Get last commit time
      cd "/c/Projects/worker-agents/$seat/$r"
      last_commit=$(git log -1 --format="%ci" 2>/dev/null || echo "unknown")
      echo "  📅 Last commit: $last_commit"
    fi
  done

  # Check 4: Is PR merged?
  for r in $(echo $repo | tr '+' ' '); do
    if [ -d "/c/Projects/$r" ]; then
      cd "/c/Projects/$r"
      pr_state=$(gh pr list --head "$branch" --json state --jq '.[0].state' 2>/dev/null || echo "")

      if [ "$pr_state" = "MERGED" ]; then
        echo "  ❌ PR MERGED - Agent should be released!"
        STALE=true
        ISSUES="$ISSUES\n  - PR merged but agent still BUSY"
      elif [ -n "$pr_state" ]; then
        echo "  ✅ PR status: $pr_state"
      else
        echo "  ℹ️  No PR found"
      fi
    fi
  done

  # Check 5: Empty worktree?
  file_count=$(find "/c/Projects/worker-agents/$seat" -type f 2>/dev/null | wc -l)
  if [ "$file_count" -eq 0 ]; then
    echo "  ⚠️  Worktree is empty!"
    STALE=true
    ISSUES="$ISSUES\n  - Empty worktree"
  else
    echo "  ✅ Worktree has $file_count files"
  fi

  echo ""

  if [ "$STALE" = true ]; then
    STALE_COUNT=$((STALE_COUNT + 1))
    ISSUES_FOUND+=("$seat:$ISSUES")

    if [ "$FIX_MODE" = true ]; then
      echo "  🔧 SUGGESTED FIX:"
      echo "     cd /c/Projects/$r && git worktree remove /c/Projects/worker-agents/$seat/$r --force"
      echo "     # Then update pool file to mark $seat as FREE"
      echo ""
    fi
  else
    HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
    echo "  ✅ $seat is HEALTHY"
    echo ""
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Healthy agents: $HEALTHY_COUNT"
echo "❌ Stale agents: $STALE_COUNT"

if [ $STALE_COUNT -gt 0 ]; then
  echo ""
  echo "⚠️  STALE AGENTS DETECTED:"
  for issue in "${ISSUES_FOUND[@]}"; do
    agent=$(echo "$issue" | cut -d: -f1)
    problems=$(echo "$issue" | cut -d: -f2-)
    echo ""
    echo "  $agent:"
    echo -e "$problems"
  done

  if [ "$FIX_MODE" = false ]; then
    echo ""
    echo "💡 Run with --fix to see suggested release commands"
  fi

  exit 1
else
  echo ""
  echo "🎉 All BUSY agents are healthy!"
  exit 0
fi
