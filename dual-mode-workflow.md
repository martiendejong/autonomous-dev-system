# Dual-Mode Workflow - Feature Development vs Active Debugging

**EFFECTIVE:** 2026-01-13
**PURPOSE:** Clear decision tree for when to use worktrees vs direct editing

---

## 🎯 Overview

Claude operates in **TWO DISTINCT MODES** depending on the context of the user's request:

1. **🏗️ Feature Development Mode** - New features, changes, refactoring
2. **🐛 Active Debugging Mode** - User is actively debugging/developing in C:\Projects\<repo>

**The mode determines WHERE you edit code:**
- Feature Development Mode → Work in worktree (`C:\Projects\worker-agents\agent-XXX\<repo>`)
- Active Debugging Mode → Work directly in base repo (`C:\Projects\<repo>`)

---

## 🚦 Decision Tree - Which Mode to Use?

```
┌─────────────────────────────────────────────────────┐
│ User requests code changes or proposes new feature │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
       ┌─────────────────────────────┐
       │ Is user ACTIVELY debugging  │
       │ or working on this code in  │────── YES ─────┐
       │ C:\Projects\<repo> right    │                │
       │ now?                        │                │
       └─────────────┬───────────────┘                │
                     │                                │
                     NO                               │
                     │                                ▼
                     │                    ┌──────────────────────────┐
                     │                    │ 🐛 ACTIVE DEBUGGING MODE │
                     │                    └──────────────────────────┘
                     │                    │ Work in: C:\Projects\<repo>
                     │                    │ Branch: Current user branch
                     │                    │ Purpose: Fix build errors,
                     │                    │          assist debugging,
                     │                    │          quick fixes
                     │                    └──────────────────────────┘
                     │
                     ▼
       ┌──────────────────────────────┐
       │ 🏗️ FEATURE DEVELOPMENT MODE  │
       └──────────────────────────────┘
       │ 1. Allocate worktree
       │ 2. Create feature branch
       │ 3. Develop solution
       │ 4. Create PR
       │ 5. Code review
       │ 6. Release worktree
       └──────────────────────────────┘
```

---

## 🐛 ACTIVE DEBUGGING MODE

### When to Use

Use Active Debugging Mode when **ANY** of these conditions are true:

1. **Build Errors Posted**
   - User pastes compilation errors from Visual Studio
   - User mentions "it won't build" or "build is failing"
   - User shares error output from their development session

2. **Explicit Context Provided**
   - User mentions "I'm working on branch X"
   - User shares code from C:\Projects\<repo> with current state
   - User says "I'm debugging this issue in..."
   - User has Visual Studio open and running debugger

3. **Quick Fix Requests**
   - "Fix this syntax error"
   - "Add this missing using statement"
   - "Update this config value"
   - Small, immediate changes to code user is actively working on

4. **Runtime Debugging**
   - User is running the application in Visual Studio
   - User is stepping through code with debugger
   - User needs immediate code changes to test hypothesis

### How to Operate

**1. Detect the Branch**
```bash
# Check what branch user is on
cd C:/Projects/<repo>
git branch --show-current

# Verify there are uncommitted changes (user is working)
git status
```

**2. Work Directly in Base Repo**
```bash
# Edit files in place
# Location: C:\Projects\<repo>\
# Branch: Whatever user is currently on (DON'T switch branches!)
# NO worktree allocation needed
```

**3. Commit Strategy**
```bash
# Option A: Let user commit themselves
# - Make changes
# - Tell user what you changed
# - User commits when ready

# Option B: Commit for user (if requested)
# - git add -u
# - git commit -m "fix: <description>"
# - git push origin <current-branch>
# - DO NOT create PR (user will do that when ready)
```

**4. Key Rules**
- ❌ **DO NOT** allocate worktree
- ❌ **DO NOT** create new branch
- ❌ **DO NOT** switch branches
- ❌ **DO NOT** create PR automatically
- ✅ **DO** edit files in C:\Projects\<repo> directly
- ✅ **DO** work on user's current branch
- ✅ **DO** preserve user's workflow state

### Example Scenarios

**Scenario 1: User Pastes Build Error**
```
User: "I'm getting this error when I build:

Error CS0246: The type or namespace name 'JsonSerializer' could not be found

Can you fix it?"

Claude Action:
→ Mode: Active Debugging (build error posted)
→ Location: C:\Projects\client-manager (current branch)
→ Action: Add `using System.Text.Json;` to the file
→ Output: "Added missing using statement to <file>:5"
```

