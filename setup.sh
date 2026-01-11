#!/usr/bin/env bash
#
# Autonomous Development System - First-Time Setup
# Cross-platform installation wizard
#
# Usage: bash setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OS
OS="unknown"
case "$(uname -s)" in
    Darwin*)    OS="mac";;
    Linux*)     OS="linux";;
    CYGWIN*|MINGW*|MSYS*)    OS="windows";;
esac

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   AUTONOMOUS DEVELOPMENT SYSTEM                           ║
║   First-Time Installation Wizard                          ║
║                                                           ║
║   Battle-tested protocols for multi-repo development     ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}Detected OS: $OS${NC}"
echo ""

# Function to prompt for input with default
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local result

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " result
        echo "${result:-$default}"
    else
        read -p "$prompt: " result
        echo "$result"
    fi
}

# Function to prompt yes/no
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local result

    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " result
        result="${result:-y}"
    else
        read -p "$prompt [y/N]: " result
        result="${result:-n}"
    fi

    [[ "$result" =~ ^[Yy] ]]
}

# Determine default paths based on OS
if [ "$OS" = "windows" ]; then
    DEFAULT_CONTROL_PLANE="$HOME/.autonomous-dev"
    DEFAULT_WORKTREE_PATH="$HOME/Documents/worker-agents"
else
    DEFAULT_CONTROL_PLANE="$HOME/.autonomous-dev"
    DEFAULT_WORKTREE_PATH="$HOME/worker-agents"
fi

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}STEP 1: Control Plane Configuration${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The control plane stores:"
echo "  • Agent pool status (worktrees.pool.md)"
echo "  • Activity logs (worktrees.activity.md)"
echo "  • Reflection logs (lessons learned)"
echo "  • Pattern library"
echo ""

CONTROL_PLANE=$(prompt_with_default "Control plane directory" "$DEFAULT_CONTROL_PLANE")
CONTROL_PLANE="${CONTROL_PLANE/#\~/$HOME}"  # Expand ~

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}STEP 2: Repository Configuration${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Add repositories you want to manage with autonomous development."
echo "These are your BASE repositories (worktrees will be created from them)."
echo ""
echo "Examples:"
echo "  • Name: my-api, Path: /home/user/projects/my-api, Branch: develop"
echo "  • Name: frontend, Path: /home/user/projects/frontend, Branch: main"
echo ""

REPOS=()
REPO_COUNT=0

while true; do
    REPO_COUNT=$((REPO_COUNT + 1))

    echo -e "${GREEN}Repository #$REPO_COUNT${NC}"

    REPO_NAME=$(prompt_with_default "  Repository short name (or 'done' to finish)" "")

    if [ "$REPO_NAME" = "done" ] || [ -z "$REPO_NAME" ]; then
        if [ $REPO_COUNT -eq 1 ]; then
            echo -e "${RED}Error: You must add at least one repository!${NC}"
            REPO_COUNT=0
            continue
        else
            break
        fi
    fi

    REPO_PATH=$(prompt_with_default "  Absolute path to repository" "")
    REPO_PATH="${REPO_PATH/#\~/$HOME}"  # Expand ~

    if [ ! -d "$REPO_PATH" ]; then
        echo -e "${YELLOW}  Warning: Directory does not exist: $REPO_PATH${NC}"
        if ! prompt_yes_no "  Add anyway?"; then
            REPO_COUNT=$((REPO_COUNT - 1))
            continue
        fi
    fi

    REPO_BRANCH=$(prompt_with_default "  Base branch" "develop")

    REPOS+=("{\"name\":\"$REPO_NAME\",\"path\":\"$REPO_PATH\",\"baseBranch\":\"$REPO_BRANCH\"}")

    echo -e "${GREEN}  ✓ Added: $REPO_NAME${NC}"
    echo ""

    if ! prompt_yes_no "Add another repository?" "y"; then
        break
    fi
    echo ""
done

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}STEP 3: Worktree Configuration${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Worktrees are isolated working directories for parallel development."
echo "Each agent gets its own worktree to prevent conflicts."
echo ""

WORKTREE_PATH=$(prompt_with_default "Worktree base path" "$DEFAULT_WORKTREE_PATH")
WORKTREE_PATH="${WORKTREE_PATH/#\~/$HOME}"  # Expand ~

echo ""
AGENT_POOL_SIZE=$(prompt_with_default "Agent pool size (1-50)" "12")

# Validate pool size
if ! [[ "$AGENT_POOL_SIZE" =~ ^[0-9]+$ ]] || [ "$AGENT_POOL_SIZE" -lt 1 ] || [ "$AGENT_POOL_SIZE" -gt 50 ]; then
    echo -e "${YELLOW}Invalid pool size, using default: 12${NC}"
    AGENT_POOL_SIZE=12
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}STEP 4: Shell Preference${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Available shells:"
echo "  1) auto (detect automatically)"
echo "  2) bash"
echo "  3) zsh"
echo "  4) pwsh (PowerShell)"
echo "  5) cmd (Windows Command Prompt)"
echo ""

SHELL_CHOICE=$(prompt_with_default "Select shell [1-5]" "1")

case "$SHELL_CHOICE" in
    1) PREFERRED_SHELL="auto";;
    2) PREFERRED_SHELL="bash";;
    3) PREFERRED_SHELL="zsh";;
    4) PREFERRED_SHELL="pwsh";;
    5) PREFERRED_SHELL="cmd";;
    *) PREFERRED_SHELL="auto";;
