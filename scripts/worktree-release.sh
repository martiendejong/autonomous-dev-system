#!/usr/bin/env bash
#
# Worktree Release Script - Complete Work and Create PR
#
# Usage: worktree-release.sh <agent-seat> <pr-title>
#
# This script commits work, merges latest develop, creates PR,
# cleans worktrees, and marks agent FREE.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Arguments
AGENT_SEAT="$1"
PR_TITLE="$2"

if [ -z "$AGENT_SEAT" ]; then
    echo -e "${RED}Error: Agent seat required${NC}"
    echo "Usage: worktree-release.sh <agent-seat> <pr-title>"
    exit 1
fi

if [ -z "$PR_TITLE" ]; then
    echo -e "${RED}Error: PR title required${NC}"
    echo "Usage: worktree-release.sh <agent-seat> <pr-title>"
    exit 1
fi

# Load configuration
CONFIG_PATH="${AUTONOMOUS_DEV_CONFIG:-$HOME/.autonomous-dev/config.json}"

if [ ! -f "$CONFIG_PATH" ]; then
    echo -e "${RED}Error: Configuration not found at $CONFIG_PATH${NC}"
    echo "Run setup.sh first to configure the plugin."
    exit 1
fi

# Parse config
CONTROL_PLANE=$(node -p "require('$CONFIG_PATH').controlPlane")
WORKTREE_PATH=$(node -p "require('$CONFIG_PATH').worktreePath")
REPOS_JSON=$(node -p "JSON.stringify(require('$CONFIG_PATH').repos)")

POOL_FILE="$CONTROL_PLANE/_machine/worktrees.pool.md"
ACTIVITY_FILE="$CONTROL_PLANE/_machine/worktrees.activity.md"

# Verify agent exists and is BUSY
AGENT_STATUS=$(grep "| $AGENT_SEAT |" "$POOL_FILE" | awk -F'|' '{print $5}' | tr -d ' ')

if [ -z "$AGENT_STATUS" ]; then
    echo -e "${RED}Error: Agent $AGENT_SEAT not found in pool${NC}"
    exit 1
fi

if [ "$AGENT_STATUS" != "BUSY" ]; then
    echo -e "${RED}Error: Agent $AGENT_SEAT is not BUSY (current status: $AGENT_STATUS)${NC}"
    echo "Only BUSY agents can be released."
    exit 1
fi

AGENT_DIR="$WORKTREE_PATH/$AGENT_SEAT"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}RELEASING WORKTREE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Agent: $AGENT_SEAT"
echo "PR Title: $PR_TITLE"
echo ""

# Parse repos
REPO_COUNT=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0)).length")

# Get branch name from first repo worktree
FIRST_REPO=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[0].name")
FIRST_WORKTREE="$AGENT_DIR/$FIRST_REPO"

if [ ! -d "$FIRST_WORKTREE" ]; then
    echo -e "${RED}Error: Worktree not found at $FIRST_WORKTREE${NC}"
    exit 1
fi

cd "$FIRST_WORKTREE"
BRANCH_NAME=$(git branch --show-current)

echo "Branch: $BRANCH_NAME"
echo ""

# Process each repo
PR_URLS=()

for i in $(seq 0 $((REPO_COUNT - 1))); do
    REPO_NAME=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].name")
    REPO_PATH=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].path")
    BASE_BRANCH=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].baseBranch || 'develop'")

    WORKTREE_DIR="$AGENT_DIR/$REPO_NAME"

    if [ ! -d "$WORKTREE_DIR" ]; then
        echo -e "${YELLOW}⚠️  Skipping $REPO_NAME (worktree not found)${NC}"
        continue
    fi

    echo -e "${BLUE}Processing: $REPO_NAME${NC}"
    cd "$WORKTREE_DIR"

    # Check if there are any changes
    if [ -z "$(git status --porcelain)" ]; then
        echo "  No changes to commit"
    else
        # Stage all changes
        echo "  Staging changes..."
        git add -A

        # Commit with co-author
        echo "  Committing..."
        git commit -m "$(cat <<EOF
