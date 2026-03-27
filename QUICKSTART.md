# Claude Agent Quick Start

**Read time: 2 minutes**

---

## Instant Status Check

```powershell
# One command to see everything
.\tools\bootstrap-snapshot.ps1 -Generate
```

Output tells you:
- Free/busy worktree seats
- Base repo branches (should be `develop`)
- Active worktrees
- Recent learnings

---

## The Two Modes

### Feature Development Mode
**Trigger:** User asks for new feature, refactoring, changes

```
1. Allocate worktree → Mark BUSY in pool.md
2. Work in C:\Projects\worker-agents\agent-XXX\<repo>
3. Create PR → Release worktree → Mark FREE
```

### Active Debugging Mode
**Trigger:** User posts errors, says "I'm debugging", "fix this build"

```
1. Work directly in C:\Projects\<repo>
2. Stay on user's current branch
3. Make fixes, don't create PRs unless asked
```

---

## Core Files

| File | Purpose | When to Read |
|------|---------|--------------|
| `_machine/worktrees.pool.md` | Seat allocation | Before any code edit |
| `_machine/reflection.log.md` | Past learnings | When hitting problems |
| `ZERO_TOLERANCE_RULES.md` | Hard stop rules | When unsure |

---

## Common Commands

```powershell
# Check system health
.\tools\bootstrap-snapshot.ps1

# Check worktree status
.\tools\worktree-status.ps1

# Release all worktrees
.\tools\worktree-release-all.ps1 -AutoCommit

# Run repo dashboard
bash tools/repo-dashboard.sh
```

---

## The 4 Rules (Feature Mode)

1. **Allocate before edit** - Read pool.md, mark BUSY
2. **Work in worktree** - Never edit C:\Projects\<repo> directly
3. **Release after PR** - Clean up, mark FREE, switch to develop
4. **Follow scripts folder** - CLAUDE.md is law

---

## When In Doubt

1. Run `.\tools\bootstrap-snapshot.ps1`
2. Read `ZERO_TOLERANCE_RULES.md`
3. Check `_machine/reflection.log.md` for similar situations

---

**Full Manual:** `CLAUDE.md`
**Machine Config:** `MACHINE_CONFIG.md`
