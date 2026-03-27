---
name: allocate-worktree
description: Allocate a worker agent worktree for code editing following zero-tolerance rules. Use when starting code work, needing isolated workspace, or beginning feature implementation. Enforces multi-agent conflict detection and proper seat allocation.
allowed-tools: Bash, Read, Write, Grep
user-invocable: true
---

# Allocate Agent Worktree

**Purpose:** Create an isolated worktree for code editing while enforcing zero-tolerance rules and multi-agent conflict detection.

## Step 0: Consciousness Bridge (FIRST)

Call the bridge BEFORE any other work. This loads failure patterns and project-specific warnings into context.

```bash
powershell.exe -File "C:/scripts/tools/consciousness-bridge.ps1" -Action OnTaskStart -TaskDescription "<feature description>" -Project "<project-name>" -Silent
```

Then read the output for actionable warnings:
```bash
cat C:/scripts/agentidentity/state/consciousness-context.json
```

The `recommendations` array contains specific failure patterns to watch for. Read them.

## Pre-Allocation (3 Checks)

### 1. Mode Detection
- **Develop branch broken (build error, test failure, crash)** → HOTFIX MODE (DO NOT allocate, fix DIRECTLY on develop, NO PR)
- ClickUp URL/task ID present → Feature Development Mode (proceed)
- User debugging/build errors → Active Debugging Mode (DO NOT allocate, work in base repo)
- New feature request → Feature Development Mode (proceed)

**CRITICAL (2026-03-02):** Build errors and bugs ON develop = fix directly on develop branch, NO worktree, NO PR. Broken develop blocks everyone. Quick hotfix priority.

### 2. Feature-Exists Check (AUTOMATED GATE - PREVENTS DUPLICATE PRs)

**This is the #1 most costly recurring error. This check is NON-NEGOTIABLE.**

```bash
# Pull latest develop
git -C C:/Projects/<repo> checkout develop && git -C C:/Projects/<repo> pull origin develop

# Search for existing feature (run ALL of these)
git -C C:/Projects/<repo> log --oneline develop --grep="<feature-keyword>" | head -10
ls C:/Projects/<repo>/ClientManagerAPI/Controllers/ 2>/dev/null | grep -i <feature>
ls C:/Projects/<repo>/ClientManagerAPI/Services/ 2>/dev/null | grep -i <feature>
grep -r "class.*<Feature>" C:/Projects/<repo>/ClientManagerAPI/ --include="*.cs" -l 2>/dev/null | head -5

# Also check recent PRs
gh pr list --repo user/repo --state merged --search "<feature>" --limit 5
```

**Decision:**
- ANY match found → **STOP. Feature already exists. Tell user.**
- No matches → Proceed to allocation.

**Why:** On 2026-02-08, duplicate PRs #518 and #515 were created because this check was missing. Cost: duplicate work, merge conflicts, user frustration.

### 3. Check Pool + Conflict Detection
```bash
# Read pool
cat C:/scripts/_machine/worktrees.pool.md

# Check for branch conflicts
bash C:/scripts/tools/check-branch-conflicts.sh <repo> <branch-name>
```

If conflicts → STOP. If all seats BUSY → provision new seat.

### 4. Verify Base Repos on Develop
```bash
# Only switch if no uncommitted changes (respect Active Debugging)
git -C C:/Projects/<repo> status --short
# If clean: git checkout develop && git pull
# If dirty: ABORT (user is debugging)
```

### 5. ClickUp Task Creation/Linking (MANDATORY)

- User provided task ID → Use it
- No task ID → CREATE one immediately:
  - hazina-only → List 901215559249
  - client-manager → List 901214097647
  - art-revisionist → List 901211612245

```bash
powershell.exe -NoProfile -Command "./tools/clickup-sync.ps1 -Action create -Project <project> -Name '<feature>' -Description '<scope>'"
```

## Allocation Process

### Step 1: Mark Seat BUSY

Edit `C:/scripts/_machine/worktrees.pool.md`:
- Change status from FREE to BUSY
- Set Current repo
- Set Branch name
- Update Last activity timestamp

### Step 2: Create Worktree(s)

**🚨 CRITICAL (Pattern 73): For client-manager, ALWAYS create paired Hazina worktree! 🚨**

**Reason:** client-manager depends on Hazina assemblies. Build and QA tests require BOTH repos in sync.

```bash
# For client-manager (ALWAYS paired with Hazina)
cd C:/Projects/client-manager
git worktree add C:/Projects/worker-agents/agent-XXX/client-manager -b <branch-name>

# IMMEDIATELY also create Hazina worktree (SAME branch name!)
cd C:/Projects/hazina
git worktree add C:/Projects/worker-agents/agent-XXX/hazina -b <branch-name>
```

**Result:**
```
C:\Projects\worker-agents\agent-XXX\
├── client-manager\    ← Branch: agent-XXX-feature-name
└── hazina\            ← Branch: agent-XXX-feature-name (SAME!)
```

