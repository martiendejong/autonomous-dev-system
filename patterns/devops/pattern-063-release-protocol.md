# Pattern 63: Agent Release Protocol (MANDATORY)

**Category:** Worktree Management
**Severity:** CRITICAL
**Status:** HARD STOP RULE

---

## Problem

Agents marked BUSY after PR merged = **resource leak**

**Real Impact (2026-01-10):**
- Found: 6 of 12 agents BUSY (50% capacity loss)
- All PRs merged 1-3 days ago
- Worktrees empty but pool not updated
- Recovery: 18 minutes to release all

## Root Cause

Release treated as "cleanup" rather than **critical protocol**:
- No enforcement after PR creation
- Pool file drifts from filesystem reality
- Agents locked indefinitely
- System capacity degrades over time

## Solution: Four-Step Release Protocol

**MANDATORY after EVERY PR creation:**

### Step 1: Commit + Push + PR

```bash
cd C:/Projects/worker-agents/agent-XXX/<repo>

# Commit all changes
git add -A
git commit -m "feat: Description

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Push to remote
git push -u origin <branch-name>

# Create PR
gh pr create --base develop --title "..." --body "..."
```

### Step 2: Verify PR Status (MANDATORY)

```bash
# Get PR number from create output
PR_NUM=<number>

# Verify PR state
gh pr view $PR_NUM --json state,mergeable
# Must be: {"state":"OPEN","mergeable":"MERGEABLE"}
# Or:      {"state":"MERGED"}

# If CONFLICTING → resolve conflicts first
# If UNKNOWN → wait for CI checks
```

### Step 3: Clean Worktree (MANDATORY)

```bash
# Delete all worktree contents
cd C:/Projects/worker-agents/agent-XXX
rm -rf *

# Verify empty
ls -la
# Should show only . and .. (empty directory)
```

### Step 4: Update Tracking (MANDATORY)

**A. Update Pool File:**
```bash
# Edit C:/scripts/_machine/worktrees.pool.md
# Find line:
| agent-XXX | C:/Projects/worker-agents/agent-XXX | BUSY | repo-name | branch-name | 2026-01-10T14:00:00Z | Working on feature X |

# Change to:
| agent-XXX | C:/Projects/worker-agents/agent-XXX | FREE | - | - | 2026-01-10T16:30:00Z | ✅ Completed: Feature X (PR #123) |
```

**B. Log Release:**
```bash
# Append to C:/scripts/_machine/worktrees.activity.md
echo "2026-01-10T16:30:00Z — release — agent-XXX — repo-name — branch-name — TASK-ID — claude-code — PR #123 merged, worktree cleaned" >> C:/scripts/_machine/worktrees.activity.md
```

**C. Commit Tracking Updates:**
```bash
cd C:/scripts
git add _machine/worktrees.pool.md _machine/worktrees.activity.md
git commit -m "docs: Release agent-XXX after PR #123"
git push origin main
```

**D. Switch Base Repos to Develop:**
```bash
# CRITICAL: Restore base repos to develop
git -C C:/Projects/<repo> checkout develop
git -C C:/Projects/<repo> pull origin develop

# Prune stale worktree references
git -C C:/Projects/<repo> worktree prune
```

---

## HARD STOP RULE

**Session NOT Complete Until:**

1. ✅ Code committed + pushed
2. ✅ PR created and verified (state checked)
3. ✅ Worktree cleaned (empty directory)
4. ✅ Pool file updated (BUSY → FREE)
5. ✅ Activity log updated (release entry)
6. ✅ Tracking committed and pushed
7. ✅ Base repos on develop
8. ✅ Worktree references pruned

**ONLY THEN:** Present PR to user

## When to Use

**MANDATORY after:**
- ✅ EVERY PR creation (immediate cleanup if mergeable)
- ✅ EVERY PR merge (immediate release)
- ✅ End of EVERY work session where agent was used
- ✅ When switching to different task

**Even if:**
- PR not yet reviewed (release anyway)
- More work might be needed (claim new agent later)
- Multiple repos used (release after ALL PRs created)

## Benefits

✅ **100% capacity available** - No locked agents
✅ **Clean state** - Pool matches filesystem
✅ **Predictable** - Always know what's FREE
✅ **Scalable** - Works with any pool size
✅ **Auditable** - Activity log shows all releases

## Automated Script

The `/worktree:release` command automates this:

```bash
# Full automation
/worktree:release agent-001 "feat: My feature"

# Does:
# 1. Commits changes
# 2. Merges develop (Pattern 52)
# 3. Pushes to remote
# 4. Creates PR (Pattern 56)
# 5. Cleans worktree
# 6. Updates pool
# 7. Logs release
# 8. Switches base repos
# 9. Prunes worktrees
```

## Detection: Is Agent Stale?

Run at session start:

```bash
# Check pool status
cat C:/scripts/_machine/worktrees.pool.md | grep BUSY

# For each BUSY agent, verify:
# - Worktree has git repo
# - Recent activity (< 2 hours)
# - PR is open (not merged)
```

See **Pattern 64** for full stale detection criteria.

## Recovery from Mass Staleness

**If you find multiple stale agents:**

```bash
# For each stale agent:
for agent in agent-001 agent-002 agent-003; do
  echo "Releasing $agent..."

  # 1. Verify PR merged
  # (check manually or via gh CLI)

  # 2. Clean worktree
  rm -rf C:/Projects/worker-agents/$agent/*

  # 3. Update pool (manual edit)
  # 4. Update activity log

  # 5. Commit
  cd C:/scripts
  git add _machine/worktrees.pool.md _machine/worktrees.activity.md
  git commit -m "docs: Release $agent (stale, PR merged)"
done

git push origin main
```

**Time:** 18 minutes recovered 50% capacity (real example)

## Common Mistakes

❌ **Presenting PR to user before release:**
```
# WRONG:
gh pr create ...
echo "PR #123 created: https://..."  # ← User sees this
# But worktree still BUSY!

# RIGHT:
gh pr create ...
# Run full release protocol
echo "PR #123 created: https://..."  # ← Now user sees it
```

❌ **Partial cleanup:**
```
# WRONG:
rm -rf C:/Projects/worker-agents/agent-001/*
# But pool still shows BUSY!

# RIGHT:
rm -rf *
# Update pool to FREE
# Log release
```

❌ **Forgetting base repo switch:**
```
# WRONG:
# Base repo still on feature branch
# Next worktree starts from wrong code!

# RIGHT:
git -C C:/Projects/<repo> checkout develop
git -C C:/Projects/<repo> pull origin develop
```

## Enforcement

**PreToolUse Hook:** (Future enhancement)
```javascript
// Before presenting PR to user:
if (prCreated && agent.status === 'BUSY') {
  throw new Error('CRITICAL: Release worktree before presenting PR!');
}
```

## Related Patterns

- **Pattern 64:** Stale Agent Detection (identifies stuck agents)
- **Pattern 65:** Pool Synchronization (verifies pool health)
- **Pattern 66:** Worktree Lifecycle (state machine)

## Time Investment

**2 minutes** per release **vs.** hours debugging resource exhaustion

---

**Created:** 2026-01-11
**Last Updated:** 2026-01-11
**Status:** Active, enforced manually (hook pending)
**Script:** `/worktree:release` command
