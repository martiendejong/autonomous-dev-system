---
name: worktree-status
description: Check worktree pool status, available seats, active allocations, and system health. Use when checking capacity, debugging allocation issues, or starting session.
allowed-tools: Bash, Read, Grep
user-invocable: true
---

# Worktree Status Dashboard

**Purpose:** Display current state of worktree pool, identify available seats, and check for issues.

## Quick Status Check

```bash
# Run the comprehensive dashboard
bash C:/scripts/tools/repo-dashboard.sh
```

This shows:
- Base repo branch status
- Worktree pool allocations
- Recent activity
- Pending PRs
- System health

## Manual Status Checks

### 1. Pool Status

```bash
cat C:/scripts/_machine/worktrees.pool.md
```

**Look for:**
- FREE seats (available for allocation)
- BUSY seats (currently in use)
- STALE seats (BUSY > 2 hours with no activity)
- BROKEN seats (need manual cleanup)

### 2. Active Worktrees (Git View)

```bash
# Check client-manager worktrees
git -C C:/Projects/client-manager worktree list

# Check hazina worktrees
git -C C:/Projects/hazina worktree list
```

**This shows actual git worktree state** (source of truth).

### 3. Active Agent Sessions

```bash
cat C:/scripts/_machine/instances.map.md
```

Shows which agents are working on which branches.

### 4. Recent Activity

```bash
tail -n 50 C:/scripts/_machine/worktrees.activity.md
```

Shows recent allocations and releases.

### 5. Base Repo Branch Check

```bash
# Check current branches
git -C C:/Projects/client-manager branch --show-current
git -C C:/Projects/hazina branch --show-current
```

**Should ALWAYS be:** `develop`

**If not:**
```bash
cd C:/Projects/<repo>
git checkout develop
git pull origin develop
```

## Health Checks

### Check for Stale Allocations

```bash
grep "BUSY" C:/scripts/_machine/worktrees.pool.md
```

**If BUSY > 2 hours ago:**
- Check instances.map.md for active session
- Check worktrees.activity.md for last update
- If no activity, mark as STALE and investigate

### Check for Orphaned Worktrees

```bash
# Compare git worktree list with pool.md
git -C C:/Projects/client-manager worktree list | grep agent-
```

**If worktree exists but seat is FREE:**
- Stale worktree not cleaned up properly
- Run cleanup procedure

### Check for Pool-Git Mismatches

**Pool says BUSY but git worktree list shows nothing:**
- Pool.md not updated after release
- Manually mark FREE

**Git shows worktree but pool says FREE:**
- Allocation not logged properly
- Investigate and clean up

## Capacity Planning

### Count Available Seats

```bash
grep -c "FREE" C:/scripts/_machine/worktrees.pool.md
```

### Count Active Sessions

```bash
grep -c "BUSY" C:/scripts/_machine/worktrees.pool.md
```

### Provision New Seat (If Needed)

If all seats BUSY and you need to allocate:

1. Find highest agent number:
```bash
grep "agent-" C:/scripts/_machine/worktrees.pool.md | tail -1
```

2. Add new row to pool.md with next number (e.g., agent-013)

3. Set status to FREE

4. Log provisioning in activity.md

## Conflict Detection

### Check if Branch Already Allocated

```bash
# Search pool.md for branch name
grep "<branch-name>" C:/scripts/_machine/worktrees.pool.md

# Search instances.map.md
grep "<branch-name>" C:/scripts/_machine/instances.map.md

# Check git worktrees
git -C C:/Projects/<repo> worktree list | grep "<branch-name>"
```

**If ANY match found:** Branch is in use, cannot allocate.

## Common Status Patterns

### Healthy System
```
All base repos on develop ✅
0-2 BUSY seats
No STALE or BROKEN seats
instances.map.md matches pool.md BUSY count
```

### Needs Cleanup
```
Base repo NOT on develop ⚠️
Multiple STALE seats (BUSY > 2hr)
instances.map.md doesn't match pool.md
Orphaned worktrees in git worktree list
```

### Critical Issues
```
All seats BUSY (no capacity) 🚨
BROKEN seats blocking allocations
Merge conflicts in tracking files
Base repo on feature branch
```

## Cleanup Procedures

### Clean Stale Worktree

```bash
# 1. Remove worktree directory
rm -rf C:/Projects/worker-agents/agent-XXX/*

# 2. Prune git references
git -C C:/Projects/<repo> worktree prune

# 3. Mark seat FREE in pool.md

# 4. Remove from instances.map.md

# 5. Log cleanup in activity.md
```

### Fix Base Repo Branch

```bash
cd C:/Projects/<repo>
git checkout develop
git pull origin develop
```

### Recover from Tracking File Conflicts

```bash
cd C:/scripts
git pull origin main
# Resolve conflicts manually
git add _machine/*.md
git commit -m "fix: Resolve tracking file conflicts"
git push origin main
```

## Reference Files

- Pool: `C:/scripts/_machine/worktrees.pool.md`
- Activity: `C:/scripts/_machine/worktrees.activity.md`
- Instances: `C:/scripts/_machine/instances.map.md`
- Protocol: `C:/scripts/_machine/worktrees.protocol.md`

## Status Report Template

When reporting status to user:

```
📊 Worktree Pool Status

Available Seats: X FREE
Active Allocations: Y BUSY
Base Repos: client-manager (develop ✅), hazina (develop ✅)

Active Sessions:
- agent-XXX: <repo> / <branch> - <description>

Recent Activity:
- <timestamp>: agent-YYY released (PR #123)
```

## Integration with Session Start

**ALWAYS run at session start:**

```bash
# 1. Dashboard overview
bash C:/scripts/tools/repo-dashboard.sh

# 2. Verify base repos
git -C C:/Projects/client-manager branch --show-current
git -C C:/Projects/hazina branch --show-current

# 3. Check pool for FREE seats
grep "FREE" C:/scripts/_machine/worktrees.pool.md | head -5
```

This ensures you understand system state before allocating.
