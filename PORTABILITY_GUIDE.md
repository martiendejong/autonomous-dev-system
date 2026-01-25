# Portability Guide - Using General Rules in Claude Code Plugin

**PURPOSE:** How to adapt portable documentation for your Claude Code plugin configuration
**AUDIENCE:** Users copying these workflows to Claude Code custom instructions or plugin settings

---

## 🎯 What's Portable vs Machine-Specific?

### ✅ PORTABLE (Copy to Plugin)
Files prefixed with `GENERAL_*`:
- `GENERAL_ZERO_TOLERANCE_RULES.md`
- `GENERAL_DUAL_MODE_WORKFLOW.md`
- `GENERAL_WORKTREE_PROTOCOL.md`

These files use **variables** like `${BASE_REPO_PATH}` that you replace with your actual paths.

### ❌ MACHINE-SPECIFIC (Keep Local)
Files specific to this machine:
- `MACHINE_CONFIG.md` - Paths, projects, user settings
- `CLAUDE.md` - Index referencing local files
- `claude_info.txt` - Local agent configuration
- Files in `_machine/` folder - Operational state

These files contain **hardcoded paths** and **personal configuration** that won't work on your machine.

---

## 📋 Step-by-Step: Copy to Plugin

### Step 1: Copy General Files

1. Copy these files to your local documentation:
   ```
   GENERAL_ZERO_TOLERANCE_RULES.md
   GENERAL_DUAL_MODE_WORKFLOW.md
   GENERAL_WORKTREE_PROTOCOL.md
   ```

2. OR combine them into a single `CLAUDE_CODE_INSTRUCTIONS.md` file

### Step 2: Define Your Paths

Create your own `MACHINE_CONFIG.md` with your paths:

```markdown
# My Machine Configuration

## Directory Structure

BASE_REPO_PATH=/Users/yourname/projects
WORKTREE_PATH=/Users/yourname/projects/worker-agents
CONTROL_PLANE_PATH=/Users/yourname/.claude
MACHINE_CONTEXT_PATH=/Users/yourname/.claude/_machine

## Projects

### Project 1: my-app
- Location: /Users/yourname/projects/my-app
- Main branch: main
- Repository: github.com/yourname/my-app

## Main Branch
<main-branch>=main  (or develop, master, etc.)
```

### Step 3: Replace Variables

**Option A: Keep Variables (Recommended)**
- Keep `${BASE_REPO_PATH}` syntax in documentation
- Create `MACHINE_CONFIG.md` that Claude reads first
- Easier to update paths later

**Option B: Find & Replace**
- Open `GENERAL_*.md` files
- Find: `${BASE_REPO_PATH}` → Replace: `/Users/yourname/projects`
- Find: `${WORKTREE_PATH}` → Replace: `/Users/yourname/projects/worker-agents`
- Find: `${CONTROL_PLANE_PATH}` → Replace: `/Users/yourname/.claude`
- Find: `${MACHINE_CONTEXT_PATH}` → Replace: `/Users/yourname/.claude/_machine`
- Find: `<main-branch>` → Replace: `main` (or `develop`)
- Find: `<repo>` → Replace with actual repo names when needed

### Step 4: Add to Claude Code

**Claude Code CLI (.claude/CLAUDE.md):**
```markdown
# Claude Code Instructions

Before starting, read:
1. MACHINE_CONFIG.md - Your local paths
2. GENERAL_ZERO_TOLERANCE_RULES.md - Critical rules
3. GENERAL_DUAL_MODE_WORKFLOW.md - Mode selection
4. GENERAL_WORKTREE_PROTOCOL.md - Worktree workflow
```

**Claude.ai Custom Instructions:**
```
Paste the content of:
1. MACHINE_CONFIG.md (your paths)
2. GENERAL_DUAL_MODE_WORKFLOW.md (abbreviated)
3. Key rules from GENERAL_ZERO_TOLERANCE_RULES.md
```

---

## 🔧 Variable Reference

### Required Variables

| Variable | Example | Description |
|----------|---------|-------------|
| `${BASE_REPO_PATH}` | `/Users/you/projects` | Where main repos are cloned |
| `${WORKTREE_PATH}` | `/Users/you/projects/worker-agents` | Where agent worktrees go |
| `${CONTROL_PLANE_PATH}` | `/Users/you/.claude` | Documentation location |
| `${MACHINE_CONTEXT_PATH}` | `/Users/you/.claude/_machine` | Operational state files |
| `<main-branch>` | `develop` or `main` | Your main branch name |
| `<repo>` | `my-project` | Repository name (context-specific) |

### Optional Variables

| Variable | Example | Description |
|----------|---------|-------------|
| `<owner>` | `yourname` | GitHub username/org |
| `<number>` | `123` | PR number (context-specific) |
| `agent-XXX` | `agent-001` | Agent seat identifier |

---

## 🏗️ Directory Setup

### Create Required Directories

```bash
# Base structure
mkdir -p ${CONTROL_PLANE_PATH}
mkdir -p ${MACHINE_CONTEXT_PATH}
mkdir -p ${WORKTREE_PATH}

# Agent seats
mkdir -p ${WORKTREE_PATH}/agent-001
mkdir -p ${WORKTREE_PATH}/agent-002
mkdir -p ${WORKTREE_PATH}/agent-003

# Copy documentation
cp GENERAL_*.md ${CONTROL_PLANE_PATH}/
cp MACHINE_CONFIG.md ${CONTROL_PLANE_PATH}/
```

