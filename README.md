# Autonomous Development System

**Battle-tested autonomous agent protocols for Claude Code with worktree management, zero-tolerance enforcement, and 75+ documented patterns.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude_Code->=0.10.0-blue)](https://code.claude.com)
[![Cross-Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac%20%7C%20Linux-green)](https://github.com)

---

## 🎯 What Is This?

A comprehensive plugin for Claude Code that provides:

- **Atomic Worktree Management** - Parallel development without conflicts
- **Zero-Tolerance Enforcement** - Automatic prevention of workflow violations
- **75+ Documented Patterns** - Solutions to common CI/CD and development issues
- **Cross-Repo Coordination** - Manage complex multi-repository workflows
- **Self-Improving System** - Reflection logging captures lessons learned
- **10 Productivity Tools** - Dashboard, PR status, coverage, and more

Designed for serious multi-repo development with enforced best practices.

---

## 🚀 Quick Start

### Prerequisites

- **Claude Code** >= 0.10.0
- **Git** with worktree support
- **Node.js** >= 16 (for hooks)
- **GitHub CLI** (`gh`) for PR operations
- **Bash** or **PowerShell** (depending on OS)

### Installation

1. **Clone or download this repository:**

   ```bash
   git clone https://github.com/yourusername/autonomous-dev-system.git
   cd autonomous-dev-system
   ```

2. **Run the installation wizard:**

   **On Mac/Linux/Git Bash:**
   ```bash
   bash setup.sh
   ```

   **On Windows PowerShell:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File setup.ps1
   ```

3. **Answer the prompts:**
   - Control plane directory (stores logs, pool data)
   - Repositories to manage (name, path, base branch)
   - Worktree base path (where agent directories are created)
   - Agent pool size (default: 12)
   - Preferred shell

4. **Install the plugin in Claude Code:**

   ```bash
   claude plugin install --local /path/to/autonomous-dev-system
   ```

   Or use during development:
   ```bash
   claude --plugin-dir="/path/to/autonomous-dev-system"
   ```

---

## 📋 Core Concepts

### Worktrees

**Git worktrees** are isolated working directories that allow multiple branches to be checked out simultaneously. This enables:

- **Parallel Development** - Multiple agents working on different features
- **Zero Conflicts** - Each agent has its own files
- **Clean State** - Base repos remain untouched

### Agent Pool

A pool of **N agents** (default: 12), each with:
- A seat number (`agent-001` to `agent-012`)
- A status (**FREE** or **BUSY**)
- A dedicated worktree directory

When you start work, you **claim** a FREE agent. When done, you **release** it back to the pool.

### Zero-Tolerance Enforcement

The PreToolUse hook **automatically prevents** violations:
- ❌ Editing in base repos (must use worktrees)
- ❌ Creating PRs without specifying base branch
- ❌ Committing in base repos via bash

**No more mistakes** - the system stops you before you break the workflow.

---

## 🛠️ Available Commands

### `/worktree:claim <branch> <description>`

Atomically allocate a worktree for new work.

**Example:**
```
/worktree:claim feature/user-auth "Implement JWT authentication"
```

**What it does:**
1. Finds a FREE agent
2. Marks it BUSY
3. Creates worktrees for all configured repos
4. Logs the allocation
5. Copies config files (appsettings.json, .env)

**After claiming:**
- Edit ONLY in `<worktree-path>/agent-XXX/<repo>/`
- NEVER edit in base repo paths

---

### `/worktree:release <agent> <pr-title>`

Complete work and release worktree back to pool.

**Example:**
```
/worktree:release agent-001 "feat: Add JWT authentication"
```

**What it does:**
1. Commits all changes
2. Merges latest develop (avoids conflicts)
3. Pushes to remote
4. Creates PRs (with correct base branch)
5. Cleans worktrees
6. Marks agent FREE
7. Updates base repos

**Critical:** ALWAYS release after creating PR, BEFORE presenting to user.

---

### `/worktree:status`

Show agent pool status and detect stale allocations.

**Example Output:**
```
Pool Size: 12 agents
FREE: 8 (67%)
BUSY: 4 (33%)
STALE: 1 ⚠️  Needs release

agent-007 [BUSY] ⏱️  1d 3h ago  ⚠️  STALE
  PR #45: MERGED
  🚨 Release worktree!
```

**Stale agent criteria:**
- PR merged but still BUSY
- No activity > 2 hours
- Empty worktree but marked BUSY

---

### `/dashboard`

Comprehensive overview of all repos, PRs, CI status, and agent pool health.

**Shows:**
- Branch status (clean vs dirty)
- Recent commits
- Open PRs with CI status
- Action items (wrong base branches, stale agents)
- Agent pool health

Use this at session start to understand current state.

---

### `/pr:status`

Show all open PRs across all repos with CI status.

**Use when:**
- Planning which PRs to review/merge
- Checking CI health
- Finding PRs ready to merge

---

### `/patterns:search <keyword>`

Search 75+ documented patterns for solutions.

**Example:**
```
/patterns:search merge conflict
```

Returns relevant patterns like:
- Pattern 4: Large File Merge Conflicts
- Pattern 52: Merge develop before creating PR
- Pattern 57: Strategic --theirs resolution

---

## 🚨 Zero-Tolerance Rules (Enforced Automatically)

### RULE 1: Never Edit Base Repos

✅ **Allowed:**
- Read files in `C:\Projects\<repo>`
- Run builds in base repos
- Search/grep in base repos

❌ **Forbidden:**
- Edit files in `C:\Projects\<repo>`
- Write files in base repos
- Commit in base repos

**Enforcement:** PreToolUse hook throws error if you try.

---

### RULE 2: Always Specify PR Base Branch

✅ **Correct:**
```bash
gh pr create --base develop --title "..." --body "..."
```

❌ **Wrong:**
```bash
gh pr create --title "..."  # Defaults to 'main'!
```

**Enforcement:** Hook warns if `--base` missing.

**Why:** gh CLI defaults to `main` if not specified, causing wrong merge target.

---

### RULE 3: Release Worktrees After PR Creation

**Workflow:**
1. Complete work
2. Run `/worktree:release`
3. PR created
4. Worktree cleaned
5. Agent marked FREE
6. **THEN** present PR to user

**Never** leave agents BUSY after PR creation - it locks resources.

---

## 📚 Pattern Library

The plugin includes 75+ documented patterns for:

- **CI/CD Fixes** - MSB3030, NETSDK1100, NU1605, Docker tag issues
- **Git Workflows** - Merge conflicts, branch management, PR dependencies
- **Build Issues** - NuGet downgrades, namespace migrations, DI errors
- **Frontend** - Vite config, ESLint v9, npm package issues
- **Testing** - Mock patterns, coverage, integration tests
- **Security** - Secret scanning, CodeQL, Trivy false positives

**Access via:** `/patterns:search <keyword>`

**Contribute:** After solving a new issue, document it in the reflection log!

---

## 🔧 Configuration

Configuration is stored in `<control-plane>/config.json`:

```json
{
  "version": "1.0.0",
  "controlPlane": "/home/user/.autonomous-dev",
  "worktreePath": "/home/user/worker-agents",
  "agentPoolSize": 12,
  "shell": "auto",
  "repos": [
    {
      "name": "my-api",
      "path": "/home/user/projects/my-api",
      "baseBranch": "develop"
    },
    {
      "name": "frontend",
      "path": "/home/user/projects/frontend",
      "baseBranch": "main"
    }
  ]
}
```

**Reconfigure:** Edit `config.json` or re-run `setup.sh`/`setup.ps1`

---

## 🤝 Contributing

This plugin is designed to be **self-improving**. When you discover new patterns:

1. **Document in reflection log:**
   - `<control-plane>/_machine/reflection.log.md`
   - Follow the template (Problem, Root Cause, Fix, Pattern)

2. **Add to pattern library:**
   - `<control-plane>/patterns/pattern-XXX.md`
   - Use next available pattern number

3. **Update claude_info.txt:**
   - Add quick reference for common issues

4. **Submit PR** to this repository to share with community!

---

## 🐛 Troubleshooting

### "All agents BUSY"

**Solution 1:** Check for stale agents:
```
/worktree:status
```

Release any stale agents shown.

**Solution 2:** Increase pool size:
Edit `config.json` → `agentPoolSize: 20`

---

### "Configuration not found"

**Solution:** Re-run installation:
```bash
bash setup.sh
# or
powershell -File setup.ps1
```

---

### "PreToolUse hook error"

The hook is **protecting you** from a violation!

**Common causes:**
- Trying to edit in base repo instead of worktree
- No worktree allocated yet

**Fix:** Follow the error message instructions.

---

### "Wrong PR base branch"

**Symptom:** PR targets `main` instead of `develop`

**Fix:**
```bash
gh pr edit <number> --base develop
```

**Prevention:** Always use `--base develop` in `/worktree:release`

---

## 📖 Documentation

- **Setup Guide:** This README
- **Pattern Library:** `<control-plane>/patterns/`
- **Reflection Log:** `<control-plane>/_machine/reflection.log.md`
- **Activity Log:** `<control-plane>/_machine/worktrees.activity.md`
- **Pool Status:** `<control-plane>/_machine/worktrees.pool.md`

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file

---

## 🙏 Acknowledgments

Built from battle-tested protocols developed across hundreds of development sessions managing complex multi-repo projects.

**Core Principles:**
- Atomic operations prevent race conditions
- Enforcement prevents mistakes
- Documentation scales knowledge
- Reflection enables continuous improvement

---

## 🚀 Happy Autonomous Developing!

Questions? Issues? Contributions?
- GitHub Issues: [Report a bug](https://github.com/yourusername/autonomous-dev-system/issues)
- Discussions: [Share patterns](https://github.com/yourusername/autonomous-dev-system/discussions)
- PR: [Contribute code](https://github.com/yourusername/autonomous-dev-system/pulls)

**May your worktrees always be clean and your PRs always mergeable! ✨**
