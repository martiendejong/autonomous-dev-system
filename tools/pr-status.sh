#!/bin/bash
# pr-status.sh - Show status of all open PRs across repos
# Usage: ./pr-status.sh [repo-name]
# Example: ./pr-status.sh client-manager

REPO="$1"

echo "=== BULK PR STATUS CHECKER ==="
echo ""

if [ -n "$REPO" ]; then
  REPOS=("$REPO")
else
  REPOS=("client-manager" "hazina")
fi

TOTAL_PRS=0

for repo in "${REPOS[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $repo"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  cd "/c/Projects/$repo" || continue

  # Get all open PRs
  prs=$(gh pr list --json number,title,state,statusCheckRollup,mergeable,headRefName 2>/dev/null)

  if [ -z "$prs" ] || [ "$prs" = "[]" ]; then
    echo "  ✅ No open PRs"
    echo ""
    continue
  fi

  # Parse and display each PR
  echo "$prs" | jq -r '.[] |
    "  #\(.number): \(.title)\n" +
    "  Branch: \(.headRefName)\n" +
    "  CI Status: \(.statusCheckRollup[0].state // "PENDING")\n" +
    "  Mergeable: \(if .mergeable == "MERGEABLE" then "✅ Ready" elif .mergeable == "CONFLICTING" then "⚠️ Conflicts" else "⏳ Unknown" end)\n" +
    "  ────────────────────────────────────────"'

  pr_count=$(echo "$prs" | jq '. | length')
  TOTAL_PRS=$((TOTAL_PRS + pr_count))

  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary: $TOTAL_PRS open PRs across all repos"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
