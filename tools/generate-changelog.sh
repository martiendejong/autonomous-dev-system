#!/bin/bash
# generate-changelog.sh - Generate changelog from merged PRs
# Usage: ./generate-changelog.sh [--since-tag <tag>] [repo-name]

SINCE_TAG=""
REPO=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --since-tag)
      SINCE_TAG="$2"
      shift 2
      ;;
    *)
      REPO=$1
      shift
      ;;
  esac
done

if [ -n "$REPO" ]; then
  REPOS=("$REPO")
else
  REPOS=("client-manager" "hazina")
fi

echo "=== CHANGELOG GENERATOR ==="
echo ""

OUTPUT_FILE="/c/scripts/logs/CHANGELOG-$(date +%Y%m%d-%H%M%S).md"

cat > "$OUTPUT_FILE" << 'HEADER'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

HEADER

echo "## [Unreleased]" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

for repo in "${REPOS[@]}"; do
  repo_path="/c/Projects/$repo"

  if [ ! -d "$repo_path" ]; then
    continue
  fi

  cd "$repo_path"

  echo "━━━ Processing $repo ━━━"

  # Determine range
  if [ -n "$SINCE_TAG" ]; then
    RANGE="$SINCE_TAG..HEAD"
    echo "  Range: Since tag $SINCE_TAG"
  else
    # Find last tag
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -n "$last_tag" ]; then
      RANGE="$last_tag..HEAD"
      echo "  Range: Since last tag $last_tag"
    else
      # No tags, use all merged PRs in last 30 days
      RANGE="--since='30 days ago'"
      echo "  Range: Last 30 days (no tags found)"
    fi
  fi

  echo "  Fetching merged PRs..."

  # Get merged PRs
  prs=$(gh pr list --state merged --limit 100 --json number,title,mergedAt,labels 2>/dev/null)

  if [ -z "$prs" ] || [ "$prs" = "[]" ]; then
    echo "  ℹ️  No merged PRs found"
    echo ""
    continue
  fi

  # Categorize PRs
  added=()
  changed=()
  fixed=()
  deprecated=()
  removed=()
  security=()
  docs=()
  tests=()
  chore=()
  dependencies=()

  echo "$prs" | jq -r '.[] | "\(.number)|\(.title)"' | while IFS='|' read -r num title; do
    # Categorize by conventional commit prefix or labels
    if echo "$title" | grep -qiE "^feat[:(]"; then
      added+=("- $title (#$num)")
    elif echo "$title" | grep -qiE "^fix[:(]"; then
      fixed+=("- $title (#$num)")
    elif echo "$title" | grep -qiE "^chore[:(]"; then
      chore+=("- $title (#$num)")
    elif echo "$title" | grep -qiE "^docs[:(]"; then
      docs+=("- $title (#$num)")
    elif echo "$title" | grep -qiE "^test[:(]"; then
      tests+=("- $title (#$num)")
    elif echo "$title" | grep -qiE "^refactor[:(]"; then
      changed+=("- $title (#$num)")
    elif echo "$title" | grep -qiE "^perf[:(]"; then
      changed+=("- $title (#$num)")
    elif echo "$title" | grep -qiE "^security[:(]"; then
      security+=("- $title (#$num)")
    elif echo "$title" | grep -qiE "^deps[:(]|dependency"; then
      dependencies+=("- $title (#$num)")
    else
      # Try to categorize by keywords in title
      if echo "$title" | grep -qiE "add|new|implement"; then
        added+=("- $title (#$num)")
      elif echo "$title" | grep -qiE "fix|bug|issue"; then
        fixed+=("- $title (#$num)")
      elif echo "$title" | grep -qiE "update|change|refactor"; then
        changed+=("- $title (#$num)")
      else
        chore+=("- $title (#$num)")
      fi
    fi
  done

  # Write to changelog
  echo "" >> "$OUTPUT_FILE"
  echo "### $repo" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  if [ ${#added[@]} -gt 0 ]; then
    echo "#### Added" >> "$OUTPUT_FILE"
    printf '%s\n' "${added[@]}" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi

  if [ ${#changed[@]} -gt 0 ]; then
    echo "#### Changed" >> "$OUTPUT_FILE"
    printf '%s\n' "${changed[@]}" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi

  if [ ${#fixed[@]} -gt 0 ]; then
    echo "#### Fixed" >> "$OUTPUT_FILE"
    printf '%s\n' "${fixed[@]}" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi

  if [ ${#security[@]} -gt 0 ]; then
    echo "#### Security" >> "$OUTPUT_FILE"
    printf '%s\n' "${security[@]}" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi

  if [ ${#deprecated[@]} -gt 0 ]; then
    echo "#### Deprecated" >> "$OUTPUT_FILE"
    printf '%s\n' "${deprecated[@]}" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi

  if [ ${#removed[@]} -gt 0 ]; then
    echo "#### Removed" >> "$OUTPUT_FILE"
    printf '%s\n' "${removed[@]}" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi

  pr_count=$(echo "$prs" | jq '. | length')
  echo "  ✅ Processed $pr_count PRs"
  echo ""
done

# Add footer
cat >> "$OUTPUT_FILE" << 'FOOTER'

---

## Release Notes

To create a new release:

1. Update version numbers in package.json / .csproj files
2. Create git tag: `git tag -a v1.0.0 -m "Release v1.0.0"`
3. Push tag: `git push origin v1.0.0`
4. Create GitHub release from tag

FOOTER

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Changelog generated!"
echo ""
echo "📄 Output: $OUTPUT_FILE"
echo ""
echo "💡 Review and edit before committing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Display preview
echo ""
echo "Preview:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
head -50 "$OUTPUT_FILE"
echo "..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