### Create Tracking Files

```bash
# Worktree pool status
cat > ${MACHINE_CONTEXT_PATH}/worktrees.pool.md <<EOF
# Worktree Pool Status

| Agent | Status | Current repo | Branch | Last activity | Notes |
|-------|--------|--------------|--------|---------------|-------|
| agent-001 | FREE | - | - | - | Available |
| agent-002 | FREE | - | - | - | Available |
| agent-003 | FREE | - | - | - | Available |
EOF

# Activity log
cat > ${MACHINE_CONTEXT_PATH}/worktrees.activity.md <<EOF
# Worktree Activity Log

Format: timestamp — action — agent — repo — branch — instance — executor — notes

---
EOF

# Reflection log
cat > ${MACHINE_CONTEXT_PATH}/reflection.log.md <<EOF
# Agent Reflection Log

This file tracks learnings, mistakes, and improvements across agent sessions.

---
EOF
```

---

## 🎨 Customization

### Adjust for Your Workflow

**If you don't use worktrees:**
- Skip `GENERAL_WORKTREE_PROTOCOL.md`
- Only use Active Debugging Mode from `GENERAL_DUAL_MODE_WORKFLOW.md`

**If you work solo (no multi-agent):**
- Use single agent seat: `agent-001`
- Skip conflict detection steps
- Simplified pool management

**If you have different main branch:**
- Replace `<main-branch>` with your branch name: `develop`, `master`, `trunk`, etc.

**If you use different tools:**
- Adapt tool commands (e.g., `hub` instead of `gh`)
- Update paths to your tooling

---

## 📚 What Each File Does

### GENERAL_ZERO_TOLERANCE_RULES.md
**Purpose:** Critical rules that prevent common mistakes
**Copy?** YES - These are universal best practices
**Customize:** Replace variables with your paths

### GENERAL_DUAL_MODE_WORKFLOW.md
**Purpose:** Decision tree for Feature Development vs Active Debugging modes
**Copy?** YES - This is a universal workflow pattern
**Customize:** Replace variables, adjust mode detection for your IDE

### GENERAL_WORKTREE_PROTOCOL.md
**Purpose:** Complete worktree allocation, usage, and release workflow
**Copy?** YES (if using worktrees) - Prevents conflicts in multi-agent scenarios
**Customize:** Replace variables, adjust steps for your git workflow

### MACHINE_CONFIG.md
**Purpose:** Your local paths and project configuration
**Copy?** NO - Create your own with your paths
**Customize:** Everything - this is 100% machine-specific

---

## ✅ Verification

After setup, verify:

```bash
# Check directories exist
ls ${CONTROL_PLANE_PATH}
ls ${MACHINE_CONTEXT_PATH}
ls ${WORKTREE_PATH}

# Check tracking files exist
cat ${MACHINE_CONTEXT_PATH}/worktrees.pool.md
cat ${MACHINE_CONTEXT_PATH}/worktrees.activity.md

# Check base repo is clean
cd ${BASE_REPO_PATH}/<your-repo>
git status
git branch --show-current  # Should be on main branch
```

---

## 🚨 Common Mistakes When Copying

### ❌ Mistake 1: Copying Hardcoded Paths
```
# WRONG - Copied from someone else's config
BASE_REPO_PATH=C:\Projects  # Windows path on Mac!
```
```
# RIGHT - Your actual paths
BASE_REPO_PATH=/Users/yourname/projects
```

### ❌ Mistake 2: Not Creating Directories
```
# WRONG - Variables reference non-existent directories
${WORKTREE_PATH}/agent-001  # Directory doesn't exist!
```
```
# RIGHT - Create directories first
mkdir -p ${WORKTREE_PATH}/agent-001
```

### ❌ Mistake 3: Wrong Main Branch Name
```
# WRONG - Repo uses 'develop' but config says 'main'
<main-branch>=main  # But your repo's main branch is 'develop'!
```
```
# RIGHT - Match your actual main branch
<main-branch>=develop
```

### ❌ Mistake 4: Copying Machine-Specific Files
```
# WRONG - Copying reflection.log.md from someone else
# Their lessons learned won't apply to your environment
```
```
# RIGHT - Create your own reflection log
# Document YOUR learnings from YOUR sessions
```

---

## 💡 Tips

1. **Start Simple** - Use just Active Debugging Mode first, add worktrees later
2. **Test Paths** - Verify all paths work before adding to Claude instructions
3. **Document Deviations** - If you customize workflows, document why
4. **Version Control** - Keep your `MACHINE_CONFIG.md` in version control (excluding secrets)
5. **Update Regularly** - As you learn patterns, update your reflection log

---

## 🔗 Resources

- **Claude Code Docs:** https://docs.anthropic.com/claude/docs/claude-code
- **Git Worktrees:** https://git-scm.com/docs/git-worktree
- **GitHub CLI:** https://cli.github.com/manual/

---

**Last Updated:** 2026-01-13
**Maintained By:** Claude Community
**Questions?** File an issue or discuss in Claude Code community
