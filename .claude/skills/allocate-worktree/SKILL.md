---
name: allocate-worktree
description: Allocate a worker agent worktree for code editing following zero-tolerance rules. Use when starting code work, needing isolated workspace, or beginning feature implementation. Enforces multi-agent conflict detection and proper seat allocation.
allowed-tools: Bash, Read, Write, Grep
user-invocable: true
---

# Allocate Agent Worktree

**Purpose:** Create an isolated worktree for code editing while enforcing zero-tolerance rules and multi-agent conflict detection.

## MANDATORY Pre-Allocation Checks

### 0. Mode Detection (CRITICAL - FIRST CHECK)

**BEFORE doing ANYTHING, verify this is Feature Development Mode:**

```powershell
# Run mode detection on user's request
$mode = detect-mode.ps1 -UserMessage $userRequest

if ($mode -ne "FEATURE_DEVELOPMENT_MODE") {
    Write-Host "⚠️  Mode is $mode - DO NOT ALLOCATE WORKTREE" -ForegroundColor Red
    Write-Host "This is Active Debugging Mode - work in base repo instead" -ForegroundColor Yellow
    exit 1
}
```

**HARD RULE: ClickUp URL present → ALWAYS Feature Development Mode**

If user message contains:
- `clickup.com` URL
- Task ID like `869abc123`
- Any ClickUp reference

→ You MUST use Feature Development Mode (allocate worktree)

**Why this check exists:**
- 2026-01-20: Critical mistake where ClickUp task was treated as Debug Mode
- Resulted in direct base repo edits, no PR, no ClickUp link
- User mandate: "do not ever forget that again"

**This check prevents trust-breaking workflow violations.**

### 1. Read Zero-Tolerance Rules
```bash
# ALWAYS read first
cat C:/scripts/ZERO_TOLERANCE_RULES.md
```

### 2. ManicTime Coordination Check (MANDATORY)

**Get current agent activity context:**

```powershell
# Check how many Claude agents are running and their status
$context = monitor-activity.ps1 -Mode context -OutputFormat object

Write-Host "Active Claude Instances: $($context.ClaudeInstances.Count)"
Write-Host "User Attending: $($context.System.UserAttending)"
Write-Host "System Idle: $($context.IdleTime.IsIdle)"
```

**Store for later use:**
```powershell
$agentCount = $context.ClaudeInstances.Count
$userFocused = $context.System.UserAttending
$myPriority = if ($userFocused) { 100 } else { 50 }
```

**Coordination Strategy Selection:**
```powershell
if ($agentCount -lt 3) {
    Write-Host "✅ Low contention ($agentCount agents) - using optimistic allocation"
    $strategy = "optimistic"  # Fast path
} else {
    Write-Host "⚠️  High contention ($agentCount agents) - using pessimistic allocation"
    $strategy = "pessimistic"  # Slow path with jitter
    # Add random delay to reduce thundering herd
    Start-Sleep -Milliseconds (Get-Random -Minimum 0 -Maximum 500)
}
```

### 3. Multi-Agent Conflict Detection (CRITICAL)
Before allocating ANY worktree, check for conflicts:

```bash
# Run conflict detection script
bash C:/scripts/tools/check-branch-conflicts.sh <repo> <branch-name>
```

**If conflicts detected:**
```
🚨 CONFLICT DETECTED 🚨
There is already another agent working in this branch.

I will NOT proceed with allocation to avoid conflicts.
```

**STOP IMMEDIATELY. Do not allocate.**

### 4. Check Pool Status
```bash
cat C:/scripts/_machine/worktrees.pool.md
```

Find a FREE seat (agent-001, agent-002, etc.). If all BUSY, provision new seat.

### 5. Verify Base Repos on Develop
```bash
# Check client-manager
git -C C:/Projects/client-manager branch --show-current

# Check hazina
git -C C:/Projects/hazina branch --show-current
```

**If NOT on develop:**
```bash
cd C:/Projects/<repo>
git checkout develop
git pull origin develop
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
