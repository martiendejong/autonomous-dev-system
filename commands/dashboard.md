# Dashboard Command

Show a comprehensive overview of all managed repositories, including branches, PRs, CI status, and agent pool health.

## What It Shows

### For Each Repository:

1. **Branch Status**
   - Current branch (should be base branch like `develop`)
   - Uncommitted changes (should be none)
   - Unpushed commits
   - Status: ✅ Clean / ⚠️ Dirty

2. **Recent Commits** (last 3)
   - Commit hash
   - Author
   - Message
   - Time

3. **Open Pull Requests**
   - PR number and title
   - Base branch (verify targets develop!)
   - Status: OPEN / DRAFT / MERGEABLE / CONFLICTING
   - CI status: ✅ Passing / ❌ Failing / ⏳ Running
   - Created by and when

4. **CI/CD Status**
   - Latest workflow runs
   - Build status
   - Test status
   - Deployment status

### Agent Pool Overview:

- Total agents
- FREE vs BUSY
- Stale agents (if any)
- Worktree health

## Usage

```
/dashboard
```

## Example Output

```
╔═══════════════════════════════════════════════════════════╗
║                  REPOSITORY DASHBOARD                      ║
╚═══════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 client-manager
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Branch: develop ✅ Clean (0 uncommitted, 0 unpushed)
Last updated: 2 hours ago

Recent Commits:
  abc1234  fix: Resolve DI injection error (2h ago)
  def5678  feat: Add ROI calculator (5h ago)
  ghi9012  docs: Update API documentation (1d ago)

Open PRs: 3

  #101 feat: Add smart scheduling ✅ MERGEABLE
       CI: ✅ Build passing | ✅ Tests passing
       Base: develop | Created 3h ago by claude-code

  #99  fix: Frontend auth interceptor ⏳ PENDING
       CI: ⏳ Tests running... | ✅ Build passing
       Base: develop | Created 1d ago by claude-code

  #95  feat: Multi-language support ⚠️  CONFLICTING
       CI: ❌ Build failing | - Tests skipped
       Base: main ⚠️  WRONG BASE! Should be 'develop'
       Created 3d ago by claude-code

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 hazina
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Branch: develop ✅ Clean (0 uncommitted, 0 unpushed)
Last updated: 5 hours ago

Recent Commits:
  jkl3456  fix: OpenAI config migration (5h ago)
  mno7890  feat: Add model routing (1d ago)
  pqr1234  test: Add integration tests (2d ago)

Open PRs: 1

  #45  feat: Semantic cache improvements ✅ MERGED
       Merged 1d ago
       🎉 Success!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 AGENT POOL STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Pool: 12 agents
FREE: 8 agents (67%) ✅ Healthy
BUSY: 4 agents (33%)
STALE: 1 agent ⚠️  Needs attention

💡 Run /worktree:status for detailed agent breakdown

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚨 ACTION ITEMS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  PR #95 targets wrong base branch (main → should be develop)
    Fix: gh pr edit 95 --base develop

⚠️  Agent agent-007 is stale (PR #45 merged)
    Fix: /worktree:release agent-007 "feat: Semantic cache"

✅ Ready to merge: PR #101
    Action: gh pr merge 101 --squash --delete-branch
```

## Benefits

- **At-a-glance status** of entire development environment
- **Catch issues early** (wrong base branches, stale agents, failing CI)
- **Prioritize work** (see what's ready to merge vs needs attention)
- **Health check** before starting new work

## Implementation

Aggregate data from git, gh CLI, worktree pool, and CI status.

$SHELL_COMMAND: bash "${PLUGIN_DIR}/scripts/dashboard.sh"
