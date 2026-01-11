#!/usr/bin/env bash
#
# Dashboard Script - Comprehensive Repository Overview
#
# Usage: dashboard.sh
#
# Shows status for all configured repos including:
# - Branch status and cleanliness
# - Recent commits
# - Open PRs with CI status
# - Agent pool health
# - Action items

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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
REPOS_JSON=$(node -p "JSON.stringify(require('$CONFIG_PATH').repos)")
POOL_FILE="$CONTROL_PLANE/_machine/worktrees.pool.md"

REPO_COUNT=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0)).length")

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  REPOSITORY DASHBOARD                      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

ACTION_ITEMS=()

# Process each repository
for i in $(seq 0 $((REPO_COUNT - 1))); do
    REPO_NAME=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].name")
    REPO_PATH=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].path")
    BASE_BRANCH=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].baseBranch || 'develop'")

    if [ ! -d "$REPO_PATH" ]; then
        echo -e "${RED}⚠️  Repository not found: $REPO_PATH${NC}"
        echo ""
        continue
    fi

    cd "$REPO_PATH"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📁 $REPO_NAME${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Branch status
    CURRENT_BRANCH=$(git branch --show-current)
    UNCOMMITTED=$(git status --porcelain | wc -l)
    UNPUSHED=$(git log origin/$CURRENT_BRANCH..$CURRENT_BRANCH --oneline 2>/dev/null | wc -l || echo "0")

    if [ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]; then
        echo -e "Branch: ${YELLOW}$CURRENT_BRANCH${NC} ⚠️  (expected: $BASE_BRANCH)"
        ACTION_ITEMS+=("$REPO_NAME on wrong branch: $CURRENT_BRANCH (should be $BASE_BRANCH)")
    elif [ "$UNCOMMITTED" -gt 0 ] || [ "$UNPUSHED" -gt 0 ]; then
        echo -e "Branch: $CURRENT_BRANCH ${YELLOW}⚠️  Dirty${NC} ($UNCOMMITTED uncommitted, $UNPUSHED unpushed)"
        if [ "$UNCOMMITTED" -gt 0 ]; then
            ACTION_ITEMS+=("$REPO_NAME has $UNCOMMITTED uncommitted changes")
        fi
    else
        echo -e "Branch: $CURRENT_BRANCH ${GREEN}✅ Clean${NC} (0 uncommitted, 0 unpushed)"
    fi

    # Last update time
    LAST_COMMIT_TIME=$(git log -1 --format="%ar")
    echo "Last updated: $LAST_COMMIT_TIME"
    echo ""

    # Recent commits
    echo "Recent Commits:"
    git log -3 --format="  %C(yellow)%h%C(reset)  %s %C(cyan)(%ar)%C(reset)" --no-merges
    echo ""

    # Open PRs
    PR_DATA=$(gh pr list --json number,title,baseRefName,state,mergeable,statusCheckRollup,createdAt 2>/dev/null || echo "[]")
    PR_COUNT=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0)).length")

    if [ "$PR_COUNT" -gt 0 ]; then
        echo "Open PRs: $PR_COUNT"
        echo ""

        # Parse each PR
        for j in $(seq 0 $((PR_COUNT - 1))); do
            PR_NUM=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0))[$j].number")
            PR_TITLE=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0))[$j].title")
            PR_BASE=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0))[$j].baseRefName")
            PR_STATE=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0))[$j].state")
            PR_MERGEABLE=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0))[$j].mergeable || 'UNKNOWN'")

            # CI status
            CI_SUMMARY=$(echo "$PR_DATA" | node -p "
                const pr = JSON.parse(require('fs').readFileSync(0))[$j];
                const rollup = pr.statusCheckRollup || [];
                const contexts = rollup.filter(r => r.__typename === 'StatusContext' || r.__typename === 'CheckRun');
                const passing = contexts.filter(c => c.state === 'SUCCESS' || c.conclusion === 'SUCCESS').length;
                const failing = contexts.filter(c => c.state === 'FAILURE' || c.conclusion === 'FAILURE').length;
                const pending = contexts.filter(c => c.state === 'PENDING' || c.state === 'IN_PROGRESS').length;
                \`\${passing} passing, \${failing} failing, \${pending} pending\`;
            " 2>/dev/null || echo "no CI data")

            # Status indicators
            if [ "$PR_MERGEABLE" = "MERGEABLE" ]; then
                STATUS_ICON="${GREEN}✅ MERGEABLE${NC}"
            elif [ "$PR_MERGEABLE" = "CONFLICTING" ]; then
                STATUS_ICON="${RED}⚠️  CONFLICTING${NC}"
                ACTION_ITEMS+=("PR #$PR_NUM in $REPO_NAME has merge conflicts")
            else
                STATUS_ICON="${YELLOW}⏳ PENDING${NC}"
            fi

            # Check base branch
            if [ "$PR_BASE" != "$BASE_BRANCH" ]; then
                BASE_WARNING="${RED}⚠️  WRONG BASE!${NC} (targets $PR_BASE, should be $BASE_BRANCH)"
                ACTION_ITEMS+=("PR #$PR_NUM in $REPO_NAME targets wrong base: $PR_BASE (should be $BASE_BRANCH)")
            else
                BASE_WARNING=""
            fi

            echo -e "  ${CYAN}#$PR_NUM${NC} $PR_TITLE $STATUS_ICON"
            echo "       CI: $CI_SUMMARY"
            echo -e "       Base: $PR_BASE $BASE_WARNING"

            # Time ago
            PR_AGO=$(gh pr view "$PR_NUM" --json createdAt -q '.createdAt' | xargs -I {} date -d {} "+%s" 2>/dev/null || echo "0")
            if [ "$PR_AGO" -gt 0 ]; then
                NOW=$(date +%s)
                DIFF=$((NOW - PR_AGO))
                HOURS=$((DIFF / 3600))
                if [ "$HOURS" -gt 24 ]; then
                    DAYS=$((HOURS / 24))
                    echo "       Created ${DAYS}d ago"
                else
                    echo "       Created ${HOURS}h ago"
                fi
            fi

            # Check if ready to merge
            if [ "$PR_MERGEABLE" = "MERGEABLE" ] && [[ "$CI_SUMMARY" == *"0 failing"* ]]; then
                ACTION_ITEMS+=("✅ Ready to merge: PR #$PR_NUM in $REPO_NAME")
            fi

            echo ""
        done
    else
        echo "Open PRs: 0"
        echo ""
    fi
done

# Agent pool status
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🤖 AGENT POOL STATUS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -f "$POOL_FILE" ]; then
    TOTAL_AGENTS=$(grep -c "^| agent-" "$POOL_FILE" || echo "0")
    FREE_AGENTS=$(grep -c "| FREE |" "$POOL_FILE" || echo "0")
    BUSY_AGENTS=$(grep -c "| BUSY |" "$POOL_FILE" || echo "0")

    if [ "$TOTAL_AGENTS" -gt 0 ]; then
        FREE_PERCENT=$((FREE_AGENTS * 100 / TOTAL_AGENTS))

        echo "Pool: $TOTAL_AGENTS agents"
        echo -e "FREE: $FREE_AGENTS agents ($FREE_PERCENT%)"
        echo -e "BUSY: $BUSY_AGENTS agents"

        # Check for stale agents
        STALE_COUNT=$(grep "| BUSY |" "$POOL_FILE" | wc -l || echo "0")
        if [ "$STALE_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}⚠️  Check /worktree:status for details${NC}"
        fi

        echo ""

        if [ "$FREE_PERCENT" -ge 50 ]; then
            echo -e "${GREEN}✅ Pool health: HEALTHY${NC}"
        elif [ "$FREE_PERCENT" -ge 25 ]; then
            echo -e "${YELLOW}⚠️  Pool health: MODERATE${NC}"
        else
            echo -e "${RED}🚨 Pool health: CRITICAL${NC}"
            ACTION_ITEMS+=("Agent pool critically low ($FREE_PERCENT% available)")
        fi
    fi
else
    echo -e "${YELLOW}⚠️  Pool file not found${NC}"
fi

echo ""

# Action items summary
if [ ${#ACTION_ITEMS[@]} -gt 0 ]; then
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🚨 ACTION ITEMS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    for item in "${ACTION_ITEMS[@]}"; do
        if [[ "$item" == *"Ready to merge"* ]]; then
            echo -e "${GREEN}$item${NC}"
        elif [[ "$item" == *"wrong base"* ]] || [[ "$item" == *"conflicts"* ]]; then
            echo -e "${RED}⚠️  $item${NC}"
        else
            echo -e "${YELLOW}⚠️  $item${NC}"
        fi
    done

    echo ""
else
    echo -e "${GREEN}✅ No action items - all systems nominal!${NC}"
    echo ""
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}💡 Run /worktree:status for detailed agent breakdown${NC}"
echo -e "${CYAN}💡 Run /pr:status for detailed PR checks${NC}"
echo ""
