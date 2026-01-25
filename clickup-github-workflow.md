# ClickUp ↔ GitHub Workflow

**Created:** 2026-01-14
**Status:** Active

---

## Overview

This document defines how ClickUp tasks are linked to GitHub branches and PRs for the client-manager and hazina repositories.

---

## 1. Naming Convention

### Branch Names
```
<type>/<clickup-id>-<short-description>
```

**Examples:**
```
feature/869bhfw7r-restaurant-menu
fix/869bpz2c0-images-not-generating
refactor/869bmhjh9-product-catalog
```

**Types:**
- `feature/` - New functionality
- `fix/` - Bug fixes
- `refactor/` - Code improvements
- `docs/` - Documentation only
- `test/` - Test additions

### PR Titles
```
<type>: <description> [<clickup-id>]
```

**Examples:**
```
feat: Restaurant menu catalog [869bhfw7r]
fix: Images not generating in chat [869bpz2c0]
```

---

## 2. Linking Criteria

### When to Link ClickUp → GitHub

A ClickUp task gets linked to GitHub when:
- Task status changes to **"busy"** (in progress)
- Task requires code changes in client-manager or hazina

### When to Link GitHub → ClickUp

A GitHub branch/PR gets linked to ClickUp when:
- Branch name contains a ClickUp task ID
- PR is created for a task-related branch

---

## 3. Status Synchronization

| ClickUp Status | GitHub State | Trigger Event |
|----------------|--------------|---------------|
| todo | - | Task created in ClickUp |
| **busy** | Branch + PR open | Agent allocates worktree, starts work |
| **review** | PR merged | PR merged to develop/master → User does acceptance test |
| done | Acceptance passed | User confirms feature works correctly |

### Status Flow

```
todo → busy → review → done
              ↓
         (if test fails)
              ↓
           busy (new branch/PR)
```

### Automatic Updates

When agent creates a PR:
1. Add comment to ClickUp task with PR link
2. Keep ClickUp status at "busy" (PR still open)
3. PR description includes ClickUp task URL

When PR is merged:
1. Update ClickUp status to "review"
2. Add comment: "PR merged - ready for acceptance test"
3. **User performs acceptance test**

After acceptance test:
- **Pass:** User moves to "done"
- **Fail:** Agent creates new branch/PR, keeps status "busy"

---

## 4. Workflow Steps

### Starting Work on a Task

```
1. Check ClickUp for priority tasks
   > clickup-sync.ps1 -Action list

2. Pick a task, note the ID (e.g., 869bhfw7r)

3. Update ClickUp status to "busy"
   > clickup-sync.ps1 -Action update -TaskId 869bhfw7r -Status busy

4. Allocate worktree with task-based branch name
   > Branch: feature/869bhfw7r-restaurant-menu

5. Work on the feature...

6. Create PR with task reference
   > gh pr create --title "feat: Restaurant menu [869bhfw7r]"

7. Add PR link to ClickUp (keep status "busy")
   > clickup-sync.ps1 -Action comment -TaskId 869bhfw7r -Comment "PR #148: https://github.com/martiendejong/client-manager/pull/148"

8. Release worktree per zero-tolerance rules
```

### When PR is Merged

```
1. Update ClickUp status to "review" (for acceptance testing)
   > clickup-sync.ps1 -Action update -TaskId 869bhfw7r -Status review

2. Add merge comment
   > clickup-sync.ps1 -Action comment -TaskId 869bhfw7r -Comment "✅ PR merged to develop - ready for acceptance test"
```

### After Acceptance Test

**If test passes (User action):**
- User moves task to "done" in ClickUp

**If test fails:**
```
1. Create new branch from develop
   > Branch: fix/869bhfw7r-restaurant-menu-v2

2. Status stays at "busy"

3. Create new PR, add comment to task
   > clickup-sync.ps1 -Action comment -TaskId 869bhfw7r -Comment "Fix PR #150: https://github.com/..."
```

---

## 5. Reference Format

### In ClickUp Task
```
## GitHub
- Branch: `feature/869bhfw7r-restaurant-menu`
- PR: #148 - https://github.com/martiendejong/client-manager/pull/148
- Status: Merged ✅
```

### In GitHub PR Description
```
## ClickUp Task
https://app.clickup.com/t/869bhfw7r

## Summary
[Description of changes]
```

---

## 6. ID Extraction

### From Branch Name
```powershell
# Extract ClickUp ID from branch
$branch = "feature/869bhfw7r-restaurant-menu"
$taskId = ($branch -split '/')[1] -split '-' | Select-Object -First 1
# Result: 869bhfw7r
```

### From PR Title
```powershell
# Extract ClickUp ID from PR title
$title = "feat: Restaurant menu [869bhfw7r]"
$taskId = [regex]::Match($title, '\[([a-z0-9]+)\]').Groups[1].Value
# Result: 869bhfw7r
```

---

## 7. Validation Rules

### Before Creating Branch
- [ ] Task ID exists in ClickUp
- [ ] Task is in Brand Designer list
- [ ] Task status is appropriate (todo, needs refinement, etc.)

### Before Creating PR
- [ ] Branch name contains valid ClickUp ID
- [ ] ClickUp task updated to "busy"
- [ ] PR title includes task ID in brackets

### Before Merging
- [ ] ClickUp status is "review"
- [ ] PR has ClickUp link in description

---

## 8. Edge Cases

### Task Without Code Changes
- Status: Skip GitHub linking
- Example: "buy tokens" - business/payment task, not code

### Code Change Without Task
- Create ClickUp task first
- Or use branch without ID prefix for urgent fixes
- Document in PR: "No ClickUp task - urgent fix"

### Multiple PRs for One Task
- All PRs reference same task ID
- Add comments to task for each PR
- Only mark "done" when all PRs merged

### One PR for Multiple Tasks
- Use primary task ID in branch name
- Reference all task IDs in PR description
- Update all tasks when PR is merged

---

## 9. Tools

### clickup-sync.ps1 Commands

```powershell
# List tasks
clickup-sync.ps1 -Action list

# Start work on task
clickup-sync.ps1 -Action update -TaskId 869bhfw7r -Status busy

# Mark for review (after PR created)
clickup-sync.ps1 -Action update -TaskId 869bhfw7r -Status review

# Add PR link
clickup-sync.ps1 -Action comment -TaskId 869bhfw7r -Comment "PR #148 created"

# Mark done (after merge)
clickup-sync.ps1 -Action update -TaskId 869bhfw7r -Status done
```

---

**Maintained by:** Claude Agent
