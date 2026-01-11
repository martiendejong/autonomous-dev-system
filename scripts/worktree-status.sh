#!/usr/bin/env bash
#
# Worktree Status Script - Show Agent Pool Status
#
# Usage: worktree-status.sh
#
# Shows current pool status, identifies stale agents,
# and provides actionable suggestions.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

if [ ! -f "$POOL_FILE" ]; then
    echo -e "${RED}Error: Pool file not found at $POOL_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}WORKTREE AGENT POOL STATUS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Count agents
TOTAL_AGENTS=$(grep -c "^| agent-" "$POOL_FILE" || echo "0")
FREE_AGENTS=$(grep -c "| FREE |" "$POOL_FILE" || echo "0")
BUSY_AGENTS=$(grep -c "| BUSY |" "$POOL_FILE" || echo "0")

if [ "$TOTAL_AGENTS" -eq 0 ]; then
    echo -e "${RED}No agents found in pool!${NC}"
    exit 1
fi

# Calculate percentages
FREE_PERCENT=$((FREE_AGENTS * 100 / TOTAL_AGENTS))
BUSY_PERCENT=$((BUSY_AGENTS * 100 / TOTAL_AGENTS))

echo "Pool Size: $TOTAL_AGENTS agents"
echo "FREE: $FREE_AGENTS agents ($FREE_PERCENT%)"
echo "BUSY: $BUSY_AGENTS agents ($BUSY_PERCENT%)"

# Detect stale agents
STALE_COUNT=0
STALE_AGENTS=()

CURRENT_TIME=$(date +%s)
STALE_THRESHOLD=7200  # 2 hours in seconds

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$BUSY_AGENTS" -eq 0 ]; then
    echo -e "${GREEN}No BUSY agents - pool is idle${NC}"
else
    echo -e "${YELLOW}BUSY AGENTS:${NC}"
    echo ""

    # Parse BUSY agents
    grep "| BUSY |" "$POOL_FILE" | while IFS='|' read -r _ seat path status repo branch timestamp desc _; do
        # Trim whitespace
        seat=$(echo "$seat" | tr -d ' ')
        path=$(echo "$path" | tr -d ' ')
        repo=$(echo "$repo" | tr -d ' ')
        branch=$(echo "$branch" | tr -d ' ')
        timestamp=$(echo "$timestamp" | tr -d ' ')
        desc=$(echo "$desc" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Calculate duration
        if [ -n "$timestamp" ] && [ "$timestamp" != "-" ]; then
            # Parse ISO 8601 timestamp
            AGENT_TIME=$(date -d "$timestamp" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" +%s 2>/dev/null || echo "0")

            if [ "$AGENT_TIME" -gt 0 ]; then
                DURATION=$((CURRENT_TIME - AGENT_TIME))
                HOURS=$((DURATION / 3600))
                MINUTES=$(((DURATION % 3600) / 60))

                if [ "$HOURS" -gt 0 ]; then
                    DURATION_STR="${HOURS}h ${MINUTES}m ago"
                else
                    DURATION_STR="${MINUTES}m ago"
                fi

                IS_STALE=false

                # Check stale criteria
                if [ "$DURATION" -gt "$STALE_THRESHOLD" ]; then
                    IS_STALE=true
                    STALE_REASON="No activity > 2 hours"
                fi

                # Check if PR merged (if we can determine branch/repo)
                if [ -n "$branch" ] && [ "$branch" != "-" ] && [ -n "$repo" ] && [ "$repo" != "-" ]; then
                    # Try to get PR status
                    REPO_PATH_VAL=$(echo "$REPOS_JSON" | node -p "
                        const repos = JSON.parse(require('fs').readFileSync(0));
                        const repo = repos.find(r => r.name === '$repo');
                        repo ? repo.path : '';
                    ")

                    if [ -n "$REPO_PATH_VAL" ] && [ -d "$REPO_PATH_VAL" ]; then
                        cd "$REPO_PATH_VAL"

                        # Check if PR exists and status
                        PR_STATE=$(gh pr list --head "$branch" --state all --json state,title,number --jq '.[0] | "\(.state)|\(.number)|\(.title)"' 2>/dev/null || echo "")

                        if [ -n "$PR_STATE" ]; then
                            STATE=$(echo "$PR_STATE" | cut -d'|' -f1)
                            PR_NUM=$(echo "$PR_STATE" | cut -d'|' -f2)
                            PR_TITLE=$(echo "$PR_STATE" | cut -d'|' -f3)

                            if [ "$STATE" = "MERGED" ]; then
                                IS_STALE=true
                                STALE_REASON="PR #$PR_NUM merged"
                            fi
                        fi
                    fi
                fi

                # Display agent
                if [ "$IS_STALE" = true ]; then
                    STALE_COUNT=$((STALE_COUNT + 1))
                    echo -e "${seat} ${RED}[BUSY]${NC} ⏱️  ${DURATION_STR}  ${RED}⚠️  STALE${NC}"
                else
                    echo -e "${seat} ${YELLOW}[BUSY]${NC} ⏱️  ${DURATION_STR}  ${GREEN}✅ Active${NC}"
                fi

                if [ -n "$repo" ] && [ "$repo" != "-" ]; then
                    echo "  Repo: $repo"
                fi
                if [ -n "$branch" ] && [ "$branch" != "-" ]; then
                    echo "  Branch: $branch"
                fi
                if [ -n "$desc" ] && [ "$desc" != "-" ]; then
                    echo "  Working on: $desc"
                fi
                if [ "$IS_STALE" = true ]; then
                    echo -e "  ${RED}🚨 $STALE_REASON${NC}"
                fi

                echo ""
            fi
        fi
    done
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# List FREE agents
if [ "$FREE_AGENTS" -gt 0 ]; then
    FREE_LIST=$(grep "| FREE |" "$POOL_FILE" | awk -F'|' '{print $2}' | tr -d ' ' | tr '\n' ', ' | sed 's/,$//')
    echo -e "${GREEN}FREE AGENTS:${NC} $FREE_LIST"
    echo ""
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Actionable tips
if [ "$STALE_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}💡 TIP: To release a stale agent:${NC}"
    echo "   worktree-release.sh <agent-seat> \"<pr-title>\""
    echo ""
fi

if [ "$FREE_AGENTS" -gt 0 ]; then
    echo -e "${GREEN}💡 TIP: To claim a FREE agent:${NC}"
    echo "   worktree-claim.sh <branch-name> \"<description>\""
    echo ""
fi

if [ "$FREE_AGENTS" -eq 0 ]; then
    echo -e "${RED}⚠️  WARNING: No FREE agents available!${NC}"
    echo ""
    echo "Options:"
    echo "1. Release a completed agent (check for STALE agents above)"
    echo "2. Increase pool size in config.json"
    echo ""
fi

# Health indicator
if [ "$FREE_PERCENT" -ge 50 ]; then
    echo -e "${GREEN}✅ Pool health: HEALTHY${NC} ($FREE_PERCENT% available)"
elif [ "$FREE_PERCENT" -ge 25 ]; then
    echo -e "${YELLOW}⚠️  Pool health: MODERATE${NC} ($FREE_PERCENT% available)"
else
    echo -e "${RED}🚨 Pool health: CRITICAL${NC} ($FREE_PERCENT% available)"
fi

echo ""