**Scenario 2: User Debugging in VS**
```
User: "I'm stepping through the code and the validation logic is wrong.
Can you update the ValidateInput method to check for null?"

Claude Action:
→ Mode: Active Debugging (user is debugging)
→ Location: C:\Projects\client-manager (current branch)
→ Action: Edit ValidateInput method
→ Output: "Updated validation logic in <file>:45"
```

**Scenario 3: User on Feature Branch**
```
User: "I'm working on feature/add-export-functionality branch and I need
to add error handling to the ExportService."

Claude Action:
→ Mode: Active Debugging (user stated current branch)
→ Verify: git branch --show-current → feature/add-export-functionality
→ Location: C:\Projects\client-manager
→ Action: Add error handling
→ Output: "Added try-catch to ExportService.cs:78"
```

---

## 🏗️ FEATURE DEVELOPMENT MODE

### When to Use

Use Feature Development Mode when **ALL** of these conditions are true:

1. **New Work Request**
   - User proposes a new feature
   - User requests refactoring
   - User wants architectural changes
   - Fresh development task (not debugging existing work)

2. **NO Active Debugging**
   - User is NOT currently running Visual Studio debugger
   - User is NOT in the middle of fixing build errors
   - User is NOT sharing code from their current work session

3. **Will Create PR**
   - Work will result in a pull request
   - Multiple commits expected
   - Code review process will follow

### How to Operate

**1. Check for Conflicts**
```bash
# MANDATORY: Check if another agent is working on this
bash /c/scripts/tools/check-branch-conflicts.sh <repo> <branch-name>
```

**2. Allocate Worktree**
```bash
# Read pool
Read C:\scripts\_machine\worktrees.pool.md

# Find FREE seat (or provision new agent-00X)
# Mark BUSY + log allocation

# Ensure base repo on develop + latest
cd C:/Projects/<repo>
git checkout develop
git pull origin develop

# Create worktree
git worktree add C:/Projects/worker-agents/agent-XXX/<repo> -b agent-XXX-<feature>

# Copy config files
cp appsettings.json C:/Projects/worker-agents/agent-XXX/<repo>/
cp .env C:/Projects/worker-agents/agent-XXX/<repo>/
```

**3. Develop Feature**
```bash
# Work in: C:\Projects\worker-agents\agent-XXX\<repo>\
# Make all changes, commits in worktree
cd C:/Projects/worker-agents/agent-XXX/<repo>

# Regular development workflow
git add .
git commit -m "feat: implement X"
```

**4. Create PR**
```bash
# Merge develop before PR
git fetch origin
git merge origin/develop

# Push and create PR
git push -u origin agent-XXX-<feature>
gh pr create --base develop --title "..." --body "..."

# Verify base branch
gh pr view <number> --json baseRefName
# Must show: "baseRefName": "develop"
```

**5. Release Worktree (MANDATORY)**
```bash
# IMMEDIATELY after gh pr create:

# 1. Clean worktree directory
rm -rf C:/Projects/worker-agents/agent-XXX/*

# 2. Update pool status (BUSY → FREE)
Edit C:\scripts\_machine\worktrees.pool.md

# 3. Log release
echo "<timestamp> — release — agent-XXX — <repo> — <branch> — — claude-code — PR #XX created" >> C:/scripts/_machine/worktrees.activity.md

# 4. Commit tracking updates
cd C:/scripts
git add _machine/worktrees.pool.md _machine/worktrees.activity.md
git commit -m "docs: Release agent-XXX after PR #XX"
git push origin main

# 5. Switch base repos to develop
git -C C:/Projects/<repo> checkout develop
git -C C:/Projects/<repo> pull origin develop

# 6. Prune worktree references
git -C C:/Projects/<repo> worktree prune

# ONLY THEN present PR to user
```

**6. Key Rules**
- ✅ **DO** allocate worktree FIRST (before any Edit/Write)
- ✅ **DO** check for branch conflicts
- ✅ **DO** create feature branch
- ✅ **DO** create PR with code review
- ✅ **DO** release worktree immediately after PR
- ❌ **DO NOT** edit C:\Projects\<repo> directly
- ❌ **DO NOT** present PR before releasing worktree

### Example Scenarios

**Scenario 1: New Feature Request**
```
User: "I want to add a new export to PDF feature for reports"

Claude Action:
→ Mode: Feature Development (new feature request)
→ Allocate: agent-001, create worktree
→ Branch: agent-001-add-pdf-export
→ Location: C:\Projects\worker-agents\agent-001\client-manager
→ Develop: Implement PDF export service
→ PR: Create PR #123 "feat: Add PDF export for reports"
→ Release: Clean agent-001, mark FREE, switch to develop
→ Output: "PR #123 created: <url>"
```

