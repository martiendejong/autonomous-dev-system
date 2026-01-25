# Worktree Protocol - Complete Guide (Portable)

**VERSION:** 1.0 (Portable)
**PURPOSE:** Complete worktree allocation, usage, and release protocol
**PORTABILITY:** Uses variables defined in `MACHINE_CONFIG.md` (not included in plugin copy)
**APPLIES TO:** Feature Development Mode only (see GENERAL_DUAL_MODE_WORKFLOW.md)

---

## 🎯 Overview

**Worktrees enable multiple agents to work on different features simultaneously without conflicts.**

- **Base Repository** (`${BASE_REPO_PATH}/<repo>`) - Stays on main branch, read-only for code edits
- **Worktrees** (`${WORKTREE_PATH}/agent-XXX/<repo>`) - Isolated working directories per agent

---

## ⚠️ CRITICAL: Pre-Flight Checklist

**BEFORE ANY CODE EDIT in Feature Development Mode:**

```
□ Am I in Feature Development Mode? (not Active Debugging)
□ Have I read ${MACHINE_CONTEXT_PATH}/worktrees.pool.md?
□ Have I marked a seat BUSY?
□ Am I editing in ${WORKTREE_PATH}/agent-XXX/<repo>? (NOT ${BASE_REPO_PATH}/<repo>)
□ Do I know which worktree I'm using?

IF ANY ☐ = NO → STOP! ALLOCATE FIRST!
```

---

## 🔒 The Problem

When multiple agents run in parallel, they MUST NOT share the same worktree. Each agent MUST have its own isolated worktree to prevent:
- Git conflicts
- Simultaneous edits to same files
- Branch corruption
- Lost work

---

## ✅ The Solution: Atomic Allocation

### Step-by-Step Protocol

**0. Multi-Agent Conflict Check (MANDATORY)**
```bash
# Check if another agent is already working on this branch
bash ${CONTROL_PLANE_PATH}/tools/check-branch-conflicts.sh <repo> <branch-name>
# If script exits with error → STOP IMMEDIATELY
# Output: "There is already another agent working in this branch"
```

**1. Ensure Base Repo is Clean and Up-to-Date**
```bash
cd ${BASE_REPO_PATH}/<repo>

# Fetch latest refs
git fetch origin --prune

# Check current branch
branch=$(git branch --show-current)

# Switch to main branch if needed
if [ "$branch" != "<main-branch>" ]; then
    git checkout <main-branch>
fi

# Pull latest changes
git pull origin <main-branch>

# Base repo MUST ALWAYS be on main branch with latest code
# It's the foundation for all worktrees
```

**2. Read Pool and Find FREE Seat**
```bash
# Read the worktree pool status
Read ${MACHINE_CONTEXT_PATH}/worktrees.pool.md

# Find a FREE seat (agent-001, agent-002, etc.)
# If NO FREE seat → Provision new agent-00(N+1)
```

**3. Mark Seat BUSY (Atomic Lock)**
```bash
# Update pool.md IMMEDIATELY:
# - Status: FREE → BUSY
# - Current repo: <repo-name>
# - Branch: agent-XXX-<feature>
# - Last activity: <timestamp>
# - Notes: <task description>

# This LOCKS the seat for you
```

**4. Log Allocation**
```bash
# Append to activity log
echo "<timestamp> — allocate — agent-XXX — <repo> — <branch> — — claude-code — <description>" >> ${MACHINE_CONTEXT_PATH}/worktrees.activity.md
```

**5. Update Instance Mapping** (if using multi-agent system)
```bash
# Update ${MACHINE_CONTEXT_PATH}/instances.map.md
# Map current Claude instance ID to agent-XXX seat
```

**6. Create/Update Worktree**
```bash
# Create new worktree with feature branch
git worktree add ${WORKTREE_PATH}/agent-XXX/<repo> -b agent-XXX-<feature>

# If worktree already exists but needs new branch:
cd ${WORKTREE_PATH}/agent-XXX/<repo>
git checkout -b agent-XXX-<new-feature>
```

**7. Copy Configuration Files**
```bash
# Copy runtime config files from base repo (if needed)
cp ${BASE_REPO_PATH}/<repo>/appsettings.json ${WORKTREE_PATH}/agent-XXX/<repo>/
cp ${BASE_REPO_PATH}/<repo>/.env ${WORKTREE_PATH}/agent-XXX/<repo>/
# etc.
```

