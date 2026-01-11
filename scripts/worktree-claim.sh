#!/usr/bin/env bash
#
# Worktree Claim Script - Atomic Worktree Allocation
#
# Usage: worktree-claim.sh <branch-name> <description>
#
# This script atomically allocates a FREE agent from the pool,
# creates worktrees for all configured repos, and logs the allocation.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Arguments
BRANCH_NAME="$1"
DESCRIPTION="$2"

if [ -z "$BRANCH_NAME" ]; then
    echo -e "${RED}Error: Branch name required${NC}"
    echo "Usage: worktree-claim.sh <branch-name> <description>"
    exit 1
fi

if [ -z "$DESCRIPTION" ]; then
    echo -e "${RED}Error: Description required${NC}"
    echo "Usage: worktree-claim.sh <branch-name> <description>"
    exit 1
fi

# Load configuration
CONFIG_PATH="${AUTONOMOUS_DEV_CONFIG:-$HOME/.autonomous-dev/config.json}"

if [ ! -f "$CONFIG_PATH" ]; then
    echo -e "${RED}Error: Configuration not found at $CONFIG_PATH${NC}"
    echo "Run setup.sh first to configure the plugin."
    exit 1
fi

# Parse config using Node.js (cross-platform JSON parsing)
CONTROL_PLANE=$(node -p "require('$CONFIG_PATH').controlPlane")
WORKTREE_PATH=$(node -p "require('$CONFIG_PATH').worktreePath")
REPOS_JSON=$(node -p "JSON.stringify(require('$CONFIG_PATH').repos)")

POOL_FILE="$CONTROL_PLANE/_machine/worktrees.pool.md"
ACTIVITY_FILE="$CONTROL_PLANE/_machine/worktrees.activity.md"

# Check if pool file exists
if [ ! -f "$POOL_FILE" ]; then
    echo -e "${RED}Error: Pool file not found at $POOL_FILE${NC}"
    echo "Run setup.sh first to initialize the agent pool."
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}CLAIMING WORKTREE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Branch: $BRANCH_NAME"
echo "Description: $DESCRIPTION"
echo ""

# Find first FREE agent
AGENT_SEAT=$(grep "| FREE |" "$POOL_FILE" | head -1 | awk -F'|' '{print $2}' | tr -d ' ')

if [ -z "$AGENT_SEAT" ]; then
    echo -e "${RED}Error: No FREE agents available!${NC}"
    echo ""
    echo "All agents are currently BUSY. Options:"
    echo "1. Run worktree-status.sh to check for stale allocations"
    echo "2. Release a completed agent"
    echo "3. Increase pool size in config.json"
    exit 1
fi

echo -e "${GREEN}✓ Found FREE agent: $AGENT_SEAT${NC}"

# Get agent directory
AGENT_DIR="$WORKTREE_PATH/$AGENT_SEAT"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo ""
echo "Creating worktrees for all configured repos..."
echo ""

# Parse repos and create worktrees
REPO_COUNT=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0)).length")

for i in $(seq 0 $((REPO_COUNT - 1))); do
    REPO_NAME=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].name")
    REPO_PATH=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].path")
    BASE_BRANCH=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].baseBranch || 'develop'")

    echo "  Processing: $REPO_NAME"

    # Ensure base repo is on base branch and up-to-date
    cd "$REPO_PATH"

    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]; then
        echo "    ⚠️  Switching from $CURRENT_BRANCH to $BASE_BRANCH"
        git checkout "$BASE_BRANCH"
    fi

    echo "    Fetching latest changes..."
    git fetch origin --prune

    echo "    Pulling $BASE_BRANCH..."
    git pull origin "$BASE_BRANCH"

    # Create worktree
    WORKTREE_DIR="$AGENT_DIR/$REPO_NAME"
    mkdir -p "$AGENT_DIR"

    echo "    Creating worktree at $WORKTREE_DIR..."

    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        echo -e "    ${YELLOW}⚠️  Branch $BRANCH_NAME already exists${NC}"
        echo "    Using existing branch (make sure this is intentional)"
        git worktree add "$WORKTREE_DIR" "$BRANCH_NAME" 2>/dev/null || true
    else
        git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME"
    fi

    # Copy config files if they exist
    echo "    Copying config files..."
    for config in appsettings*.json .env* secrets*.json; do
        if [ -f "$REPO_PATH/$config" ]; then
            cp "$REPO_PATH/$config" "$WORKTREE_DIR/" 2>/dev/null || true
            echo "      ✓ Copied $config"
        fi
    done

    echo -e "    ${GREEN}✓ Worktree created for $REPO_NAME${NC}"
    echo ""
done

# Update pool file (mark as BUSY)
echo "Updating agent pool..."

# Use sed to update the pool file
# Find the line with the agent seat and mark it BUSY
FIRST_REPO=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[0].name")

# Create temporary file with updated pool
cp "$POOL_FILE" "$POOL_FILE.tmp"

# Update the agent's row
sed -i "s|^| $AGENT_SEAT | .* | FREE |.*\$|| $AGENT_SEAT | $AGENT_DIR | BUSY | $FIRST_REPO | $BRANCH_NAME | $TIMESTAMP | $DESCRIPTION |g" "$POOL_FILE.tmp"

# If sed didn't work (no match), try awk
if grep -q "$AGENT_SEAT | .* | FREE |" "$POOL_FILE.tmp"; then
    # Fallback: use awk
    awk -v agent="$AGENT_SEAT" -v dir="$AGENT_DIR" -v repo="$FIRST_REPO" -v branch="$BRANCH_NAME" -v ts="$TIMESTAMP" -v desc="$DESCRIPTION" '
    BEGIN { FS="|"; OFS="|" }
    $2 ~ agent && $5 ~ "FREE" {
        $3 = " " dir " "
        $5 = " BUSY "
        $6 = " " repo " "
        $7 = " " branch " "
        $8 = " " ts " "
        $9 = " " desc " "
    }
    { print }
    ' "$POOL_FILE" > "$POOL_FILE.tmp"
fi

mv "$POOL_FILE.tmp" "$POOL_FILE"

echo -e "${GREEN}✓ Agent pool updated${NC}"

# Log allocation
echo "$TIMESTAMP — allocate — $AGENT_SEAT — $FIRST_REPO — $BRANCH_NAME — — claude-code — $DESCRIPTION" >> "$ACTIVITY_FILE"

echo -e "${GREEN}✓ Activity logged${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ WORKTREE CLAIMED SUCCESSFULLY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Agent: $AGENT_SEAT"
echo "Branch: $BRANCH_NAME"
echo "Worktree base: $AGENT_DIR"
echo ""
echo "Worktrees created:"
for i in $(seq 0 $((REPO_COUNT - 1))); do
    REPO_NAME=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].name")
    echo "  • $AGENT_DIR/$REPO_NAME"
done
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT:${NC}"
echo "  • Edit ONLY in worktree directories above"
echo "  • NEVER edit in base repos"
echo "  • Release with: worktree-release.sh $AGENT_SEAT \"<pr-title>\""
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
echo ""