**Scenario 2: Refactoring Request**
```
User: "The authentication service needs refactoring to use dependency injection"

Claude Action:
→ Mode: Feature Development (architectural change)
→ Allocate: agent-002, create worktree
→ Branch: agent-002-refactor-auth-di
→ Location: C:\Projects\worker-agents\agent-002\client-manager
→ Develop: Refactor AuthService
→ PR: Create PR #124 "refactor: Use DI in AuthService"
→ Release: Clean agent-002, mark FREE, switch to develop
→ Output: "PR #124 created: <url>"
```

**Scenario 3: Multi-File Feature**
```
User: "Implement complete user profile management with avatar upload"

Claude Action:
→ Mode: Feature Development (complex feature)
→ Allocate: agent-003, create worktree
→ Branch: agent-003-user-profile-management
→ Location: C:\Projects\worker-agents\agent-003\client-manager
→ Develop:
  - Backend: ProfileService, AvatarStorage
  - Frontend: ProfilePage, AvatarUpload component
  - Database: Migration for profiles table
→ PR: Create PR #125 "feat: Complete user profile management"
→ Release: Clean agent-003, mark FREE, switch to develop
→ Output: "PR #125 created: <url>"
```

---

## 🎯 Mode Detection Quick Reference

| User Signal | Mode | Location | Worktree? |
|-------------|------|----------|-----------|
| "Fix this build error: ..." | 🐛 Debug | C:\Projects\<repo> | ❌ No |
| "I'm debugging this in VS..." | 🐛 Debug | C:\Projects\<repo> | ❌ No |
| "Working on branch feature/X" | 🐛 Debug | C:\Projects\<repo> | ❌ No |
| "Add this quick fix to..." | 🐛 Debug | C:\Projects\<repo> | ❌ No |
| "Implement new feature X" | 🏗️ Feature | Worktree | ✅ Yes |
| "Refactor the service layer" | 🏗️ Feature | Worktree | ✅ Yes |
| "Add a new component for..." | 🏗️ Feature | Worktree | ✅ Yes |
| "Create an API endpoint for..." | 🏗️ Feature | Worktree | ✅ Yes |

---

## ⚠️ Critical Reminders

### For Active Debugging Mode
1. **Respect User State** - Don't change branches, don't create PRs, don't allocate worktrees
2. **Fast Fixes** - User needs immediate help, not workflow overhead
3. **User Commits** - Unless explicitly asked, let user handle git operations
4. **NO Cleanup** - Don't switch branches, don't run git worktree prune, leave state as-is

### For Feature Development Mode
1. **Zero Tolerance** - MUST allocate worktree, MUST release after PR
2. **Always PR** - Feature work ALWAYS results in pull request + code review
3. **Clean State** - Release worktree IMMEDIATELY after PR creation
4. **Develop Baseline** - Base repos ALWAYS return to develop branch after work

---

## 🔄 Mode Switching

**Can you switch modes mid-session?**

Yes, but be explicit:

```
User: "Actually, I want to test this fix locally first before creating a PR"

Claude Response:
"Switching from Feature Development Mode to Active Debugging Mode.
I'll work directly in C:\Projects\<repo> on your current branch so you
can test immediately. When ready for PR, let me know and I'll create it."
```

```
User: "This is working now. Let's create a proper PR for this."

Claude Response:
"Switching from Active Debugging Mode to Feature Development Mode.
I'll allocate a worktree, create a feature branch, and prepare a PR
with your changes."
```

---

## 📊 Success Criteria

**Active Debugging Mode Success:**
- ✅ User's build errors resolved
- ✅ User can continue debugging immediately
- ✅ Branch state unchanged (user still on their branch)
- ✅ No worktree overhead
- ✅ Fast turnaround time

**Feature Development Mode Success:**
- ✅ Worktree allocated before code edits
- ✅ All changes in worktree (ZERO in C:\Projects\<repo>)
- ✅ PR created with full description
- ✅ Worktree released immediately after PR
- ✅ Base repos back on develop branch
- ✅ Pool status accurate (FREE)

---

**Last Updated:** 2026-01-13
**Maintained By:** Claude Agent
**User Mandate:** "when i propose a change... you either find a free worker agent [or] when the context i send you is already about code that falls directly under c:\projects\projectname you find out what branch the user is working on... and you work directly in that branch"
