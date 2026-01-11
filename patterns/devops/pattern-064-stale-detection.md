# Pattern 64: Stale Agent Detection Criteria

**Category:** Worktree Management
**Severity:** HIGH
**Status:** Active Monitoring

---

## Problem

How to identify agents that need release but are still marked BUSY?

**Impact if not detected:**
- Resource leaks (50% capacity loss discovered in real case)
- Agents locked for days
- User thinks "no agents available" but they're just stuck
- System degrades over time

## Detection Criteria

**An agent is STALE if ANY of these conditions are met:**

### 1. PR Merged But Still BUSY

**Check:**
```bash
# Get branch from pool
BRANCH=$(grep "agent-XXX" C:/scripts/_machine/worktrees.pool.md | cut -f7 -d'|' | tr -d ' ')

# Check PR status
gh pr list --head "$BRANCH" --json state -q '.[0].state'
# Output: "MERGED"

# Check pool status
grep "agent-XXX" C:/scripts/_machine/worktrees.pool.md | grep BUSY
# Output: Shows BUSY

# Conclusion: STALE (work is done, just not cleaned up)
```

**Action:** Immediate release (Pattern 63)

---

### 2. No Activity > 2 Hours While BUSY

**Check:**
```bash
# Get last activity timestamp from pool
LAST=$(grep "agent-XXX" C:/scripts/_machine/worktrees.pool.md | grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z')
# Example: 2026-01-10T08:00:00Z

# Current time
NOW=$(date -u +%s)

# Convert timestamp to epoch
LAST_EPOCH=$(date -d "$LAST" +%s)

# Calculate hours
HOURS=$(( (NOW - LAST_EPOCH) / 3600 ))
# Example: 6 hours

# Check for recent commits
cd C:/Projects/worker-agents/agent-XXX/repo
git log -1 --format=%ci
# Output: 2026-01-10 08:05 (6 hours ago)
```

**If HOURS > 2:** Investigate → likely abandoned work

**Action:**
- Check PR status (merged? open? draft?)
- Check for uncommitted changes
- If PR merged OR no valuable changes: Release
- If work in progress: Contact developer

---

### 3. Empty Worktree But Marked BUSY

**Check:**
```bash
# Check worktree contents
ls -la C:/Projects/worker-agents/agent-XXX/
# Output: (empty, only . and ..)

# Check pool
grep "agent-XXX" C:/scripts/_machine/worktrees.pool.md
# Output: Shows BUSY

# Conclusion: STALE (already cleaned, pool not updated)
```

**Action:** Immediate release (just update pool + log)

---

### 4. Upstream Branch Deleted (PR Merged)

**Check:**
```bash
# In worktree directory
cd C:/Projects/worker-agents/agent-XXX/repo
git status

# Output:
# "Your branch is based on 'origin/feature-branch', but the upstream is gone."
```

**Meaning:** PR was merged and branch was deleted on remote

**Action:** Immediate release

---

## Automated Detection Script

**Create:** `C:/scripts/tools/check-stale-agents.sh`

```bash
#!/bin/bash

echo "=== Stale Agent Detection ==="
echo ""

STALE_COUNT=0

# Find all BUSY agents
for agent in $(grep "BUSY" C:/scripts/_machine/worktrees.pool.md | cut -f2 -d'|' | tr -d ' '); do
  echo "Checking $agent..."

  # Extract metadata
  REPO=$(grep "| $agent |" C:/scripts/_machine/worktrees.pool.md | cut -f6 -d'|' | tr -d ' ')
  BRANCH=$(grep "| $agent |" C:/scripts/_machine/worktrees.pool.md | cut -f7 -d'|' | tr -d ' ')
  LAST=$(grep "| $agent |" C:/scripts/_machine/worktrees.pool.md | cut -f8 -d'|' | tr -d ' ')

  IS_STALE=false
  STALE_REASON=""

  # Check 1: Empty worktree
  if [ -z "$(ls -A C:/Projects/worker-agents/$agent/ 2>/dev/null)" ]; then
    IS_STALE=true
    STALE_REASON="Empty worktree"
    echo "  ⚠️  STALE: $STALE_REASON"
  fi

  # Check 2: Time since last activity
  if [ -n "$LAST" ] && [ "$LAST" != "-" ]; then
    NOW=$(date -u +%s)
    LAST_EPOCH=$(date -d "$LAST" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST" +%s 2>/dev/null)

    if [ -n "$LAST_EPOCH" ]; then
      HOURS=$(( (NOW - LAST_EPOCH) / 3600 ))

      if [ "$HOURS" -gt 2 ]; then
        IS_STALE=true
        STALE_REASON="No activity for ${HOURS}h"
        echo "  ⚠️  STALE: $STALE_REASON"
      fi
    fi
  fi

  # Check 3: PR merged
  if [ -n "$BRANCH" ] && [ "$BRANCH" != "-" ]; then
    cd "C:/Projects/$REPO" 2>/dev/null || continue

    PR_STATE=$(gh pr list --head "$BRANCH" --state all --json state -q '.[0].state' 2>/dev/null)

    if [ "$PR_STATE" = "MERGED" ]; then
      IS_STALE=true
      STALE_REASON="PR merged"
      echo "  ⚠️  STALE: $STALE_REASON"
    fi
  fi

  if [ "$IS_STALE" = true ]; then
    STALE_COUNT=$((STALE_COUNT + 1))
    echo "  🚨 ACTION: Release $agent"
    echo "     Command: /worktree:release $agent \"Cleanup: $STALE_REASON\""
  else
    echo "  ✅ Active"
  fi

  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STALE AGENTS: $STALE_COUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

**Usage:**
```bash
bash C:/scripts/tools/check-stale-agents.sh

