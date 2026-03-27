---
name: feature-mode
description: Switch to Feature Development Mode - for new features, refactoring, planned work
triggers:
  - /feature
  - feature mode
  - new feature
  - start feature
invocation: user
---

# Feature Development Mode

**Use this mode when:** User asks for a new feature, refactoring, or planned code changes.

---

## Pre-Flight Checklist

Before any code edit in Feature Development Mode:

```
[ ] 1. Confirm this is NOT debugging (no build errors, no "fix this")
[ ] 2. Read worktrees.pool.md
[ ] 3. Find FREE seat
[ ] 4. Run worktree-allocate.ps1
[ ] 5. Mark seat BUSY
[ ] 6. Work ONLY in C:\Projects\worker-agents\agent-XXX\<repo>
```

---

## Quick Start

```powershell
# Allocate worktree for feature work
.\tools\worktree-allocate.ps1 -Repo myproject -Branch feature/<name> -Paired

# Check status
.\tools\worktree-status.ps1 -Compact
```

---

## Rules

1. **NEVER** edit in `C:\Projects\<repo>` directly
2. **ALWAYS** use allocated worktree
3. **ALWAYS** create PR before ending
4. **ALWAYS** release worktree after PR

---

## Workflow

```
1. Allocate worktree
2. Implement feature
3. Commit and push
4. Create PR (gh pr create)
5. Release worktree
6. Present PR to user
```

---

## Exit Criteria

Session ends when:
- [x] PR created and visible on GitHub
- [x] Worktree released (marked FREE)
- [x] Base repos back on develop

---

## Related

- `ZERO_TOLERANCE_RULES.md`
- `GENERAL_WORKTREE_PROTOCOL.md`
- `allocate-worktree` skill
- `release-worktree` skill
