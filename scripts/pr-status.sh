#!/usr/bin/env bash
#
# PR Status Script - Show All Open PRs Across Repos
#
# Usage: pr-status.sh
#
# Shows comprehensive PR status including CI checks,
# merge conflicts, and ready-to-merge PRs.

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
REPOS_JSON=$(node -p "JSON.stringify(require('$CONFIG_PATH').repos)")
REPO_COUNT=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0)).length")

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}PULL REQUEST STATUS - ALL REPOSITORIES${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

TOTAL_PRS=0
MERGEABLE_PRS=0
CONFLICTING_PRS=0
CI_FAILING_PRS=0

# Process each repository
for i in $(seq 0 $((REPO_COUNT - 1))); do
    REPO_NAME=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].name")
    REPO_PATH=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].path")
    BASE_BRANCH=$(echo "$REPOS_JSON" | node -p "JSON.parse(require('fs').readFileSync(0))[$i].baseBranch || 'develop'")

    if [ ! -d "$REPO_PATH" ]; then
        continue
    fi

    cd "$REPO_PATH"

    # Get open PRs
    PR_DATA=$(gh pr list --state open --json number,title,baseRefName,headRefName,state,mergeable,statusCheckRollup,author,createdAt 2>/dev/null || echo "[]")
    PR_COUNT=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0)).length")

    if [ "$PR_COUNT" -eq 0 ]; then
        continue
    fi

    TOTAL_PRS=$((TOTAL_PRS + PR_COUNT))

    echo -e "${CYAN}Repository: $REPO_NAME${NC} ($PR_COUNT open PR$([ "$PR_COUNT" -ne 1 ] && echo "s" || echo ""))"
    echo ""

    # Parse each PR
    for j in $(seq 0 $((PR_COUNT - 1))); do
        PR_NUM=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0))[$j].number")
        PR_TITLE=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0))[$j].title")
        PR_BASE=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0))[$j].baseRefName")
        PR_HEAD=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0))[$j].headRefName")
        PR_MERGEABLE=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0))[$j].mergeable || 'UNKNOWN'")
        PR_AUTHOR=$(echo "$PR_DATA" | node -p "JSON.parse(require('fs').readFileSync(0))[$j].author.login")

        # Count statuses
        case "$PR_MERGEABLE" in
            MERGEABLE)
                MERGEABLE_PRS=$((MERGEABLE_PRS + 1))
                ;;
            CONFLICTING)
                CONFLICTING_PRS=$((CONFLICTING_PRS + 1))
                ;;
        esac

        # CI status
        CI_CHECKS=$(echo "$PR_DATA" | node -p "
            const pr = JSON.parse(require('fs').readFileSync(0))[$j];
            const rollup = pr.statusCheckRollup || [];
            const contexts = rollup.filter(r => r.__typename === 'StatusContext' || r.__typename === 'CheckRun');

            const results = contexts.map(c => {
                const name = c.name || c.context || 'Unknown';
                const state = c.state || c.conclusion || 'UNKNOWN';
                const icon = state === 'SUCCESS' ? '✅' : state === 'FAILURE' ? '❌' : '⏳';
                return \`\${icon} \${name}: \${state}\`;
            });

            if (results.length === 0) return 'No CI checks';
            return results.join('\\n       ');
        " 2>/dev/null || echo "No CI data")

        # Count failing checks
        FAILING_COUNT=$(echo "$CI_CHECKS" | grep -c "❌" || echo "0")
        if [ "$FAILING_COUNT" -gt 0 ]; then
            CI_FAILING_PRS=$((CI_FAILING_PRS + 1))
        fi

        # PR status icon
        if [ "$PR_MERGEABLE" = "MERGEABLE" ] && [ "$FAILING_COUNT" -eq 0 ]; then
            STATUS="${GREEN}✅ Ready to merge${NC}"
        elif [ "$PR_MERGEABLE" = "CONFLICTING" ]; then
            STATUS="${RED}⚠️  CONFLICTING${NC}"
        elif [ "$FAILING_COUNT" -gt 0 ]; then
            STATUS="${RED}❌ CI failing${NC}"
        else
            STATUS="${YELLOW}⏳ Pending${NC}"
        fi

        echo -e "  ${CYAN}#$PR_NUM${NC} $PR_TITLE"
        echo -e "       Status: $STATUS"
        echo "       Branch: $PR_HEAD → $PR_BASE"
        echo "       Author: $PR_AUTHOR"
        echo -e "       CI Checks:"
        echo "       $CI_CHECKS"

        # Warnings
        if [ "$PR_BASE" != "$BASE_BRANCH" ]; then
            echo -e "       ${RED}⚠️  WARNING: Wrong base branch (targets $PR_BASE, should be $BASE_BRANCH)${NC}"
        fi

        echo ""
    done

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
done

# Summary
if [ "$TOTAL_PRS" -eq 0 ]; then
    echo -e "${GREEN}✅ No open pull requests across all repositories${NC}"
    echo ""
else
    echo -e "${CYAN}SUMMARY${NC}"
    echo ""
    echo "Total Open PRs: $TOTAL_PRS"
    echo -e "  ${GREEN}✅ Mergeable: $MERGEABLE_PRS${NC}"
    echo -e "  ${RED}⚠️  Conflicting: $CONFLICTING_PRS${NC}"
    echo -e "  ${RED}❌ CI Failing: $CI_FAILING_PRS${NC}"
    echo ""

    if [ "$MERGEABLE_PRS" -gt 0 ]; then
        echo -e "${GREEN}💡 TIP: You have $MERGEABLE_PRS PR(s) ready to merge!${NC}"
        echo ""
    fi

    if [ "$CONFLICTING_PRS" -gt 0 ]; then
        echo -e "${YELLOW}💡 TIP: Resolve conflicts for $CONFLICTING_PRS PR(s)${NC}"
        echo ""
    fi
fi