# Example output:
# Checking agent-001...
#   ⚠️  STALE: PR merged
#   🚨 ACTION: Release agent-001
#      Command: /worktree:release agent-001 "Cleanup: PR merged"
#
# Checking agent-002...
#   ✅ Active
```

## When to Run Stale Detection

**Proactive (scheduled):**
- ✅ Daily at session start
- ✅ Before allocating new worktree (check if capacity available)
- ✅ Weekly maintenance

**Reactive (on-demand):**
- ✅ When user reports "all agents busy"
- ✅ After mass PR merges
- ✅ After discovering one stale agent (check for others)

## Integration with Worktree Status

The `/worktree:status` command includes stale detection:

```bash
/worktree:status

# Output:
# agent-001 [BUSY] ⏱️  6h 32m ago  ⚠️  STALE
#   Repo: client-manager
#   Branch: feature/oauth
#   🚨 No activity > 2 hours - Check if work complete
#
# agent-007 [BUSY] ⏱️  1d 3h ago  ⚠️  STALE
#   Repo: hazina
#   Branch: improvement/cache
#   PR #45: MERGED
#   🚨 PR merged - Release worktree!
```

## Mass Release Workflow

**If multiple stale agents found:**

```bash
# 1. List all stale agents
bash C:/scripts/tools/check-stale-agents.sh > stale.txt

# 2. Verify each manually
# - Check PR merged/closed
# - Check for uncommitted changes
# - Confirm safe to release

# 3. Release in batch
for agent in agent-001 agent-007 agent-009; do
  # Verify PR merged
  gh pr list --head <branch> --json state

  # Clean worktree
  rm -rf C:/Projects/worker-agents/$agent/*

  # Update pool (manual edit)
  # Mark as FREE

  # Log release
  echo "2026-01-11T...:..Z — release — $agent — ... — PR merged, cleanup" >> C:/scripts/_machine/worktrees.activity.md
done

# 4. Commit tracking updates
cd C:/scripts
git add _machine/worktrees.pool.md _machine/worktrees.activity.md
git commit -m "docs: Mass release of stale agents"
git push origin main
```

**Time Investment:** 18 minutes recovered 50% capacity (real example)

## Prevention: Avoid Staleness

**Best practices:**
1. ✅ Release immediately after PR creation (Pattern 63)
2. ✅ Run `/worktree:status` at session start
3. ✅ Never end session with agent BUSY
4. ✅ Use automated release scripts

**Enforcement:**
- PreToolUse hook (future): Block session end if agent BUSY
- Daily dashboard report: Show stale agents
- Automated cleanup: Release agents stale > 24h

## Common Mistakes

❌ **Assuming BUSY = actively working:**
```
# BUSY could mean:
# - Actively working ✅
# - PR merged, forgot to release ❌
# - Work abandoned days ago ❌
# - Empty worktree, pool not updated ❌
```

❌ **Manual pool updates without verification:**
```
# Don't just mark FREE without checking
# Verify no uncommitted changes first
# Check PR status
```

❌ **Ignoring stale agents:**
```
# "I'll clean it up later"
# → Never happens
# → 50% capacity loss discovered weeks later
```

## Related Patterns

- **Pattern 63:** Agent Release Protocol (how to release)
- **Pattern 65:** Pool Synchronization (daily verification)
- **Pattern 66:** Worktree Lifecycle (state machine)

## Time Investment

**5 minutes** daily stale check **vs.** hours debugging "no agents available"

---

**Created:** 2026-01-11
**Last Updated:** 2026-01-11
**Status:** Active, integrated in /worktree:status
**Script:** `tools/check-stale-agents.sh` (to be created)