---

## 🚧 Work in Allocated Worktree

**Location:** `${WORKTREE_PATH}/agent-XXX/<repo>/`

**Rules:**
- ✅ Edit files in worktree
- ✅ Make commits in worktree
- ✅ Run tests in worktree
- ❌ DO NOT edit `${BASE_REPO_PATH}/<repo>` directly
- ❌ DO NOT switch branches in base repo

---

## 💓 Heartbeat Updates (Every 30 min)

```bash
# Update last activity timestamp in pool.md
# Append checkin to activity.md
echo "<timestamp> — checkin — agent-XXX — <repo> — <branch> — — claude-code — Still working on <task>" >> ${MACHINE_CONTEXT_PATH}/worktrees.activity.md
```

---

## 🔄 Complete Workflow + Release

### Step 1: Commit All Work
```bash
cd ${WORKTREE_PATH}/agent-XXX/<repo>

git add -u
git commit -m "feat: implement <feature>"
```

### Step 2: Merge Main Branch (CRITICAL)
```bash
# ALWAYS merge main branch before creating PR
# This ensures code is up-to-date with latest changes
git fetch origin
git merge origin/<main-branch>

# Resolve any conflicts
# Re-run tests
# Commit merge if needed
```

### Step 3: Push to Remote
```bash
git push -u origin agent-XXX-<feature>
```

### Step 4: Create PR
```bash
# ALWAYS specify --base <main-branch>
gh pr create --base <main-branch> --title "feat: <description>" --body "..."

# Output: https://github.com/<owner>/<repo>/pull/<number>
```

### Step 5: Verify Base Branch (CRITICAL)
```bash
# Immediately verify PR base branch
gh pr view <number> --json baseRefName

# Must show: "baseRefName": "<main-branch>"
# If wrong base → close PR and recreate with correct base
```

### Step 6: Clean Worktree Directory (IMMEDIATE)
```bash
# IMMEDIATELY after PR creation
rm -rf ${WORKTREE_PATH}/agent-XXX/*
```

### Step 7: Update Pool Status (BUSY → FREE)
```bash
# Edit ${MACHINE_CONTEXT_PATH}/worktrees.pool.md
# - Status: BUSY → FREE
# - Current repo: (blank)
# - Branch: (blank)
# - Last activity: <timestamp>
# - Notes: "Released after PR #<number>"
```

### Step 8: Log Release
```bash
echo "<timestamp> — release — agent-XXX — <repo> — <branch> — — claude-code — PR #<number> created" >> ${MACHINE_CONTEXT_PATH}/worktrees.activity.md
```

### Step 9: Clear Instance Mapping
```bash
# Remove from ${MACHINE_CONTEXT_PATH}/instances.map.md
# Unmap current instance from agent-XXX
```

### Step 10: Commit Tracking Updates
```bash
cd ${CONTROL_PLANE_PATH}
git add _machine/worktrees.pool.md _machine/worktrees.activity.md _machine/instances.map.md
git commit -m "docs: Release agent-XXX after PR #<number>"
git push origin main
```

### Step 11: Switch Base Repos to Main Branch
```bash
# For EACH repo involved
git -C ${BASE_REPO_PATH}/<repo> checkout <main-branch>
git -C ${BASE_REPO_PATH}/<repo> pull origin <main-branch>
```

### Step 12: Prune Stale Worktree References
```bash
# For EACH repo involved
git -C ${BASE_REPO_PATH}/<repo> worktree prune
```

### Step 13: ONLY THEN Present PR to User
```
"PR #<number> created: <url>"
```

---

## 🔒 Concurrency Rules

1. **ONE AGENT PER WORKTREE** - A BUSY seat is LOCKED. No other agent may use it.
2. **ATOMIC ALLOCATION** - Read pool → Find FREE → Mark BUSY → Write pool (no gaps!)
3. **ALWAYS RELEASE** - Never leave seats BUSY when done
4. **AUTO-PROVISION** - If all seats BUSY, create agent-00(N+1) automatically

---

## 🚨 Critical Patterns

