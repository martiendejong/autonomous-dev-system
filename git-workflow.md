# Git Workflow and PR Management

## 🔗 CROSS-REPO PR DEPENDENCIES

**CRITICAL: When myproject PR depends on myframework PR, CLEARLY MARK IT!**

### Why This Matters
- myproject uses myframework as a submodule/package reference
- If myframework changes aren't merged first, myproject PR will fail CI
- User needs to know which PRs to merge together

### PR Description Template (MANDATORY)

When creating a PR in myproject that depends on myframework changes:

```markdown
## ⚠️ DEPENDENCY ALERT ⚠️

**This PR depends on the following myframework PR(s):**
- [ ] https://github.com/yourname/myframework/pull/XXX - [Brief description]

**Merge order:**
1. First merge the myframework PR(s) above
2. Then merge this PR

---

## Summary
[rest of PR description]
```

### For myframework PRs that myproject depends on:

```markdown
## ⚠️ DOWNSTREAM DEPENDENCIES ⚠️

**The following myproject PR(s) depend on this:**
- https://github.com/yourname/myproject/pull/YYY - [Brief description]

**Merge this PR first before the dependent PRs above.**

---

## Summary
[rest of PR description]
```

### Tracking File: C:\scripts\_machine\pr-dependencies.md

Maintain a live tracking file:

```markdown
# Active PR Dependencies

| Downstream PR | Depends On (myframework) | Status |
|---------------|---------------------|--------|
| myproject#45 | myframework#2, myframework#8 | ⏳ Waiting |
| myproject#46 | myframework#7 | ✅ Ready (myframework merged) |
```

### ENFORCEMENT

**Before creating ANY myproject PR:**
1. Check if it uses new myframework features/changes
2. If YES: Find or create the corresponding myframework PR
3. Add dependency header to BOTH PRs
4. Update pr-dependencies.md

**Before merging ANY myframework PR:**
1. Check pr-dependencies.md for dependent myproject PRs
2. Notify user about merge order
3. Update tracking after merge

## 🔄 SYNC RULE: PULL AFTER PUSH TO C:\Projects

**CRITICAL: After pushing changes from worktrees, ALWAYS pull to C:\Projects\<repo>**

### Why This Matters
- C:\Projects\<repo> is the BASE repository used for reading, debugging, and creating new worktrees
- If you push changes from a worktree but don't pull to C:\Projects, the base is out of sync
- Next worktree created from C:\Projects will be missing your changes
- Builds in Visual Studio (which uses C:\Projects) will have stale code

### Mandatory Workflow

```powershell
# After pushing from worktree:
cd C:\Projects\worker-agents\agent-XXX\<repo>
git push origin <branch>

# IMMEDIATELY pull to base repo:
cd C:\Projects\<repo>
git pull origin develop   # If pushed to develop
# OR
git fetch origin          # If pushed to feature branch (for PR)
```

### When to Pull to C:\Projects

| Scenario | Action |
|----------|--------|
| Pushed to develop branch | `git pull origin develop` in C:\Projects\<repo> |
| Pushed feature branch (for PR) | `git fetch origin` (updates remote refs) |
| PR was merged to develop | `git pull origin develop` in C:\Projects\<repo> |
| Multiple PRs merged | Pull after EACH merge to keep base current |

### Examples

```bash
# After pushing build fixes to myproject develop:
cd /c/Projects/myproject
git pull origin develop

# After pushing CI fix to myframework develop:
cd /c/Projects/myframework
git pull origin develop
```

**ENFORCEMENT:** If you see stale code errors or "file not found" in C:\Projects, you forgot to pull!


## 📋 GIT-FLOW WORKFLOW RULES

**Branch strategy (MANDATORY):**

```
main ← develop ← feature branches
```

### PR Target Rules

