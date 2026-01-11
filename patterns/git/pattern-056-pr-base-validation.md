# Pattern 56: PR Base Branch Validation

**Category:** Git Workflow
**Severity:** CRITICAL
**Status:** MANDATORY RULE

---

## Problem

GitHub CLI (`gh`) **defaults to `main` branch** if `--base` not specified.

**Result:**
- Feature PR targets `main` instead of `develop`
- Merge would bypass git-flow workflow
- Code goes to production without staging
- Wrong merge conflicts (feature vs main, not feature vs develop)

## Root Cause

**gh CLI default behavior:**
```bash
gh pr create --title "..."
# Defaults to: --base main
# NOT --base develop!
```

**GitHub's assumption:** Most repos use `main` as primary branch

**Your workflow:** Uses git-flow (develop → main)

## Solution

**ALWAYS specify `--base develop` explicitly:**

```bash
# ✅ CORRECT
gh pr create --base develop --title "..." --body "..."

# ❌ WRONG
gh pr create --title "..."  # Defaults to main!
```

### Verification (MANDATORY)

**Immediately after creating PR:**

```bash
PR_NUM=<number>

# Check actual base branch
gh pr view $PR_NUM --json baseRefName -q '.baseRefName'
# Must output: develop

# Full verification
gh pr view $PR_NUM --json baseRefName,headRefName
# Output:
# {
#   "baseRefName": "develop",    ← MUST be develop
#   "headRefName": "feature/..." ← Your branch
# }
```

### Correction (If Wrong Base)

```bash
# Fix PR base branch
gh pr edit $PR_NUM --base develop

# Verify fixed
gh pr view $PR_NUM --json baseRefName -q '.baseRefName'
# Output: develop
```

## When to Use

**EVERY time creating PR from:**
- ✅ Feature branches (`feature/*`)
- ✅ Fix branches (`fix/*`)
- ✅ Improvement branches (`improvement/*`)
- ✅ Agent branches (`agent-XXX-*`)
- ✅ ANY branch targeting develop

**Exception:** Releases (develop → main)
```bash
# When merging to main (releases only)
gh pr create --base main --title "Release v1.0.0" ...
```

## Benefits

✅ **Correct merge target** - PRs go to develop, not main
✅ **Proper git-flow** - develop → staging → main
✅ **Right conflicts** - Compare against develop (relevant), not main (stale)
✅ **Easy review** - Reviewer sees changes since develop, not all of develop

## Git-Flow Branching Strategy

```
main (production)
  ↑
  | (release PR)
  |
develop (staging)
  ↑
  | (feature PR ← ALWAYS target this)
  |
feature/user-auth
```

**Critical Rule:**
- Feature branches → `develop` (ALWAYS)
- Develop → `main` (releases only)

## Real Example

**Before (wrong base):**
```bash
# Created PR without --base
gh pr create --title "feat: Add auth"
# PR #45 created: feature/auth → main

# Result: Conflicts with main (wrong comparison)
# Bypasses develop (breaks git-flow)
```

**After (correct base):**
```bash
# Created PR with --base develop
gh pr create --base develop --title "feat: Add auth"
# PR #45 created: feature/auth → develop

# Verify
gh pr view 45 --json baseRefName
# Output: {"baseRefName":"develop"}

# Result: Clean PR, proper workflow
```

## Detection: Find Wrong Base PRs

```bash
# List all open PRs with base branches
gh pr list --state open --json number,headRefName,baseRefName \
  --jq '.[] | "\(.number): \(.headRefName) → \(.baseRefName)"'

# Example output:
# 45: feature/auth → main        ← ⚠️  WRONG!
# 46: fix/bug-123 → develop      ← ✅ Correct
# 47: improvement/perf → main    ← ⚠️  WRONG!

# Fix wrong bases:
gh pr edit 45 --base develop
gh pr edit 47 --base develop
```

## Integration with Worktree Scripts

The worktree release script enforces this:

```bash
# In release-worktree.sh/cmd
gh pr create \
  --base develop \        # ← Pattern 56
  --title "$PR_TITLE" \
  --body "..."

# Then verify
gh pr view $PR_NUM --json baseRefName
# Ensures correct base
```

## Prevention Checklist

**Before creating ANY PR:**
1. ✅ Merged latest develop (Pattern 52)
2. ✅ Using `--base develop` flag (Pattern 56)
3. ✅ Verified base after creation (Pattern 56)
4. ✅ Checked CI status (all checks passing)

## Common Mistakes

❌ **Assuming gh knows your workflow:**
```bash
# gh doesn't know you use git-flow
# It defaults to main, not develop
```

❌ **Fixing base after review started:**
```bash
# PR #45 reviewed with wrong conflicts
# Later changed to develop
# Reviewer confused by changed diff
```

❌ **Batch fixing multiple PRs:**
```bash
# Better: Fix immediately after creation
# Not: Discover during PR review dashboard
```

## Automation Ideas

**Git alias:**
```bash
# Add to .gitconfig
[alias]
  pr = "!gh pr create --base develop"

# Usage:
git pr --title "..." --body "..."
```

**PreToolUse Hook (Future):**
```javascript
// Warn if gh pr create without --base
if (command.includes('gh pr create') && !command.includes('--base')) {
  throw new Error('Missing --base flag! Use: gh pr create --base develop');
}
```

## Related Patterns

- **Pattern 24:** PR Base Branch Validation (duplicate, same pattern)
- **Pattern 52:** Merge Develop Before PR (do this first)
- **Pattern 63:** Agent Release Protocol (uses this pattern)

## Time Investment

**10 seconds** to add `--base develop` **vs.** hours fixing wrong merge target

---

**Created:** 2026-01-11
**Last Updated:** 2026-01-11
**Status:** Active, enforced in worktree-release.sh
**Severity:** CRITICAL - Wrong base breaks git-flow
