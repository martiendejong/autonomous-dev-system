---
name: release-worktree
description: Release worktree after creating PR following zero-tolerance protocol. Use after gh pr create, before presenting PR to user. Ensures complete cleanup and proper state transitions.
allowed-tools: Bash, Read, Write, Grep
user-invocable: true
---

# Release Agent Worktree

**Purpose:** Clean up worktree, release seat, update tracking files, and return base repos to develop after PR creation.

## CRITICAL: When to Release

**Release IMMEDIATELY after:**
- ✅ Code changes committed
- ✅ Changes pushed to remote
- ✅ PR created with `gh pr create`

**BEFORE:**
- ❌ Presenting PR link to user
- ❌ Marking task as complete

## Release Protocol (Zero-Tolerance Checklist)

### Step 1: Verify PR Created

```bash
# Check PR exists on GitHub
gh pr view <pr-number> --repo <owner>/<repo>
```

**If no PR exists, CREATE IT FIRST before releasing.**

### Step 1.5: 🚨 MANDATORY: Update ClickUp Task with PR Link (NON-NEGOTIABLE!)

**CRITICAL: If this work originated from a ClickUp task, you MUST update it with the PR link.**

```bash
# Extract task ID from branch name (e.g., feature/869abc123-description)
branch=$(git -C C:/Projects/worker-agents/agent-XXX/<repo> branch --show-current)
taskId=$(echo $branch | grep -oP '\d\w{8}' | head -1)

if [ -n "$taskId" ]; then
  # Get PR number and URL
  prNumber=$(gh pr view --json number --jq .number)
  prUrl=$(gh pr view --json url --jq .url)

  # Update ClickUp task with PR link
  clickup-sync.ps1 -Action comment -TaskId $taskId -Comment "PR #${prNumber}: ${prUrl}"
  echo "✅ ClickUp task $taskId updated with PR link"
else
  echo "⚠️  No ClickUp task ID found in branch name - MANUAL UPDATE REQUIRED"
fi
```

**This step is MANDATORY and NON-NEGOTIABLE per user requirement.**

### Step 2: Clean Worktree Directory

```bash
# Remove ALL worktree contents
rm -rf C:/Projects/worker-agents/agent-XXX/*
```

**Why:** Prevents disk space accumulation, ensures clean slate for next allocation.

### Step 3: Mark Seat FREE

Edit `C:/scripts/_machine/worktrees.pool.md`:
- Change status from BUSY to FREE
- Clear Current repo field (set to `-`)
- Clear Branch field (set to `-`)
- Update Last activity timestamp
- Add note about completed work (e.g., "✅ Feature X implemented (PR #123)")

### Step 4: Log Release

Add entry to `C:/scripts/_machine/worktrees.activity.md`:
```
## <timestamp> - Release: agent-XXX
- Repo: <repo-name>
- Branch: <branch-name>
- PR: #<number>
- Outcome: <PR title or brief description>
```

### Step 5: Remove from instances.map.md

Remove the line for this agent from `C:/scripts/_machine/instances.map.md`.

### Step 6: Switch Base Repos to Develop (ONLY if not in Active Debugging Mode)

**⚠️ CRITICAL: Check for Active Debugging Mode first!**

```bash
# Check client-manager for active work
cd C:/Projects/client-manager
current_branch=$(git branch --show-current)
uncommitted_changes=$(git status --short)

if [ "$current_branch" != "develop" ] && [ -n "$uncommitted_changes" ]; then
  echo "⚠️ SKIP: Active debugging detected in client-manager (branch: $current_branch, uncommitted changes)"
  echo "User is actively working - NOT switching branches"
else
  git checkout develop
  git pull origin develop
fi

# Check hazina for active work
cd C:/Projects/hazina
current_branch=$(git branch --show-current)
uncommitted_changes=$(git status --short)

if [ "$current_branch" != "develop" ] && [ -n "$uncommitted_changes" ]; then
  echo "⚠️ SKIP: Active debugging detected in hazina (branch: $current_branch, uncommitted changes)"
  echo "User is actively working - NOT switching branches"
else
  git checkout develop
  git pull origin develop
fi
```

**Detection Logic:**
- IF base repo has uncommitted changes AND is not on develop → Active Debugging Mode → SKIP branch switch
- ELSE → Safe to switch to develop

### Step 7: Prune Worktrees

```bash
# Remove worktree references from git
git -C C:/Projects/client-manager worktree prune
git -C C:/Projects/hazina worktree prune
```

### Step 8: Commit Tracking Files

```bash
cd C:/scripts
git add _machine/worktrees.pool.md
git add _machine/worktrees.activity.md
git add _machine/instances.map.md
git commit -m "chore: Release agent-XXX after <brief description> (PR #<number>)"
git push origin main
```

### Step 8.5: 🎯 Verify Definition of Done

**CRITICAL: Before presenting work as complete, verify ALL DoD criteria are met.**

