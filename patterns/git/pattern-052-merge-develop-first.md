# Pattern 52: Merge Develop Before Creating PR

**Category:** Git Workflow
**Severity:** CRITICAL
**Status:** MANDATORY RULE

---

## Problem

Feature branches diverge from develop during work. Creating PRs without merging latest develop leads to:
- Merge conflicts discovered late (in GitHub, not locally)
- Tests run against stale codebase
- Integration issues not caught before review
- Difficult code review due to conflicts

## Root Cause

While you work on a feature branch:
1. Other developers merge changes to develop
2. Your branch becomes outdated
3. Your code may conflict with new changes
4. Tests may pass locally but fail with latest develop

## Solution

**ALWAYS merge origin/develop into feature branch BEFORE creating PR:**

```bash
# In your feature branch worktree
cd C:/Projects/worker-agents/agent-XXX/<repo>

# Fetch latest changes
git fetch origin --prune

# Merge develop into feature branch
git merge origin/develop --no-edit

# Resolve any conflicts NOW (locally, not in GitHub)
# If conflicts:
git status  # See conflicting files
# Edit files to resolve
git add <resolved-files>
git commit -m "Merge develop into feature branch"

# Re-run tests against merged code
dotnet test  # Backend
npm test     # Frontend

# Commit merge if needed
git push origin <feature-branch>

# NOW create PR (clean, up-to-date)
gh pr create --base develop --title "..." --body "..."
```

## When to Use

**ALWAYS - Before EVERY PR creation:**
- ✅ Feature branches before PR
- ✅ Fix branches before PR
- ✅ Improvement branches before PR
- ✅ ANY branch targeting develop

**Especially critical when:**
- Work took multiple days (develop has likely changed)
- CI/CD workflows were updated
- Dependencies were upgraded in develop
- Multiple developers working on same codebase

## Benefits

✅ **Conflicts resolved locally** - Use your IDE, debugger, full toolset
✅ **Tests run against current code** - No surprises in CI
✅ **Clean PR** - Reviewer sees only your changes
✅ **Easy review** - No conflict markers obscuring code
✅ **Fast merge** - PR ready to merge immediately if approved

## Real Example

**Before (bad):**
```
develop:  A---B---C---D---E (other PRs merged)
                 \
feature:          F---G (your work)
                      ^
                      PR created here → CONFLICTS!
```

**After (good):**
```
develop:  A---B---C---D---E
                 \         \
feature:          F---G---M (merged develop)
                          ^
                          PR created here → CLEAN!
```

## Integration with Worktree Release

This pattern is **built into** the worktree release script:

```bash
# In release-worktree.sh/cmd
git fetch origin
git merge origin/develop  # ← Pattern 52
# Resolve conflicts if any
git push origin <branch>
gh pr create --base develop ...  # ← Pattern 56
```

## Verification

```bash
# Check if your branch has latest develop
git log --oneline develop..origin/develop
# If empty → you have latest develop
# If shows commits → need to merge

# Verify merge succeeded
git log --oneline -1
# Should show merge commit if conflicts resolved
```

## Common Mistakes

❌ **Creating PR first, merging later:**
- PR shows conflicts
- Reviewer sees merge commits mixed with feature
- Hard to review

❌ **Merging GitHub's base branch instead of origin/develop:**
- May not be latest (caching)
- Use `origin/develop` always

❌ **Skipping tests after merge:**
- Merge may break tests
- CI fails, PR blocked

## Related Patterns

- **Pattern 4:** Large File Merge Conflicts (how to resolve)
- **Pattern 56:** PR Base Branch Validation (what base to target)
- **Pattern 57:** Strategic --theirs Resolution (conflict strategy)

## Time Investment

**2 minutes** to merge develop **vs.** hours debugging conflicts in GitHub

---

**Created:** 2026-01-11
**Last Updated:** 2026-01-11
**Status:** Active, enforced in worktree-release.sh
