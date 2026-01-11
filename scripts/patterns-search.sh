#!/usr/bin/env bash
#
# Pattern Search Script - Search Pattern Library
#
# Usage: patterns-search.sh <keyword>
#
# Searches through documented patterns for solutions
# to common problems.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

KEYWORD="$1"

if [ -z "$KEYWORD" ]; then
    echo -e "${RED}Error: Search keyword required${NC}"
    echo "Usage: patterns-search.sh <keyword>"
    echo ""
    echo "Examples:"
    echo "  patterns-search.sh merge"
    echo "  patterns-search.sh CI"
    echo "  patterns-search.sh docker"
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
PATTERNS_DIR="$CONTROL_PLANE/patterns"

if [ ! -d "$PATTERNS_DIR" ]; then
    echo -e "${YELLOW}⚠️  Patterns directory not found${NC}"
    echo ""
    echo "Run pattern extraction to populate the library:"
    echo "  (Pattern extraction task pending)"
    echo ""
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}PATTERN SEARCH: \"$KEYWORD\"${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Search in pattern files
RESULTS=$(grep -ril "$KEYWORD" "$PATTERNS_DIR" 2>/dev/null || echo "")

if [ -z "$RESULTS" ]; then
    echo -e "${YELLOW}No patterns found matching \"$KEYWORD\"${NC}"
    echo ""
    echo "Try different keywords:"
    echo "  - More general terms (e.g., 'build' instead of 'MSBuild')"
    echo "  - Related concepts (e.g., 'merge' for conflict resolution)"
    echo "  - Technology names (e.g., 'docker', 'npm', 'git')"
    echo ""
    exit 0
fi

# Display matching patterns
COUNT=0
while IFS= read -r file; do
    if [ -f "$file" ]; then
        COUNT=$((COUNT + 1))

        # Extract pattern number and title
        FILENAME=$(basename "$file")
        PATTERN_NUM=$(echo "$FILENAME" | grep -oP 'pattern-\K[0-9]+' || echo "??")

        # Get first line (title)
        TITLE=$(head -1 "$file" | sed 's/^#* *//')

        # Extract relevant excerpt
        EXCERPT=$(grep -i "$KEYWORD" "$file" | head -3 | sed 's/^/    /')

        echo -e "${CYAN}Pattern $PATTERN_NUM: $TITLE${NC}"
        echo -e "${GREEN}File:${NC} $file"
        echo ""
        echo "Matching excerpt:"
        echo "$EXCERPT"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    fi
done <<< "$RESULTS"

echo -e "${GREEN}Found $COUNT pattern(s) matching \"$KEYWORD\"${NC}"
echo ""
echo -e "${CYAN}💡 TIP: Read full pattern file for complete solution${NC}"
echo ""