| Source Branch | Target Branch |
|---------------|---------------|
| feature/* | develop |
| agent-*-feature | develop |
| improvement/* | develop |
| fix/* | develop |
| develop | main |

**NEVER create PRs from feature branches directly to main!**

### Correcting Wrong PR Base

If a PR was created with wrong base:
```bash
gh pr edit <number> --base develop
```

### Checking All Open PRs

```bash
# List all open PRs with their base branches:
gh pr list --state open --json number,headRefName,baseRefName \
  --jq '.[] | "\(.number): \(.headRefName) -> \(.baseRefName)"'
```

### Branch Cleanup After Merge (MANDATORY)

**RULE: Only `develop` and `main` branches are persistent. All others are temporary.**

**When merging PRs - ALWAYS delete the branch:**
```bash
# Option 1: Delete during merge (PREFERRED)
gh pr merge <number> --squash --delete-branch

# Option 2: Delete manually after merge
git push origin --delete <branch-name>

# Option 3: Clean up stale branches periodically
git fetch --prune  # Remove deleted remote refs locally
```

**Finding stale branches (merged but not deleted):**
```bash
# List remote branches not merged with develop
git branch -r --no-merged origin/develop | grep -v HEAD

# Check if branch has merged PR
gh pr list --state all --head <branch-name> --json number,state
# If state=MERGED → delete the branch
```

**Cleanup command for stale branches:**
```bash
# After confirming PR is merged:
git push origin --delete <branch-name>
```

### Stable Release Tagging (MANDATORY)

**RULE: After stabilizing main (critical fixes merged, tests pass), tag BOTH repos with same identifier.**

**Tag format:** `v{YYYY}.{MM}.{DD}-stable`

**Tagging workflow:**
```bash
# Tag myframework
cd /c/Projects/myframework && git checkout main && git pull origin main
git tag -a "vYYYY.MM.DD-stable" -m "Stable release checkpoint - YYYY-MM-DD

Summary of changes:
- PR #X: Description
- PR #Y: Description

Signed-off-by: Claude <noreply@anthropic.com>"
git push origin vYYYY.MM.DD-stable

# Tag myproject (SAME tag name!)
cd /c/Projects/myproject && git checkout main && git pull origin main
git tag -a "vYYYY.MM.DD-stable" -m "Stable release checkpoint - YYYY-MM-DD

Summary of changes:
- PR #X: Description
- PR #Y: Description

Signed-off-by: Claude <noreply@anthropic.com>"
git push origin vYYYY.MM.DD-stable

# Return to develop
cd /c/Projects/myframework && git checkout develop
cd /c/Projects/myproject && git checkout develop
```

**When to tag:**
- After merging critical bug fixes to main
- After completing a milestone/sprint
- Before major refactoring
- When user requests a checkpoint

**Current stable tag:** `v2026.01.08-stable` (both repos)

**Listing tags:**
```bash
git tag -l "v*-stable" --sort=-creatordate | head -5
```

---

## 📚 See Also

**Related workflows:**
- **Worktree Protocol:** `GENERAL_WORKTREE_PROTOCOL.md` - Complete worktree allocation and release
- **Dual-Mode Workflow:** `GENERAL_DUAL_MODE_WORKFLOW.md` - Feature Development vs Active Debugging
- **Definition of Done:** `C:\scripts\_machine\DEFINITION_OF_DONE.md` - PR merge criteria

**External system documentation:**
- **GitHub Integration:** `C:\scripts\_machine\knowledge-base\04-EXTERNAL-SYSTEMS\github-integration.md` - Complete GitHub setup
- **Git Repositories:** `C:\scripts\_machine\knowledge-base\03-DEVELOPMENT\git-repositories.md` - All repo details

**Automation tools:**
- **PR Dependencies:** `C:\scripts\tools\validate-pr-base.ps1`
- **PR Merge Sequencer:** `C:\scripts\tools\merge-pr-sequence.ps1`
- **Branch Cleanup:** `C:\scripts\tools\prune-branches.ps1`, `cleanup-stale-branches.ps1`

**PR management skills:**
- **GitHub Workflow Skill:** `C:\scripts\.claude\skills\github-workflow\`
- **PR Dependencies Skill:** `C:\scripts\.claude\skills\pr-dependencies\`

