# Dual-Mode Workflow - Feature Development vs Active Debugging

**VERSION:** 1.0 (Portable)
**PURPOSE:** Clear decision tree for when to use worktrees vs direct editing
**PORTABILITY:** Uses variables defined in `MACHINE_CONFIG.md` (not included in plugin copy)

---

## 🎯 Overview

Claude operates in **TWO DISTINCT MODES** depending on the context of the user's request:

1. **🏗️ Feature Development Mode** - New features, changes, refactoring
2. **🐛 Active Debugging Mode** - User is actively debugging/developing in their base repository

**The mode determines WHERE you edit code:**
- Feature Development Mode → Work in worktree (`${WORKTREE_PATH}/agent-XXX/<repo>`)
- Active Debugging Mode → Work directly in base repo (`${BASE_REPO_PATH}/<repo>`)

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
       │ their base repo right now?  │                │
       └─────────────┬───────────────┘                │
                     │                                │
                     NO                               │
                     │                                ▼
                     │                    ┌──────────────────────────┐
                     │                    │ 🐛 ACTIVE DEBUGGING MODE │
                     │                    └──────────────────────────┘
                     │                    │ Work in: ${BASE_REPO_PATH}/<repo>
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
   - User pastes compilation errors from their IDE
   - User mentions "it won't build" or "build is failing"
   - User shares error output from their development session

2. **Explicit Context Provided**
   - User mentions "I'm working on branch X"
   - User shares code from their base repo with current state
   - User says "I'm debugging this issue in..."
   - User has their IDE open and running debugger

3. **Quick Fix Requests**
   - "Fix this syntax error"
   - "Add this missing import/using statement"
   - "Update this config value"
   - Small, immediate changes to code user is actively working on

4. **Runtime Debugging**
   - User is running the application in their IDE
   - User is stepping through code with debugger
   - User needs immediate code changes to test hypothesis

### How to Operate

**1. Detect the Branch**
```bash
# Check what branch user is on
cd ${BASE_REPO_PATH}/<repo>
git branch --show-current

# Verify there are uncommitted changes (user is working)
git status
```

**2. Work Directly in Base Repo**
```bash
# Edit files in place
# Location: ${BASE_REPO_PATH}/<repo>/
# Branch: Whatever user is currently on (DON'T switch branches!)
# NO worktree allocation needed
```

**3. Commit Strategy**
```bash
# Option A: Let user commit themselves (DEFAULT)
# - Make changes
# - Tell user what you changed
# - User commits when ready

# Option B: Commit for user (if explicitly requested)
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
- ✅ **DO** edit files in `${BASE_REPO_PATH}/<repo>` directly
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
→ Location: ${BASE_REPO_PATH}/<repo> (current branch)
→ Action: Add missing import to the file
→ Output: "Added missing import to <file>:5"
```

**Scenario 2: User Debugging in IDE**
```
User: "I'm stepping through the code and the validation logic is wrong.
Can you update the ValidateInput method to check for null?"

Claude Action:
→ Mode: Active Debugging (user is debugging)
→ Location: ${BASE_REPO_PATH}/<repo> (current branch)
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
→ Location: ${BASE_REPO_PATH}/<repo>
→ Action: Add error handling
→ Output: "Added try-catch to ExportService:78"
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
   - User is NOT currently running IDE debugger
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
# (If using multi-agent conflict detection tool)
bash ${CONTROL_PLANE_PATH}/tools/check-branch-conflicts.sh <repo> <branch-name>
```

**2. Allocate Worktree**
```bash
# Read pool
Read ${MACHINE_CONTEXT_PATH}/worktrees.pool.md

# Find FREE seat (or provision new agent-00X)
# Mark BUSY + log allocation

# Ensure base repo on main branch + latest
cd ${BASE_REPO_PATH}/<repo>
git checkout <main-branch>  # Usually 'develop' or 'main'
git pull origin <main-branch>

# Create worktree
git worktree add ${WORKTREE_PATH}/agent-XXX/<repo> -b agent-XXX-<feature>

# Copy config files (if needed)
cp appsettings.json ${WORKTREE_PATH}/agent-XXX/<repo>/
cp .env ${WORKTREE_PATH}/agent-XXX/<repo>/
```

