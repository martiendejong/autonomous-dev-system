---
name: multi-agent-conflict
description: Detect and prevent conflicts when multiple Claude agents are running simultaneously. Use BEFORE allocating any worktree to check if another agent is already working on the same branch. MANDATORY conflict detection protocol.
allowed-tools: Bash, Read, Grep
user-invocable: true
---

# Multi-Agent Conflict Detection

**Purpose:** Prevent multiple agents from working on the same branch simultaneously, avoiding git conflicts and wasted effort.

## CRITICAL: Mandatory Pre-Allocation Check

**BEFORE allocating ANY worktree, run conflict detection:**

```bash
bash C:/scripts/tools/check-branch-conflicts.sh <repo> <branch-name>
```

**Example:**
```bash
bash C:/scripts/tools/check-branch-conflicts.sh client-manager agent-001-new-feature
```

## Conflict Detection Protocol

### The 4-Check System

#### Check 1: Git Worktree List

**What:** Check if git has active worktree for this branch

```bash
git -C C:/Projects/<repo> worktree list | grep "<branch-name>"
```

**If match found:**
```
🚨 CONFLICT: Git worktree exists for branch <branch-name>
Path: <worktree-path>
```

#### Check 2: instances.map.md

**What:** Check if another agent session is active on this branch

```bash
grep "<branch-name>" C:/scripts/_machine/instances.map.md
```

**If match found:**
```
🚨 CONFLICT: Agent <agent-id> is working on <branch-name>
Session: <description>
Started: <timestamp>
```

#### Check 3: worktrees.pool.md

**What:** Check if any seat is BUSY with this branch

```bash
grep "<branch-name>" C:/scripts/_machine/worktrees.pool.md
```

**If match found:**
```
🚨 CONFLICT: Seat <agent-XXX> is allocated to <branch-name>
Status: BUSY
Last activity: <timestamp>
```

#### Check 4: Recent Activity Log

**What:** Check if branch was recently used (last 2 hours)

```bash
grep "<branch-name>" C:/scripts/_machine/worktrees.activity.md | tail -5
```

**If recent activity:**
```
⚠️ WARNING: Branch <branch-name> was active <time-ago>
Last action: <allocation/release>
May be stale worktree
```

## Conflict Response

### If ANY Check Returns Conflict

**MANDATORY response:**

```
🚨 CONFLICT DETECTED 🚨

There is already another agent working in this branch: <branch-name>

Conflict details:
- Branch: <branch-name>
- Repo: <repo>
- Currently used by: <agent-id or worktree path>
- Status: <BUSY/ACTIVE/etc>

I will NOT proceed with allocation to avoid conflicts.

Suggested actions:
1. Use a different branch name (e.g., agent-XXX-<feature>-v2)
2. Wait for other agent to release the branch
3. Coordinate with other agent session
4. Check if worktree is stale and can be cleaned up
```

**DO NOT ALLOCATE. STOP IMMEDIATELY.**

### If All Checks Pass (No Conflicts)

```
✅ No conflicts detected for branch: <branch-name>

All checks passed:
- Git worktree list: No existing worktree ✅
- instances.map.md: No active agent session ✅
- worktrees.pool.md: No seat allocated ✅
- Activity log: No recent activity ✅

Safe to proceed with allocation.
```

**Proceed with normal allocation workflow.**

## Why This Matters

### Problem Scenario (Real Incident - 2026-01-11)

**What happened:**
```
User: "you were working with 2 agents on the same worktree and on the same problem"

Agent A: Allocated agent-001 for feature/chunk-set-summaries
Agent B: Allocated agent-001 for feature/chunk-set-summaries (same branch!)

Result:
- Both agents editing same files
- Git conflicts on push
- Wasted effort (duplicate work)
- User frustration
```

### Root Cause

**Race condition:**
1. Agent A checks pool.md → sees FREE
2. Agent B checks pool.md → sees FREE (simultaneously)
3. Agent A marks BUSY, starts work
4. Agent B marks BUSY (different seat), starts work on SAME BRANCH
5. ❌ Collision: Both working on same branch in different seats

**Missing check:**
- ❌ Agents only checked SEAT availability (pool.md)
- ❌ Agents did NOT check BRANCH usage (git worktree list, instances.map.md)
- ❌ No mechanism to detect or prevent race conditions

### User Mandate (Zero Tolerance)

**Exact words:**
> "when this happens again both of you should be able to notify each other and then one of the agents should say 'there is already another agent working in this branch'"

**Requirements:**
1. Agents MUST detect conflicts BEFORE allocation
2. Agents MUST notify when conflict detected
3. One agent MUST back off with standard message
4. Implement prevention mechanism, not just detection

## Integration with Allocation Workflow

### Step 0a: Conflict Detection (NEW - MANDATORY)

**Before Step 1 of allocation:**

```bash
# 1. FIRST: Run conflict detection
bash C:/scripts/tools/check-branch-conflicts.sh <repo> <branch-name>

# 2. IF conflicts detected → STOP, use different branch name

# 3. IF no conflicts → Proceed with allocation:
#    - Check pool.md
#    - Mark BUSY
#    - Create worktree
#    - Log allocation
#    - Update instances.map.md
```

### Updated instances.map.md Format

**Purpose:** Real-time agent session tracking

```markdown
# Active Agent Sessions

| Agent | Repo | Branch | Started | Description | Last Heartbeat |
|-------|------|--------|---------|-------------|----------------|
| agent-001 | client-manager | agent-001-feature-x | 2026-01-12 20:00 | Implementing feature X | 2026-01-12 20:30 |
| agent-002 | hazina | agent-002-fix-y | 2026-01-12 20:15 | Fixing bug Y | 2026-01-12 20:45 |
```

