# Worktree Status Command

Show the current state of the agent pool, including which agents are FREE, BUSY, and what they're working on.

## What It Shows

1. **Pool Overview**
   - Total agents configured
   - FREE agents available
   - BUSY agents working
   - Stale agents (BUSY > 2 hours)

2. **Detailed Agent Status**
   - Agent seat number
   - Status (FREE/BUSY)
   - Current repository (if BUSY)
   - Current branch (if BUSY)
   - Last activity timestamp
   - Duration since last activity

3. **Stale Agent Detection** (Pattern 64)
   - PR merged but still BUSY
   - No activity > 2 hours
   - Empty worktree but marked BUSY
   - Upstream branch deleted

## Usage

```
/worktree:status
```

## Example Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WORKTREE AGENT POOL STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Pool Size: 12 agents
FREE: 8 agents (67%)
BUSY: 4 agents (33%)
STALE: 1 agent (needs release)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

BUSY AGENTS:

agent-001 [BUSY] ⏱️  2h 15m ago
  Repo: client-manager
  Branch: feature/new-api
  Working on: Implementing REST API endpoints
  ✅ Active

agent-003 [BUSY] ⏱️  45m ago
  Repo: hazina
  Branch: fix/config-migration
  Working on: Fixing OpenAI config migration
  ✅ Active

agent-005 [BUSY] ⏱️  5h 32m ago  ⚠️  STALE
  Repo: client-manager
  Branch: feature/oauth
  Working on: OAuth integration
  🚨 No activity > 2 hours - Check if work complete

agent-007 [BUSY] ⏱️  1d 3h ago  ⚠️  STALE
  Repo: hazina
  Branch: improvement/semantic-cache
  PR #45: MERGED
  🚨 PR merged - Release worktree!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FREE AGENTS: agent-002, agent-004, agent-006, agent-008,
             agent-009, agent-010, agent-011, agent-012

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 TIP: To release a stale agent:
   /worktree:release agent-007 "feat: Semantic cache improvements"

💡 TIP: To claim a FREE agent:
   /worktree:claim feature/my-work "Description"
```

## Actionable Insights

- **Stale agents** → Suggest running `/worktree:release`
- **All BUSY** → Suggest checking for stale allocations or provisioning more agents
- **High FREE count** → Pool is healthy, agents available
- **PR merged but BUSY** → Immediate release recommended

## Implementation

Read pool file, parse status, calculate durations, check PR status for BUSY agents.

$SHELL_COMMAND: bash "${PLUGIN_DIR}/scripts/worktree-status.sh"