esac

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Configuration Summary${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Control Plane: $CONTROL_PLANE"
echo "Worktree Path: $WORKTREE_PATH"
echo "Agent Pool Size: $AGENT_POOL_SIZE"
echo "Shell: $PREFERRED_SHELL"
echo ""
echo "Repositories:"
for repo in "${REPOS[@]}"; do
    name=$(echo "$repo" | grep -oP '(?<="name":")[^"]*')
    path=$(echo "$repo" | grep -oP '(?<="path":")[^"]*')
    echo "  • $name → $path"
done
echo ""

if ! prompt_yes_no "Proceed with installation?" "y"; then
    echo -e "${RED}Installation cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Installing...${NC}"

# Create directories
mkdir -p "$CONTROL_PLANE"
mkdir -p "$CONTROL_PLANE/_machine"
mkdir -p "$CONTROL_PLANE/patterns"
mkdir -p "$CONTROL_PLANE/agents"
mkdir -p "$WORKTREE_PATH"

echo -e "${GREEN}✓ Created directories${NC}"

# Build JSON config
REPOS_JSON=$(IFS=,; echo "[${REPOS[*]}]")

CONFIG_FILE="$CONTROL_PLANE/config.json"

cat > "$CONFIG_FILE" << EOF
{
  "version": "1.0.0",
  "installedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "os": "$OS",
  "controlPlane": "$CONTROL_PLANE",
  "worktreePath": "$WORKTREE_PATH",
  "agentPoolSize": $AGENT_POOL_SIZE,
  "shell": "$PREFERRED_SHELL",
  "repos": $REPOS_JSON
}
EOF

echo -e "${GREEN}✓ Created configuration: $CONFIG_FILE${NC}"

# Initialize pool
POOL_FILE="$CONTROL_PLANE/_machine/worktrees.pool.md"

cat > "$POOL_FILE" << 'EOF'
# Worktree Agent Pool

| Seat | Directory | Status | Current Repo | Branch | Last Activity | Notes |
|------|-----------|--------|--------------|--------|---------------|-------|
EOF

for i in $(seq 1 $AGENT_POOL_SIZE); do
    AGENT_NUM=$(printf "%03d" $i)
    echo "| agent-$AGENT_NUM | $WORKTREE_PATH/agent-$AGENT_NUM | FREE | - | - | $(date -u +"%Y-%m-%dT%H:%M:%SZ") | Initial setup |" >> "$POOL_FILE"
    mkdir -p "$WORKTREE_PATH/agent-$AGENT_NUM"
done

echo -e "${GREEN}✓ Initialized agent pool with $AGENT_POOL_SIZE seats${NC}"

# Initialize activity log
ACTIVITY_FILE="$CONTROL_PLANE/_machine/worktrees.activity.md"

cat > "$ACTIVITY_FILE" << EOF
# Worktree Activity Log

Format: \`TIMESTAMP — action — agent-seat — repo — branch — task-id — executor — description\`

## Activity

$(date -u +"%Y-%m-%dT%H:%M:%SZ") — init — system — - — - — - — setup — Autonomous Development System installed with $AGENT_POOL_SIZE agents
EOF

echo -e "${GREEN}✓ Created activity log${NC}"

# Initialize reflection log
REFLECTION_FILE="$CONTROL_PLANE/_machine/reflection.log.md"

cat > "$REFLECTION_FILE" << EOF
# Reflection Log - Lessons Learned

This file contains lessons learned, patterns discovered, and improvements made during development sessions.

## Format

Each entry should follow:
\`\`\`
## YYYY-MM-DD HH:MM - [Title]

**Problem:** [What went wrong or what was discovered]
**Root Cause:** [Why it happened]
**Fix:** [How it was resolved]
**Pattern:** [Reusable pattern or lesson learned]
\`\`\`

---

## $(date +"%Y-%m-%d %H:%M") - System Installation

**Event:** Autonomous Development System installed
**Configuration:** $AGENT_POOL_SIZE agents, $((${#REPOS[@]})) repositories
**Status:** Ready for use
EOF

echo -e "${GREEN}✓ Created reflection log${NC}"

# Create symlink to plugin (for Claude Code to find it)
PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Installation Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Configuration saved to: $CONFIG_FILE"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Install the plugin in Claude Code:"
echo -e "   ${BLUE}claude plugin install --local \"$PLUGIN_DIR\"${NC}"
echo ""
echo "2. Or use during development:"
echo -e "   ${BLUE}claude --plugin-dir=\"$PLUGIN_DIR\"${NC}"
echo ""
echo "3. Available commands:"
echo "   • /worktree:claim <branch> <description>"
echo "   • /worktree:release <agent-seat> <pr-title>"
echo "   • /worktree:status"
echo "   • /dashboard"
echo "   • /pr:status"
echo "   • /patterns:search <keyword>"
echo ""
echo "4. View configuration:"
echo -e "   ${BLUE}cat $CONFIG_FILE${NC}"
echo ""
echo -e "${GREEN}Happy autonomous developing! 🚀${NC}"
echo ""