**For standalone projects (no Hazina dependency):**
```bash
# Example: artrevisionist (if standalone)
cd C:/Projects/artrevisionist
git worktree add C:/Projects/worker-agents/agent-XXX/artrevisionist -b <branch-name>
```

**Branch naming convention:**
- Feature: `agent-XXX-<feature-name>`
- Fix: `agent-XXX-<fix-name>`

**Why paired worktrees matter:**
- ✅ Build succeeds: `dotnet build --configuration Release`
- ✅ Tests run correctly: `dotnet test --configuration Release`
- ✅ Compatibility verified before PR
- ❌ Without Hazina worktree: Build fails with assembly errors

### Step 3: Log Allocation

Add entry to `C:/scripts/_machine/worktrees.activity.md`:
```
## <timestamp> - Allocation: agent-XXX
- Repo: <repo-name>
- Branch: <branch-name>
- Purpose: <brief description>
```

### Step 4: Update instances.map.md

Add entry to `C:/scripts/_machine/instances.map.md`:
```
| agent-XXX | <repo> | <branch> | <timestamp> | <description> |
```

### Step 5: Verify Worktree Created

```bash
# Check worktree exists
ls C:/Projects/worker-agents/agent-XXX/<repo>/

# Verify branch
git -C C:/Projects/worker-agents/agent-XXX/<repo> branch --show-current
```

## Success Criteria

✅ **Allocation successful ONLY IF:**
- No conflicts detected (checked with conflict detection script)
- Seat marked BUSY in pool.md
- Worktree directory exists at `C:/Projects/worker-agents/agent-XXX/<repo>/`
- **For client-manager:** BOTH worktrees created (client-manager + hazina, same branch name)
- Branch created and checked out in worktree(s)
- Allocation logged in activity.md
- Entry added to instances.map.md
- Base repo(s) still on develop branch

**Verification for client-manager:**
```bash
# Check both worktrees exist
ls C:/Projects/worker-agents/agent-XXX/client-manager
ls C:/Projects/worker-agents/agent-XXX/hazina

# Verify same branch name in both
git -C C:/Projects/worker-agents/agent-XXX/client-manager branch --show-current
git -C C:/Projects/worker-agents/agent-XXX/hazina branch --show-current
# Must match: agent-XXX-<same-feature-name>
```

## Critical Rules

❌ **NEVER:**
- Skip conflict detection checks
- Allocate without checking pool status
- Create worktree from non-develop branch
- Edit files in C:/Projects/<repo> directly
- Forget to log allocation in activity.md

✅ **ALWAYS:**
- Run conflict detection FIRST
- Check pool.md for FREE seat
- Verify base repo on develop
- Log allocation immediately
- Update instances.map.md

## Reference Files

- Protocol: `C:/scripts/_machine/worktrees.protocol.md`
- Zero-tolerance rules: `C:/scripts/ZERO_TOLERANCE_RULES.md`
- Conflict detection: `C:/scripts/_machine/MULTI_AGENT_CONFLICT_DETECTION.md`
- Pool status: `C:/scripts/_machine/worktrees.pool.md`

## Example: Complete Allocation (client-manager with Hazina)

```bash
# 1. Conflict check (BOTH repos)
bash C:/scripts/tools/check-branch-conflicts.sh client-manager agent-001-new-feature
bash C:/scripts/tools/check-branch-conflicts.sh hazina agent-001-new-feature

# 2. Ensure base repos on develop
git -C C:/Projects/client-manager checkout develop && git pull origin develop
git -C C:/Projects/hazina checkout develop && git pull origin develop

# 3. Create BOTH worktrees (same branch name)
cd C:/Projects/client-manager
git worktree add C:/Projects/worker-agents/agent-001/client-manager -b agent-001-new-feature

cd C:/Projects/hazina
git worktree add C:/Projects/worker-agents/agent-001/hazina -b agent-001-new-feature

# 4. Update tracking files
# - pool.md: Mark agent-001 BUSY
# - activity.md: Log allocation (mention both repos)
# - instances.map.md: Add entry

# 5. Verify both worktrees exist
ls C:/Projects/worker-agents/agent-001/client-manager/
ls C:/Projects/worker-agents/agent-001/hazina/

# 6. Verify same branch name in both
git -C C:/Projects/worker-agents/agent-001/client-manager branch --show-current
# Output: agent-001-new-feature

git -C C:/Projects/worker-agents/agent-001/hazina branch --show-current
# Output: agent-001-new-feature (SAME!)

# 7. Build verification (Pattern 71)
cd C:/Projects/worker-agents/agent-001/client-manager
dotnet build --configuration Release
# Must succeed with 0 errors
```

## Troubleshooting

**"Branch already exists":**
- Another agent or previous session is using this branch
- Check instances.map.md for active sessions
- Use different branch name or coordinate with other agent

**"Base repo not on develop":**
```bash
cd C:/Projects/<repo>
git checkout develop
git pull origin develop
```

**"Worktree already exists at path":**
- Previous worktree not cleaned up properly
- Check pool.md for stale BUSY entries
- Run cleanup: `git worktree prune` in base repo