### Pattern 52: Merge Main Branch Before PR
```bash
# ALWAYS merge origin/<main-branch> into feature branch BEFORE creating PR
git fetch origin
git merge origin/<main-branch>
```

**Why?**
- Code is up-to-date with latest changes
- Conflicts resolved locally, not in GitHub
- Tests run against current codebase
- PR is clean and easy to review

### Pattern 56: Always Specify --base <main-branch>
```bash
# gh CLI defaults to main if not specified
# Your repo might use develop or another branch
gh pr create --base <main-branch> --title "..." --body "..."

# Verify immediately
gh pr view <number> --json baseRefName
```

**Why?**
- Wrong base = false conflicts + wrong merge target
- Catch errors immediately, not during review

---

## ⚠️ Common Mistakes

### ❌ Mistake 1: Editing Base Repo Directly
```bash
# WRONG (in Feature Development Mode)
cd ${BASE_REPO_PATH}/<repo>
# Edit files here ← VIOLATION!

# RIGHT
cd ${WORKTREE_PATH}/agent-XXX/<repo>
# Edit files here ✓
```

### ❌ Mistake 2: Presenting PR Before Releasing Worktree
```bash
# WRONG
gh pr create ...
# "PR #123 created!" ← User sees this while worktree still allocated

# RIGHT
gh pr create ...
rm -rf ${WORKTREE_PATH}/agent-XXX/*
# Update pool.md, log release, commit tracking
# THEN tell user about PR
```

### ❌ Mistake 3: Not Merging Main Branch Before PR
```bash
# WRONG
git push origin agent-XXX-feature
gh pr create  # ← Might have conflicts with develop!

# RIGHT
git fetch origin
git merge origin/<main-branch>  # Resolve conflicts NOW
git push origin agent-XXX-feature
gh pr create  # Clean PR ✓
```

### ❌ Mistake 4: Not Specifying PR Base Branch
```bash
# WRONG (gh defaults to main, but you might use develop)
gh pr create --title "..." --body "..."

# RIGHT
gh pr create --base develop --title "..." --body "..."
gh pr view <number> --json baseRefName  # Verify
```

---

## 📊 Success Criteria

**Feature Development Mode Success:**
- ✅ Worktree allocated before code edits
- ✅ All changes in worktree (ZERO in `${BASE_REPO_PATH}/<repo>`)
- ✅ Main branch merged before PR
- ✅ PR created with correct base branch
- ✅ Worktree released immediately after PR
- ✅ Base repos back on main branch
- ✅ Pool status accurate (FREE)
- ✅ Activity log complete (allocate → release)

---

## 🔧 Troubleshooting

### "All worktrees are BUSY"
→ Auto-provision new seat: agent-00(N+1)

### "Worktree already exists"
→ Check pool.md - if FREE, reuse it. If BUSY, conflict detection failed.

### "Branch already exists in another worktree"
→ Another agent is working on this. STOP. Don't create conflicts.

### Base repo not on main branch
→ `git -C ${BASE_REPO_PATH}/<repo> checkout <main-branch>`

### Stale worktree references
→ `git -C ${BASE_REPO_PATH}/<repo> worktree prune`

---

---

## 📚 See Also

**Related protocols:**
- **Dual-Mode Workflow:** `GENERAL_DUAL_MODE_WORKFLOW.md` - When to use worktrees vs direct editing
- **Zero Tolerance Rules:** `GENERAL_ZERO_TOLERANCE_RULES.md` - Pre-flight checklists
- **Git Workflow:** `git-workflow.md` - PR dependencies, branch cleanup, tagging
- **Definition of Done:** `C:\scripts\_machine\DEFINITION_OF_DONE.md` - Release criteria

**Automation tools:**
- **Worktree allocation:** `C:\scripts\tools\worktree-allocate.ps1`
- **Worktree release:** `C:\scripts\tools\worktree-release-all.ps1`
- **Worktree status:** `C:\scripts\tools\worktree-status.ps1`
- **Skills:** `C:\scripts\.claude\skills\allocate-worktree\`, `release-worktree\`, `worktree-status\`

**Version:** 1.0 (Portable)
**Last Updated:** 2026-01-25 (Added knowledge base and tool references)
**Maintained By:** Claude Community
**Portability:** This document uses variables - see MACHINE_CONFIG.md for local paths