**3. Develop Feature**
```bash
# Work in: ${WORKTREE_PATH}/agent-XXX/<repo>/
# Make all changes, commits in worktree
cd ${WORKTREE_PATH}/agent-XXX/<repo>

# Regular development workflow
git add .
git commit -m "feat: implement X"
```

**4. Create PR**
```bash
# Merge main branch before PR
git fetch origin
git merge origin/<main-branch>

# Push and create PR
git push -u origin agent-XXX-<feature>
gh pr create --base <main-branch> --title "..." --body "..."

# Verify base branch
gh pr view <number> --json baseRefName
# Must show: "baseRefName": "<main-branch>"
```

**5. Release Worktree (MANDATORY)**
```bash
# IMMEDIATELY after gh pr create:

# 1. Clean worktree directory
rm -rf ${WORKTREE_PATH}/agent-XXX/*

# 2. Update pool status (BUSY → FREE)
Edit ${MACHINE_CONTEXT_PATH}/worktrees.pool.md

# 3. Log release
echo "<timestamp> — release — agent-XXX — <repo> — <branch> — — claude-code — PR #XX created" >> ${MACHINE_CONTEXT_PATH}/worktrees.activity.md

# 4. Commit tracking updates
cd ${CONTROL_PLANE_PATH}
git add _machine/worktrees.pool.md _machine/worktrees.activity.md
git commit -m "docs: Release agent-XXX after PR #XX"
git push origin main

# 5. Switch base repos to main branch
git -C ${BASE_REPO_PATH}/<repo> checkout <main-branch>
git -C ${BASE_REPO_PATH}/<repo> pull origin <main-branch>

# 6. Prune worktree references
git -C ${BASE_REPO_PATH}/<repo> worktree prune

# ONLY THEN present PR to user
```

**6. Key Rules**
- ✅ **DO** allocate worktree FIRST (before any Edit/Write)
- ✅ **DO** check for branch conflicts
- ✅ **DO** create feature branch
- ✅ **DO** create PR with code review
- ✅ **DO** release worktree immediately after PR
- ❌ **DO NOT** edit `${BASE_REPO_PATH}/<repo>` directly
- ❌ **DO NOT** present PR before releasing worktree

### Example Scenarios

**Scenario 1: New Feature Request**
```
User: "I want to add a new export to PDF feature for reports"

Claude Action:
→ Mode: Feature Development (new feature request)
→ Allocate: agent-001, create worktree
→ Branch: agent-001-add-pdf-export
→ Location: ${WORKTREE_PATH}/agent-001/<repo>
→ Develop: Implement PDF export service
→ PR: Create PR #123 "feat: Add PDF export for reports"
→ Release: Clean agent-001, mark FREE, switch to main branch
→ Output: "PR #123 created: <url>"
```

**Scenario 2: Refactoring Request**
```
User: "The authentication service needs refactoring to use dependency injection"

Claude Action:
→ Mode: Feature Development (architectural change)
→ Allocate: agent-002, create worktree
→ Branch: agent-002-refactor-auth-di
→ Location: ${WORKTREE_PATH}/agent-002/<repo>
→ Develop: Refactor AuthService
→ PR: Create PR #124 "refactor: Use DI in AuthService"
→ Release: Clean agent-002, mark FREE, switch to main branch
→ Output: "PR #124 created: <url>"
```

**Scenario 3: Multi-File Feature**
```
User: "Implement complete user profile management with avatar upload"

Claude Action:
→ Mode: Feature Development (complex feature)
→ Allocate: agent-003, create worktree
→ Branch: agent-003-user-profile-management
→ Location: ${WORKTREE_PATH}/agent-003/<repo>
→ Develop:
  - Backend: ProfileService, AvatarStorage
  - Frontend: ProfilePage, AvatarUpload component
  - Database: Migration for profiles table
→ PR: Create PR #125 "feat: Complete user profile management"
→ Release: Clean agent-003, mark FREE, switch to main branch
→ Output: "PR #125 created: <url>"
```

