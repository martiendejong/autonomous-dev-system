# Git Workflow - Branch Strategy

**Last Updated:** 2026-01-07
**Status:** Canonical workflow for all repositories

---

## Branch Structure

```
main (production)
  ↑
  PR ← develop (integration)
       ↑
       PR ← feature/agent-XXX-feature-name (worktree)
```

---

## Workflow Rules

### 1. Branch Creation

**ALWAYS:**
- Create new feature branches from `main` (NOT from develop)
- Use naming convention: `agent-XXX-feature-name`
- Work in allocated worktree: `C:\Projects\worker-agents\agent-XXX\<repo>`

**Example:**
```bash
# In worktree
cd C:\Projects\worker-agents\agent-002\client-manager
git checkout main
git pull origin main
git checkout -b agent-002-tool-agent-implementation
```

### 2. Development

**ALWAYS:**
- Make commits in worktree branch
- Use descriptive commit messages
- Include Co-Authored-By for Claude Code
- Test before committing

**Example commit:**
```bash
git add .
git commit -m "feat: add ToolAgentService with InvokeToolAgent tool

Implements 3-layer architecture:
- Chat agent → Tool agent → Specialized tools
- Token optimization via selective context loading

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

### 3. Pull Request

**ALWAYS:**
- Create PR from feature branch → `develop` (NOT main)
- PR title: Clear, concise description
- PR body: Summary, test plan, changes
- Request review if needed

**Example:**
```bash
# Push branch
git push -u origin agent-002-tool-agent-implementation

# Create PR using gh CLI
gh pr create --base develop --title "feat: implement 3-layer tool agent architecture" --body "$(cat <<'EOF'
## Summary
- Implements ToolAgentService for orchestration layer
- Adds InvokeToolAgentTool to chat agent
- Enables async/sync execution modes

## Changes
- New: Hazina.Tools.Services.ToolAgent/
- Modified: ChatService.cs to add tool

## Test Plan
- [x] Unit tests for ToolAgentService
- [x] Integration test: chat → tool agent → UpdateAnalysisField
- [ ] Manual test: full conversation flow

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### 4. After PR Merge

**ALWAYS:**
- Mark worktree seat as FREE in `worktrees.pool.md`
- Log completion in `worktrees.activity.md`
- Delete local feature branch (optional)
- Remove worktree if no longer needed

**Example:**
```bash
# After PR merged to develop
git worktree remove C:\Projects\worker-agents\agent-002\client-manager
git branch -d agent-002-tool-agent-implementation

# Update worktrees.pool.md
# Mark agent-002 as FREE
```

---

## Branch Purposes

| Branch | Purpose | Who Updates | PR Target |
|--------|---------|-------------|-----------|
| `main` | Production-ready code | Auto (from develop PR) | N/A |
| `develop` | Integration branch | Auto (from feature PRs) | → main |
| `agent-XXX-*` | Feature development | Claude agent in worktree | → develop |

---

## Key Rules

### ✅ DO

1. **Always branch from `main`**
   - Ensures clean base
   - Avoids incomplete develop changes

2. **Always PR to `develop`**
   - Allows integration testing
   - Develop → main happens separately

3. **Always work in worktrees**
   - Isolated environment
   - No conflicts with main checkout

4. **Always include evidence**
   - Commit hashes
   - Test results
   - File paths

### ❌ DON'T

1. **Don't branch from `develop`**
   - Develop may have unstable changes
   - Use main as base

2. **Don't PR directly to `main`**
   - Main is protected
   - Use develop as integration point

3. **Don't edit in C:\Projects\<repo>**
   - Read-only for main checkout
   - Use worktrees for edits

4. **Don't merge without PR**
   - No direct pushes to develop/main
   - Always use PR flow

---

## Example Full Flow

### Scenario: Implement Tool Agent

```bash
# 1. Allocate worktree (if not exists)
cd C:\Projects\client-manager
git worktree add C:\Projects\worker-agents\agent-002\client-manager -b agent-002

# 2. Create feature branch from main
cd C:\Projects\worker-agents\agent-002\client-manager
git checkout main
git pull origin main
git checkout -b agent-002-tool-agent-service

# 3. Make changes, commit
# ... edit files ...
git add .
git commit -m "feat: add ToolAgentService

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# 4. Push and create PR to develop
git push -u origin agent-002-tool-agent-service
gh pr create --base develop --title "feat: implement tool agent service"

# 5. After PR merged
# Update worktrees.pool.md: agent-002 = FREE
# Log in worktrees.activity.md
```

---

## Worktree Activity Logging

After each workflow completion, update `worktrees.activity.md`:

```markdown
## 2026-01-07 18:45 UTC - agent-002 - Tool Agent Implementation

- **Branch:** agent-002-tool-agent-service
- **Base:** main
- **PR:** #123 → develop
- **Status:** Merged
- **Commits:** 5
- **Files changed:** 12
- **Evidence:**
  - Commit: abc1234
  - Tests: All passing
  - PR: https://github.com/user/repo/pull/123
```

---

## Emergency Hotfix Flow

For critical production issues:

```bash
# 1. Branch from main
git checkout main
git pull origin main
git checkout -b hotfix-critical-bug

# 2. Fix, commit, test
# ... fix ...
git commit -m "fix: critical security vulnerability"

# 3. PR to develop first
gh pr create --base develop

# 4. After develop PR merged, create PR to main
git checkout main
git pull origin main
git merge develop
gh pr create --base main --title "hotfix: critical security fix"
```

---

## Validation Checklist

Before creating PR:

- [ ] Branch created from `main`
- [ ] All work in worktree (`C:\Projects\worker-agents\agent-XXX\`)
- [ ] Commits have descriptive messages
- [ ] Tests pass
- [ ] PR targets `develop` (not main)
- [ ] PR includes summary and test plan
- [ ] Worktree allocation logged

---

## References

- Worktree pool: `C:\scripts\_machine\worktrees.pool.md`
- Activity log: `C:\scripts\_machine\worktrees.activity.md`
- Control plane: `C:\scripts\claude.md`

---

**This is the canonical workflow. All agents must follow this.**
