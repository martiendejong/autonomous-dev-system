# Operational Rules (Single Source of Truth)

All rules in one place. No duplicates. No contradictions. <5KB.

---

## Mode Detection (ALWAYS FIRST)

| Signal | Mode | Workspace |
|--------|------|-----------|
| ClickUp URL/task ID | Feature Development | Worktree |
| New feature request | Feature Development | Worktree |
| Build errors, "I'm debugging" | Active Debugging | Base repo |
| Quick fix on user's branch | Active Debugging | Base repo |

---

## Feature Development Rules

### Before Code Edit
1. Check `_machine/worktrees.pool.md` for FREE seat
2. **Verify feature doesn't exist** (automated - see below)
3. Ensure base repo on develop: `git -C C:\Projects\<repo> checkout develop && git pull`
4. Create worktree: `git worktree add C:\Projects\worker-agents\agent-XXX\<repo> -b <branch>`
5. For client-manager: ALWAYS create paired hazina worktree (same branch name)
6. Mark seat BUSY, log in activity.md

### Feature-Exists Check (AUTOMATED GATE)
Before creating any PR or starting feature work:
```bash
# In develop branch of relevant repo:
git log --oneline --all --grep="<feature>" | head -10
ls ClientManagerAPI/Controllers/ | grep -i <feature>
ls ClientManagerAPI/Services/ | grep -i <feature>
grep -r "class <Feature>" ClientManagerAPI/ --include="*.cs"
```
If feature EXISTS → **STOP**. Do NOT proceed.

### Before PR Merge
1. Merge develop INTO feature branch: `git merge origin/develop --no-edit`
2. Resolve conflicts if any
3. Build & test locally
4. THEN merge PR

### After PR Created (3-step release)
1. Clean worktree + mark FREE in pool.md
2. Switch base repos to develop + prune worktrees
3. Present PR to user

### PR Format
- Base: ALWAYS `develop` (never `main` unless release)
- Flag: `gh pr create --base develop`
- Language: English titles and descriptions
- Link to ClickUp task

---

## Active Debugging Rules

1. Work in `C:\Projects\<repo>` on user's current branch
2. Do NOT allocate worktree
3. Do NOT switch branches
4. Do NOT create PRs (unless user explicitly asks)
5. Focus on fast turnaround

---

## ClickUp Rules

- ClickUp task = Feature Development Mode (non-negotiable)
- Always assign when changing status: `-Assignee "74525428"`
- No task ID given + feature work → CREATE task immediately
- Apply MoSCoW prioritization before implementation
- List IDs: hazina=901215559249, client-manager=901214097647, art-revisionist=901211612245

---

## Deployment Rules

BEFORE deploying ANY service:
1. Read `MACHINE_CONFIG.md` (search for service name/port)
2. Read installer docs if applicable
3. Read existing config files
4. Verify config matches docs
5. THEN execute

Never guess ports/protocols. Never trial-and-error.

---

## Testing Rules

- Use the EXACT tool user specifies (Playwright, Browser MCP, etc.)
- No substitutions (don't use curl when Playwright was requested)
- Provide evidence: screenshots, logs, actual browser behavior
- API working ≠ UI working

---

## Git Rules

- PRs always to `develop` (never `main` unless release)
- Always merge develop into branch before merging PR
- Confirm before destructive operations (force push, reset --hard, branch -D)
- Generated content (commits, PRs, comments) always in English

---

## Communication

- Compact, conversational, person-to-person
- Sass welcome, corporate speak not
- Structure only when it genuinely helps

### Status Reporting (MANDATORY)
**ALWAYS end task responses with:**
```
STATUS: [Clear headline of current state]
Description of what was accomplished/current situation
```

**Examples:**
```
STATUS: Knowledge system integrated and tested
All 8 tools built, quick-context auto-loads at startup (53x faster), 100% context completeness.

STATUS: PR #123 created and worktree released
Feature implemented, tests passing, PR ready for review in client-manager develop branch.

STATUS: Build failed - missing dependency
dotnet build errors in Hazina framework, needs Microsoft.Extensions.Http package.
```

---

## Exemptions

Check `MACHINE_CONFIG.md` § Projects for worktree-exempt projects (e.g., hydro-vision-website).

---

**Why this file exists:** Previously rules were scattered across 8+ files with subtle contradictions. This is now the single source of truth. If a rule isn't here, it doesn't apply.

**Last Updated:** 2026-02-09
