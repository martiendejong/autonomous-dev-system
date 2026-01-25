#!/bin/bash
# agent-activity.sh - Show what each agent is doing
# Usage: ./agent-activity.sh

echo "=== AGENT ACTIVITY REPORT ==="
echo ""
echo "Generated: $(date)"
echo ""

pool_file="/c/scripts/_machine/worktrees.pool.md"

if [ ! -f "$pool_file" ]; then
  echo "❌ Pool file not found"
  exit 1
fi

# Count agents
free_count=$(grep -c "| FREE |" "$pool_file" || echo "0")
busy_count=$(grep -c "| BUSY |" "$pool_file" || echo "0")
total=$((free_count + busy_count))

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total agents: $total"
echo "  🟢 FREE: $free_count"
echo "  🔴 BUSY: $busy_count"
echo ""

if [ $busy_count -eq 0 ]; then
  echo "✅ All agents are FREE and ready for work!"
  exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 BUSY Agents ($busy_count)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

INACTIVE_AGENTS=()

grep "| BUSY |" "$pool_file" | while IFS='|' read -r _ seat _ _ _ _ repo branch timestamp notes; do
  seat=$(echo "$seat" | xargs)
  repo=$(echo "$repo" | xargs)
  branch=$(echo "$branch" | xargs)
  timestamp=$(echo "$timestamp" | xargs)
  notes=$(echo "$notes" | xargs)

  echo "┌─────────────────────────────────────────"
  echo "│ $seat"
  echo "├─────────────────────────────────────────"
  echo "│ Repos: $repo"
  echo "│ Branch: $branch"
  echo "│ Allocated: $timestamp"

  # Calculate time since allocation (simplified)
  alloc_time=$(date -d "$timestamp" +%s 2>/dev/null || echo "0")
  current_time=$(date +%s)
  hours_ago=$(( (current_time - alloc_time) / 3600 ))

  if [ $hours_ago -gt 0 ]; then
    echo "│ ⏱️  Time: ${hours_ago}h ago"
  else
    echo "│ ⏱️  Time: < 1h ago"
  fi

  # Check each repo for last commit
  for r in $(echo $repo | tr '+' ' '); do
    if [ -d "/c/Projects/worker-agents/$seat/$r" ]; then
      cd "/c/Projects/worker-agents/$seat/$r"

      # Last commit
      last_commit_msg=$(git log -1 --format="%s" 2>/dev/null || echo "No commits")
      last_commit_time=$(git log -1 --format="%ci" 2>/dev/null || echo "unknown")
      last_commit_ago=$(git log -1 --format="%ar" 2>/dev/null || echo "unknown")

      echo "│"
      echo "│ 📝 Last commit ($r):"
      echo "│    $last_commit_ago - \"$last_commit_msg\""

      # Check if inactive (>2hr since last commit)
      if [ "$last_commit_ago" != "unknown" ]; then
        if echo "$last_commit_ago" | grep -qE "[3-9] hours ago|[1-9][0-9]+ hours ago|days? ago|weeks? ago"; then
          echo "│    ⚠️  WARNING: No commits in >2 hours"
          INACTIVE_AGENTS+=("$seat")
        fi
      fi
    fi
  done

  # Check PR status
  for r in $(echo $repo | tr '+' ' '); do
    if [ -d "/c/Projects/$r" ]; then
      cd "/c/Projects/$r"
      pr_info=$(gh pr list --head "$branch" --json number,state,statusCheckRollup 2>/dev/null | \
        jq -r '.[] | "PR #\(.number): \(.state) - CI: \(.statusCheckRollup[0].state // "PENDING")"')

      if [ -n "$pr_info" ]; then
        echo "│"
        echo "│ 🔀 $pr_info"
      fi
    fi
  done

  # Task description
  if [ -n "$notes" ]; then
    echo "│"
    echo "│ 📋 Task: $notes"
  fi

  echo "└─────────────────────────────────────────"
  echo ""
done

# Show inactive agents summary
if [ ${#INACTIVE_AGENTS[@]} -gt 0 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  INACTIVE AGENTS (>2hr no commits)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  for agent in "${INACTIVE_AGENTS[@]}"; do
    echo "  • $agent - Consider checking on this agent"
  done
  echo ""
  echo "💡 Run: ./check-worktree-health.sh --fix"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🟢 FREE Agents ($free_count available)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $free_count -gt 0 ]; then
  grep "| FREE |" "$pool_file" | while IFS='|' read -r _ seat rest; do
    seat=$(echo "$seat" | xargs)
    echo "  • $seat - Ready for allocation"
  done
  echo ""
fi

echo "✅ Activity report complete"