$PR_TITLE

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
    fi

    # Merge latest develop (Pattern 52)
    echo "  Merging latest $BASE_BRANCH..."
    git fetch origin

    if git merge origin/$BASE_BRANCH --no-edit; then
        echo -e "  ${GREEN}✓ Merged $BASE_BRANCH successfully${NC}"
    else
        echo -e "${RED}Error: Merge conflict with $BASE_BRANCH!${NC}"
        echo ""
        echo "Please resolve conflicts manually in $WORKTREE_DIR"
        echo "Then run this script again."
        exit 1
    fi

    # Push to remote
    echo "  Pushing to remote..."
    git push -u origin "$BRANCH_NAME"

    echo -e "  ${GREEN}✓ Pushed to origin/$BRANCH_NAME${NC}"

    # Create PR with --base flag (Pattern 56)
    echo "  Creating pull request..."

    PR_BODY="$(cat <<EOF
## Summary

$PR_TITLE

## Changes Made

[Auto-generated PR from worktree release]

---

**Created by**: Claude Code Autonomous Development System
**Agent**: $AGENT_SEAT
**Branch**: $BRANCH_NAME
**Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"

    PR_URL=$(gh pr create --base "$BASE_BRANCH" --title "$PR_TITLE" --body "$PR_BODY" 2>&1)

    if [[ $PR_URL == *"http"* ]]; then
        echo -e "  ${GREEN}✓ PR created: $PR_URL${NC}"
        PR_URLS+=("$PR_URL")

        # Verify base branch (Pattern 56)
        PR_NUMBER=$(echo "$PR_URL" | grep -oP '\d+$')
        ACTUAL_BASE=$(gh pr view "$PR_NUMBER" --json baseRefName -q '.baseRefName')

        if [ "$ACTUAL_BASE" != "$BASE_BRANCH" ]; then
            echo -e "  ${YELLOW}⚠️  Warning: PR base is '$ACTUAL_BASE', expected '$BASE_BRANCH'${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️  PR creation output: $PR_URL${NC}"
    fi

    # Return to worktree root
    cd "$AGENT_DIR"

    echo ""
done

# Clean worktrees
echo "Cleaning worktrees..."
for i in $(seq 0 $((REPO_COUNT - 1))); do
    REPO_NAME=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].name")
    REPO_PATH=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].path")

    WORKTREE_DIR="$AGENT_DIR/$REPO_NAME"

    if [ -d "$WORKTREE_DIR" ]; then
        # Remove worktree
        cd "$REPO_PATH"
        git worktree remove "$WORKTREE_DIR" --force 2>/dev/null || rm -rf "$WORKTREE_DIR"
        echo "  ✓ Removed worktree for $REPO_NAME"
    fi
done

# Update base repos to latest develop
echo ""
echo "Updating base repositories..."
for i in $(seq 0 $((REPO_COUNT - 1))); do
    REPO_NAME=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].name")
    REPO_PATH=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].path")
    BASE_BRANCH=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].baseBranch || 'develop'")

    cd "$REPO_PATH"

    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]; then
        echo "  Switching $REPO_NAME from $CURRENT_BRANCH to $BASE_BRANCH"
        git checkout "$BASE_BRANCH"
    fi

    echo "  Pulling latest $BASE_BRANCH for $REPO_NAME..."
    git pull origin "$BASE_BRANCH"

    # Prune stale worktree references
    git worktree prune

    echo -e "  ${GREEN}✓ $REPO_NAME updated${NC}"
done

# Update pool file (mark as FREE)
echo ""
echo "Updating agent pool..."

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Use awk to update the agent's row
awk -v agent="$AGENT_SEAT" -v ts="$TIMESTAMP" '
BEGIN { FS="|"; OFS="|" }
$2 ~ agent && $5 ~ "BUSY" {
    $3 = " "
    $5 = " FREE "
    $6 = " "
    $7 = " "
    $8 = " " ts " "
    $9 = " Released "
}
{ print }
' "$POOL_FILE" > "$POOL_FILE.tmp"

mv "$POOL_FILE.tmp" "$POOL_FILE"

echo -e "${GREEN}✓ Agent pool updated${NC}"

# Log release
echo "$TIMESTAMP — release — $AGENT_SEAT — $FIRST_REPO — $BRANCH_NAME — — claude-code — $PR_TITLE" >> "$ACTIVITY_FILE"

echo -e "${GREEN}✓ Activity logged${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ WORKTREE RELEASED SUCCESSFULLY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Agent: $AGENT_SEAT (now FREE)"
echo "Branch: $BRANCH_NAME"
echo ""

if [ ${#PR_URLS[@]} -gt 0 ]; then
    echo "Pull Requests Created:"
    for url in "${PR_URLS[@]}"; do
        echo "  • $url"
    done
    echo ""
fi

echo -e "${GREEN}Ready for next task! 🚀${NC}"
echo ""
