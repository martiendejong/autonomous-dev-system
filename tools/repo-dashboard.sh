#!/bin/bash
# repo-dashboard.sh - Multi-repo status dashboard
# Usage: ./repo-dashboard.sh

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         MULTI-REPO STATUS DASHBOARD                           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

REPOS=("your-project" "hazina")

for repo in "${REPOS[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📁 $repo"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  cd "/c/Projects/$repo" || continue

  # Current branch
  branch=$(git branch --show-current)
  echo "🌿 Branch: $branch"

  # Status info
  status_output=$(git status -sb | head -1)
  echo "📍 Status: $status_output"

  # Uncommitted changes
  modified=$(git status --short | grep "^ M" | wc -l)
  added=$(git status --short | grep "^A" | wc -l)
  deleted=$(git status --short | grep "^D" | wc -l)
  untracked=$(git status --short | grep "^??" | wc -l)

  if [ $modified -gt 0 ] || [ $added -gt 0 ] || [ $deleted -gt 0 ] || [ $untracked -gt 0 ]; then
    echo "📝 Changes: $modified modified, $added added, $deleted deleted, $untracked untracked"
  else
    echo "✅ Working tree clean"
  fi

  # Open PRs
  echo ""
  echo "🔀 Open PRs:"

  if command -v jq &> /dev/null; then
    pr_summary=$(gh pr list --limit 5 --json number,title,statusCheckRollup 2>/dev/null | \
      jq -r '.[] | "   #\(.number): \(.title) [\(.statusCheckRollup[0].state // "PENDING")]"')

    if [ -z "$pr_summary" ]; then
      echo "   (none)"
    else
      echo "$pr_summary"
    fi
  else
    # Fallback without jq
    pr_count=$(gh pr list --limit 5 2>/dev/null | wc -l)
    if [ $pr_count -gt 0 ]; then
      gh pr list --limit 5 2>/dev/null | sed 's/^/   /'
    else
      echo "   (none)"
    fi
  fi

  # Last 3 commits
  echo ""
  echo "📜 Recent commits:"
  git log --oneline -3 | sed 's/^/   /'

  echo ""
done

# Agent pool status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🤖 Agent Pool Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

pool_file="/c/scripts/_machine/worktrees.pool.md"
if [ -f "$pool_file" ]; then
  free_count=$(grep "| FREE |" "$pool_file" | wc -l)
  busy_count=$(grep "| BUSY |" "$pool_file" | wc -l)
  total=$((free_count + busy_count))

  echo "🟢 FREE: $free_count agents"
  echo "🔴 BUSY: $busy_count agents"
  echo "📊 Total: $total agents"

  if [ "$busy_count" -gt 0 ]; then
    echo ""
    echo "Active agents:"
    grep "| BUSY |" "$pool_file" | while IFS='|' read -r _ seat _ _ _ _ repo branch _ notes; do
      seat=$(echo "$seat" | xargs)
      repo=$(echo "$repo" | xargs)
      branch=$(echo "$branch" | xargs)
      notes=$(echo "$notes" | xargs)
      echo "   $seat: $repo/$branch"
    done
  fi
else
  echo "⚠️  Pool file not found"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║ Dashboard complete - $(date +"%Y-%m-%d %H:%M:%S")                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
