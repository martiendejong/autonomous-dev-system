---
name: debug-mode
description: Switch to Active Debugging Mode - for fixing build errors, helping user debug
triggers:
  - /debug
  - debug mode
  - fix this
  - build error
  - debugging
invocation: user
---

# Active Debugging Mode

**Use this mode when:** User posts build errors, says they're debugging, or needs quick fixes.

---

## Step 0: Consciousness Bridge (FIRST)

Call the bridge BEFORE starting debug work. This loads failure patterns for the project.

```bash
powershell.exe -File "C:/scripts/tools/consciousness-bridge.ps1" -Action OnTaskStart -TaskDescription "<error description>" -Project "<project-name>" -Silent
```

---

## Mode Detection

Enter this mode if ANY are true:
- User posts build errors or error output
- User says "I'm working on branch X"
- User says "fix this" or "debug this"
- User is actively developing and needs quick help

---

## Rules

1. **DO** work directly in `C:\Projects\<repo>`
2. **DO** stay on user's current branch
3. **DO NOT** allocate worktrees
4. **DO NOT** switch branches
5. **DO NOT** create PRs (unless explicitly asked)

---

## Quick Start

```powershell
# Check user's current branch
git -C C:\Projects\client-manager branch --show-current

# Check for uncommitted changes
git -C C:\Projects\client-manager status

# Make fixes directly in C:\Projects\<repo>
# User will test and commit when ready
```

---

## Workflow

```
1. Understand the error
2. Check user's current branch (preserve it!)
3. Make targeted fixes
4. Let user test
5. User decides on commit/PR
```

---

## Exit Criteria

Session ends when:
- [x] User's immediate issue is resolved
- [x] Branch state preserved (NOT changed)
- [x] User can continue their work

---

## When to Switch to Feature Mode

Switch to Feature Development Mode if:
- User explicitly asks for a new feature
- User asks for major refactoring
- Work expands beyond quick fix
- You realize this needs a proper PR

---

## Step Last: Consciousness Bridge (AFTER)

When the debug task is resolved, close the feedback loop:

```bash
powershell.exe -File "C:/scripts/tools/consciousness-bridge.ps1" -Action OnTaskEnd -Outcome "success" -LessonsLearned "<what fixed the issue>" -Silent
```

Use "success", "partial", or "failure" based on outcome.

---

## Related

- `ZERO_TOLERANCE_RULES.md`
- `GENERAL_DUAL_MODE_WORKFLOW.md`
- `problem-solution-index.md`