Quick DoD Verification Checklist:
- [ ] ✅ **Code quality:** Build passes, tests pass, no warnings
- [ ] ✅ **Version control:** Committed, pushed, PR created with proper base (`develop`)
- [ ] ✅ **PR details:** Clear title, description, test plan included
- [ ] ✅ **ClickUp updated:** PR link added to task (if applicable)
- [ ] ✅ **Documentation:** Technical docs updated if needed
- [ ] ✅ **Worktree cleanup:** All 8 steps above completed

**Full DoD reference:** `C:/scripts/_machine/DEFINITION_OF_DONE.md`

**If ANY criteria not met:**
- ⚠️ Work is NOT complete
- 🔄 Go back and complete missing items
- ❌ DO NOT present to user until DoD satisfied

**Validation commands:**
```bash
# Verify PR base branch is develop
gh pr view --json baseRefName --jq .baseRefName
# Should output: "develop"

# Verify ClickUp updated (check last comment)
clickup-sync.ps1 -Action show -TaskId <task-id>
# Should show PR link in recent comments

# Verify build passed (check CI status)
gh pr checks --watch
# All checks should be green
```

### Step 9: Verify Release Complete

```bash
# Check worktree directory is empty
ls C:/Projects/worker-agents/agent-XXX/

# Check pool.md shows FREE
grep "agent-XXX" C:/scripts/_machine/worktrees.pool.md

# Check base repos on develop
git -C C:/Projects/client-manager branch --show-current
git -C C:/Projects/hazina branch --show-current

# Check git worktree list (should not show released worktree)
git -C C:/Projects/client-manager worktree list
git -C C:/Projects/hazina worktree list
```

## Success Criteria

✅ **Release successful ONLY IF:**
- Worktree directory cleaned (`rm -rf agent-XXX/*`)
- Seat marked FREE in pool.md
- Release logged in activity.md
- Entry removed from instances.map.md
- Both base repos on develop branch
- Worktrees pruned (git worktree prune)
- Tracking files committed and pushed
- **🎯 Definition of Done verified** (Step 8.5 - all DoD criteria met)
- THEN (and only then) present PR to user

**See:** `C:/scripts/_machine/DEFINITION_OF_DONE.md` for complete quality checklist

## Critical Rules

❌ **NEVER:**
- Present PR to user before releasing worktree
- Skip cleanup of worktree directory
- Forget to mark seat FREE
- Leave base repo on feature branch
- Skip committing tracking file updates

✅ **ALWAYS:**
- Complete ALL 9 steps in order
- Verify each step before proceeding
- Commit tracking files together
- Present PR link AFTER release complete

## Reference Files

- Protocol: `C:/scripts/_machine/worktrees.protocol.md`
- Zero-tolerance rules: `C:/scripts/ZERO_TOLERANCE_RULES.md`
- Pool status: `C:/scripts/_machine/worktrees.pool.md`

## Example: Complete Release

```bash
# 1. Verify PR exists
gh pr view 123 --repo user/client-manager

# 2. Clean worktree
rm -rf C:/Projects/worker-agents/agent-001/*

# 3-5. Update tracking files (pool.md, activity.md, instances.map.md)

# 6. Switch to develop
cd C:/Projects/client-manager && git checkout develop && git pull
cd C:/Projects/hazina && git checkout develop && git pull

# 7. Prune worktrees
git -C C:/Projects/client-manager worktree prune
git -C C:/Projects/hazina worktree prune

# 8. Commit tracking files
cd C:/scripts
git add _machine/*.md
git commit -m "chore: Release agent-001 after new feature (PR #123)"
git push origin main

# 9. Verify
ls C:/Projects/worker-agents/agent-001/  # Should be empty or show only .git dirs
grep "agent-001" C:/scripts/_machine/worktrees.pool.md  # Should show FREE
```

## Troubleshooting

**"Worktree directory not empty after rm -rf":**
- Check for permission issues
- Verify correct path: `C:/Projects/worker-agents/agent-XXX/`
- Close any editors or terminals in that directory

**"Base repo still on feature branch":**
- Worktree might still be linked
- Run `git worktree prune` first
- Then `git checkout develop`

**"Can't commit tracking files":**
- Check you're in C:/scripts directory
- Verify git status shows modified files
- Ensure no merge conflicts in tracking files

## PR Presentation Template

**After completing ALL release steps, present to user:**

```
✅ PR Created: #<number>
Title: <PR title>
URL: https://github.com/<owner>/<repo>/pull/<number>

Changes:
- <bullet point summary>

Worktree released, seat agent-XXX now FREE.
```

## Step 10: Consciousness Bridge (LAST)

After completing all release steps, close the feedback loop:

```bash
powershell.exe -File "C:/scripts/tools/consciousness-bridge.ps1" -Action OnTaskEnd -Outcome "success" -LessonsLearned "<what was learned during this task>" -Silent
```

Use "success", "partial", or "failure" based on outcome. Include specific lessons (e.g., "PS 5.1 arrays unroll from functions, use comma operator").

## Violation Recovery

**If you presented PR before releasing:**

1. STOP immediately
2. Read `C:/scripts/_machine/reflection.log.md` § 2026-01-08 02:00
3. Execute ALL release steps now
4. Update reflection.log.md with violation entry
5. Commit corrective action

**This is a CRITICAL VIOLATION. Zero tolerance.**