**Scenario 4: PR Conflict Resolution (CRITICAL - Common Mistake)**
```
User: "PR #236 has merge conflicts with develop. Merge develop into it so it can be tested and merged"

Claude Action:
→ Mode: Feature Development (PR maintenance = code work)
→ Allocate: agent-001, create worktree
→ Branch: fix/develop-issues-systematic (existing PR branch)
→ Location: ${WORKTREE_PATH}/agent-001/<repo>
→ Work:
  1. Check out existing PR branch in worktree
  2. Merge origin/develop in worktree
  3. Resolve conflicts in worktree
  4. Commit merge in worktree
  5. Push from worktree
→ Release: Clean agent-001, mark FREE, switch to main branch
→ Output: "PR #236 conflicts resolved, now mergeable: <url>"

⚠️ COMMON MISTAKE: Working directly in ${BASE_REPO_PATH}/<repo> because "it's just maintenance"
✅ CORRECT: ANY work on PR branches requires worktree allocation
```

---

## 🎯 Mode Detection Quick Reference

| User Signal | Mode | Location | Worktree? |
|-------------|------|----------|-----------|
| "Fix this build error: ..." | 🐛 Debug | ${BASE_REPO_PATH}/<repo> | ❌ No |
| "I'm debugging this in IDE..." | 🐛 Debug | ${BASE_REPO_PATH}/<repo> | ❌ No |
| "Working on branch feature/X" | 🐛 Debug | ${BASE_REPO_PATH}/<repo> | ❌ No |
| "Add this quick fix to..." | 🐛 Debug | ${BASE_REPO_PATH}/<repo> | ❌ No |
| "Implement new feature X" | 🏗️ Feature | ${WORKTREE_PATH}/agent-XXX/<repo> | ✅ Yes |
| "Refactor the service layer" | 🏗️ Feature | ${WORKTREE_PATH}/agent-XXX/<repo> | ✅ Yes |
| "Add a new component for..." | 🏗️ Feature | ${WORKTREE_PATH}/agent-XXX/<repo> | ✅ Yes |
| "Create an API endpoint for..." | 🏗️ Feature | ${WORKTREE_PATH}/agent-XXX/<repo> | ✅ Yes |
| **"Merge develop into PR #XXX"** | **🏗️ Feature** | **${WORKTREE_PATH}/agent-XXX/<repo>** | **✅ Yes** |
| **"Resolve conflicts in PR #XXX"** | **🏗️ Feature** | **${WORKTREE_PATH}/agent-XXX/<repo>** | **✅ Yes** |

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
4. **Main Branch Baseline** - Base repos ALWAYS return to main branch after work

---

## 🔄 Mode Switching

**Can you switch modes mid-session?**

Yes, but be explicit:

```
User: "Actually, I want to test this fix locally first before creating a PR"

Claude Response:
"Switching from Feature Development Mode to Active Debugging Mode.
I'll work directly in ${BASE_REPO_PATH}/<repo> on your current branch so you
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
- ✅ All changes in worktree (ZERO in `${BASE_REPO_PATH}/<repo>`)
- ✅ PR created with full description
- ✅ Worktree released immediately after PR
- ✅ Base repos back on main branch
- ✅ Pool status accurate (FREE)

---

---

## 📚 See Also

**Related workflows:**
- **Zero Tolerance Rules:** `GENERAL_ZERO_TOLERANCE_RULES.md` - Critical rules quick reference
- **Worktree Protocol:** `GENERAL_WORKTREE_PROTOCOL.md` - Detailed worktree allocation steps
- **Workflows Index:** `C:\scripts\_machine\knowledge-base\06-WORKFLOWS\INDEX.md` - Complete workflow catalog
- **Tools Library:** `C:\scripts\_machine\knowledge-base\07-AUTOMATION\tools-library.md` - Available automation tools

**For mode detection automation:**
- **Tool:** `C:\scripts\tools\detect-mode.ps1` - Automated mode detection based on user message

**Version:** 1.0 (Portable)
**Last Updated:** 2026-01-25 (Added knowledge base references)
**Maintained By:** Claude Community
**Portability:** This document uses variables - see MACHINE_CONFIG.md for local paths
