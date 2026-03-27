#!/bin/bash
# clean-stale-branches.sh - Delete all merged branches
# Usage: ./clean-stale-branches.sh [--dry-run] [repo-name]
# Example: ./clean-stale-branches.sh --dry-run client-manager

set -e

DRY_RUN=false
REPO=""

# Parse arguments
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      REPO=$arg
      shift
      ;;
  esac
done

# Determine which repos to clean
if [ -n "$REPO" ]; then
  REPOS=("$REPO")
else
  REPOS=("client-manager" "hazina")
fi

echo "=== STALE BRANCH CLEANER ==="
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "🔍 DRY RUN MODE - No branches will be deleted"
  echo ""
fi

for repo in "${REPOS[@]}"; do
  echo "━━━ $repo ━━━"
  cd "/c/Projects/$repo" || continue

  # Get all merged PRs
  merged_branches=$(gh pr list --state merged --limit 100 --json headRefName --jq '.[].headRefName' 2>/dev/null | \
    grep -v "^develop$" | grep -v "^main$" | sort -u)

  if [ -z "$merged_branches" ]; then
    echo "  ✅ No stale branches found"
    echo ""
    continue
  fi

  branch_count=$(echo "$merged_branches" | wc -l)
  echo "  Found $branch_count merged branches to clean:"
  echo ""

  while IFS= read -r branch; do
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY RUN] Would delete: $branch"
    else
      echo "  🗑️  Deleting: $branch"

      # Delete remote branch
      if git push origin --delete "$branch" 2>/dev/null; then
        echo "      ✅ Remote deleted"
      else
        echo "      ⚠️  Remote already deleted or not found"
      fi

      # Delete local branch
      if git branch -D "$branch" 2>/dev/null; then
        echo "      ✅ Local deleted"
      else
        echo "      ℹ️  No local branch"
      fi
    fi
    echo ""
  done <<< "$merged_branches"

  echo ""
done

if [ "$DRY_RUN" = true ]; then
  echo "💡 Run without --dry-run to actually delete branches"
else
  echo "✅ Cleanup complete!"
  echo ""
  echo "📊 Statistics:"
  for repo in "${REPOS[@]}"; do
    cd "/c/Projects/$repo" || continue
    remote_count=$(git branch -r | grep -v "HEAD" | wc -l)
    local_count=$(git branch | wc -l)
    echo "  $repo: $local_count local branches, $remote_count remote branches"
  done
fi
