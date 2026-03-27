#!/bin/bash
# Verify all base repos are on develop branch
# Usage: check-base-repos.sh

echo "=== Base Repo Health Check ==="
echo ""

all_good=true

for repo in client-manager hazina artrevisionist; do
  repo_path="C:/Projects/$repo"

  if [ ! -d "$repo_path" ]; then
    echo "⚠️  $repo - Directory not found"
    continue
  fi

  branch=$(git -C "$repo_path" branch --show-current)

  if [ "$branch" != "develop" ]; then
    echo "❌ $repo on '$branch' (should be develop)"
    all_good=false

    # Check for uncommitted changes
    if [ -n "$(git -C "$repo_path" status --porcelain)" ]; then
      echo "   ⚠️  Has uncommitted changes - cannot auto-fix"
    else
      echo "   ✅ No uncommitted changes - safe to fix"
      echo "   Fix: git -C $repo_path checkout develop && git -C $repo_path pull origin develop"
    fi
  else
    echo "✅ $repo on develop"
  fi
done

echo ""

if [ "$all_good" = true ]; then
  echo "✅ All base repos are healthy"
  exit 0
else
  echo "❌ Fix required: Restore affected repos to develop branch"
  echo ""
  echo "Auto-fix command (for clean repos only):"
  echo "  for repo in client-manager hazina artrevisionist; do"
  echo "    git -C C:/Projects/\$repo checkout develop"
  echo "    git -C C:/Projects/\$repo pull origin develop"
  echo "  done"
  exit 1
fi