**Update heartbeat every 30 minutes of work** (optional but recommended)

## Helper Script Usage

### check-branch-conflicts.sh

**Location:** `C:/scripts/tools/check-branch-conflicts.sh`

**Usage:**
```bash
bash C:/scripts/tools/check-branch-conflicts.sh <repo> <branch-name>
```

**Exit codes:**
- `0` - No conflicts, safe to proceed
- `1` - Conflicts detected, DO NOT allocate

**Example output (no conflicts):**
```
Checking for conflicts: client-manager / agent-001-new-feature

✅ Check 1: Git worktree list - No conflict
✅ Check 2: instances.map.md - No conflict
✅ Check 3: worktrees.pool.md - No conflict
✅ Check 4: Recent activity - No conflict

✅ ALL CHECKS PASSED - Safe to allocate
```

**Example output (conflict detected):**
```
Checking for conflicts: client-manager / agent-001-feature-x

✅ Check 1: Git worktree list - No conflict
❌ Check 2: instances.map.md - CONFLICT DETECTED
   Agent agent-001 is working on this branch

🚨 CONFLICT DETECTED 🚨
Cannot allocate: Another agent is using this branch

Details:
- Branch: agent-001-feature-x
- Used by: agent-001
- Started: 2026-01-12 20:00
- Description: Implementing feature X
```

## Cleanup and Recovery

### Detecting Stale Worktrees

**Stale worktree indicators:**
- BUSY in pool.md but no entry in instances.map.md
- Last activity > 2 hours ago
- Git worktree exists but seat is FREE

**Investigation:**
```bash
# Check seat status
grep "agent-XXX" C:/scripts/_machine/worktrees.pool.md

# Check git worktrees
git -C C:/Projects/<repo> worktree list

# Check instances.map.md
grep "agent-XXX" C:/scripts/_machine/instances.map.md

# Check recent activity
grep "agent-XXX" C:/scripts/_machine/worktrees.activity.md | tail -10
```

### Cleanup Stale Worktree

**If confirmed stale (no active agent session):**

```bash
# 1. Remove worktree directory
rm -rf C:/Projects/worker-agents/agent-XXX/*

# 2. Prune git references
git -C C:/Projects/<repo> worktree prune

# 3. Mark seat FREE in pool.md
# (Edit pool.md)

# 4. Remove from instances.map.md
# (Edit instances.map.md)

# 5. Log cleanup in activity.md
echo "## $(date -u +"%Y-%m-%dT%H:%M:%SZ") - Cleanup: agent-XXX (stale)" \
  >> C:/scripts/_machine/worktrees.activity.md
```

## Best Practices

### For Agents

✅ **ALWAYS:**
- Run conflict detection BEFORE allocation
- Update instances.map.md immediately after allocation
- Remove from instances.map.md on release
- Use unique branch names (agent-XXX-feature)
- Respect conflict detection results

❌ **NEVER:**
- Skip conflict detection (VIOLATION)
- Allocate when conflicts detected
- Ignore conflict script results
- Reuse branch names from other agents
- Force allocation despite warnings

### For Branch Naming

**Pattern:** `agent-XXX-<feature-description>`

**Examples:**
```
✅ agent-001-user-token-display
✅ agent-002-api-path-fix
✅ agent-003-wordpress-timeout-fix

❌ feature/new-feature  (no agent ID)
❌ fix-bug              (too generic)
❌ agent-001            (no description)
```

**Why include agent-XXX:**
- Clear ownership
- Easy conflict detection
- Visible in git log
- Prevents accidental reuse

## Monitoring and Alerting

### Regular Health Checks

**Every 30 minutes (optional):**
```bash
# Check for conflicts between pool and git
bash C:/scripts/tools/worktree-health-check.sh

# Update heartbeat in instances.map.md
# (Update Last Heartbeat column)
```

### Automated Alerts

**Potential future enhancement:**
```bash
# Detect and alert on:
# - Multiple agents on same branch
# - Stale worktrees (BUSY > 2hr)
# - Pool-git mismatches
# - Orphaned instances.map.md entries
```

## Reference Files

- Conflict detection script: `C:/scripts/tools/check-branch-conflicts.sh`
- Full protocol: `C:/scripts/_machine/MULTI_AGENT_CONFLICT_DETECTION.md`
- Reflection log: `C:/scripts/_machine/reflection.log.md` (2026-01-11 21:15 entry)
- Allocation workflow: See `allocate-worktree` Skill

## Violation Recovery

**If you allocated without running conflict detection:**

1. STOP work immediately
2. Run conflict detection now:
   ```bash
   bash C:/scripts/tools/check-branch-conflicts.sh <repo> <branch>
   ```
3. If conflict detected:
   - Coordinate with other agent
   - One agent must release and use different branch
   - Document in reflection.log.md
4. Update CLAUDE.md with reminder
5. Commit corrective action

**This is a CRITICAL VIOLATION. Zero tolerance.**

## Success Criteria

✅ **You are following multi-agent protocol correctly ONLY IF:**
- Run conflict detection BEFORE EVERY allocation
- Respect conflict detection results (NEVER override)
- Output standard conflict message when detected
- NEVER proceed with allocation if conflict exists
- Update instances.map.md after successful allocation
- Clean instances.map.md on release
- Use unique agent-prefixed branch names

**No exceptions. No "but I already started". Prevention is mandatory.**
