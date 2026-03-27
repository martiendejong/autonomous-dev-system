# Tester Guide - Autonomous Development System

**Version:** v1.0.0
**Plugin Name:** Autonomous Development System for Claude Code
**GitHub:** https://github.com/martiendejong/autonomous-dev-system

---

## 👋 Welcome Tester!

Thank you for helping test this Claude Code plugin! This guide will walk you through installation, testing, and reporting feedback.

**Estimated Time:** 30-45 minutes for complete testing

---

## 📋 What You'll Be Testing

This plugin provides autonomous worktree management for multi-repo development:

**Key Features:**
- Automatic worktree allocation from an agent pool
- Zero-tolerance enforcement (prevents common mistakes)
- 75+ documented patterns for common problems
- Cross-platform installation wizard
- 6 slash commands for workflow automation

**What Makes This Useful:**
- Prevents editing in wrong directories
- Manages parallel development without conflicts
- Automates PR creation with proper branch targeting
- Detects and cleans up stale worktrees

---

## ✅ Prerequisites (Please Verify You Have These)

Before starting, make sure you have:

- [ ] **Claude Code** >= 0.10.0 installed
- [ ] **Git** with worktree support (`git --version` should show 2.5+)
- [ ] **Node.js** >= 16.0.0 (`node --version`)
- [ ] **GitHub CLI** (`gh --version`) for PR operations
- [ ] **Bash** (Mac/Linux/Git Bash) OR **PowerShell** (Windows)
- [ ] At least **1 git repository** you can use for testing

**Not sure if you have these?** Run this command:

```bash
# Mac/Linux/Git Bash
echo "Git: $(git --version)"
echo "Node: $(node --version)"
echo "GitHub CLI: $(gh --version)"
echo "Claude Code: $(claude --version 2>/dev/null || echo 'Not found in PATH')"
```

```powershell
# Windows PowerShell
Write-Host "Git: $(git --version)"
Write-Host "Node: $(node --version)"
Write-Host "GitHub CLI: $(gh --version)"
Write-Host "Claude Code: $(claude --version)"
```

---

## 📥 Installation Steps

### Step 1: Clone the Repository

```bash
# Choose a location for the plugin
cd ~/Downloads  # or wherever you want

# Clone the repository
git clone https://github.com/martiendejong/autonomous-dev-system.git
cd autonomous-dev-system

# Verify files exist
ls -la
# You should see: README.md, setup.sh, setup.ps1, .claude-plugin/, scripts/, etc.
```

### Step 2: Run Installation Wizard

**Mac/Linux/Git Bash:**
```bash
bash setup.sh
```

**Windows PowerShell:**
```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

**The wizard will ask you for:**

1. **Control plane directory**
   - This stores logs, agent pool, and reflection data
   - Example: `~/.autonomous-dev` or `C:/Users/YourName/.autonomous-dev`
   - Just press Enter to use the default

2. **Repository #1** (and more if you have them)
   - **Name:** Short name (e.g., "my-api", "frontend")
   - **Path:** Full path to repository (e.g., `/Users/you/projects/my-api`)
   - **Base branch:** Usually "develop" or "main"
   - **Add more?** Type "done" when finished, or add another repo

3. **Worktree base path**
   - Where agent worktrees will be created
   - Example: `~/worker-agents` or `C:/Projects/worker-agents`
   - Press Enter for default

4. **Agent pool size**
   - Number of parallel agents (default: 12)
   - Press Enter for default

5. **Shell preference**
   - "auto", "bash", or "powershell"
   - Press Enter for "auto"

**Expected Output:**
```
✓ Setup complete!

Configuration saved to: ~/.autonomous-dev/config.json
Agent pool initialized with 12 agents

Next steps:
1. Install plugin in Claude Code
2. Test worktree allocation
```

### Step 3: Install Plugin in Claude Code

**Option A: Local Installation (Recommended for Testing)**
```bash
# Replace with your actual path
claude plugin install --local ~/Downloads/autonomous-dev-system
```

**Option B: Development Mode**
```bash
# Run Claude Code with plugin directory
claude --plugin-dir="~/Downloads/autonomous-dev-system"
```

**Verify Installation:**
- Start Claude Code
- Type `/worktree:` and press Tab
- You should see autocomplete suggestions for commands

---

## 🧪 Testing Checklist

### Test 1: Worktree Status (Basic Functionality)

**In Claude Code, type:**
```
/worktree:status
```

**Expected Output:**
```
Pool Size: 12 agents
FREE: 12 agents (100%)
BUSY: 0 agents (0%)

FREE AGENTS: agent-001, agent-002, agent-003, ...

✅ Pool health: HEALTHY (100% available)
```

**✅ PASS if:** You see the agent pool with all FREE agents
**❌ FAIL if:** Error message or command not found

---

### Test 2: Worktree Allocation

**In Claude Code, type:**
```
/worktree:claim test/plugin-test "Testing autonomous dev system plugin"
```

**Expected Output:**
```
✓ Found FREE agent: agent-001

Creating worktrees for all configured repos...

  Processing: my-api
    Fetching latest changes...
    Creating worktree at ~/worker-agents/agent-001/my-api...
    ✓ Worktree created for my-api

✓ Agent pool updated
✓ Activity logged

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ WORKTREE CLAIMED SUCCESSFULLY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Agent: agent-001
Branch: test/plugin-test
Worktree base: ~/worker-agents/agent-001

Worktrees created:
  • ~/worker-agents/agent-001/my-api

⚠️  IMPORTANT:
  • Edit ONLY in worktree directories above
  • NEVER edit in base repos
  • Release with: /worktree:release agent-001 "<pr-title>"

Happy coding! 🚀
```

**✅ PASS if:**
- Agent allocated successfully
- Worktree directory created
- Can see files: `ls ~/worker-agents/agent-001/my-api`

**❌ FAIL if:**
- Error messages
- No worktree created
- Command hangs

---

### Test 3: Verify Worktree Created

**In your terminal (not Claude Code):**
```bash
# Check worktree exists
ls ~/worker-agents/agent-001/

# Should show your repo name
# Example: my-api/

# Check it's a real git repo
cd ~/worker-agents/agent-001/my-api
git branch --show-current

# Should show: test/plugin-test
```

**✅ PASS if:** Worktree exists and is on correct branch
**❌ FAIL if:** Directory empty or not a git repo

---

### Test 4: Check Pool Status Updated

**In Claude Code, type:**
```
/worktree:status
```

**Expected Output:**
```
Pool Size: 12 agents
FREE: 11 agents (92%)
BUSY: 1 agent (8%)

BUSY AGENTS:

agent-001 [BUSY] ⏱️  2m ago
  Repo: my-api
  Branch: test/plugin-test
  Working on: Testing autonomous dev system plugin
  ✅ Active

FREE AGENTS: agent-002, agent-003, agent-004, ...
```

**✅ PASS if:** agent-001 shows as BUSY with your branch
**❌ FAIL if:** Still shows all FREE

---

### Test 5: Zero-Tolerance Enforcement (Hook Test)

This tests that the PreToolUse hook prevents editing in base repos.

**In Claude Code, ask it to:**
```
Can you edit a file in my base repository at [YOUR-BASE-REPO-PATH]?
```

**Expected Behavior:**
- Claude Code should either:
  1. Refuse and explain you must use worktree, OR
  2. Hook throws error: "FORBIDDEN: Editing in base repository directly!"

**✅ PASS if:** Prevented from editing base repo
**❌ FAIL if:** Allows editing without warning

---

### Test 6: Make Trivial Change in Worktree

**In Claude Code, ask it to:**
```
Please create a test file in my worktree at ~/worker-agents/agent-001/my-api/TEST.txt with content "Plugin test successful"
```

**Then verify:**
```bash
cat ~/worker-agents/agent-001/my-api/TEST.txt
# Should show: Plugin test successful
```

**✅ PASS if:** File created in worktree successfully
**❌ FAIL if:** File not created or in wrong location

---

### Test 7: Worktree Release

**In Claude Code, type:**
```
/worktree:release agent-001 "test: Verify plugin installation and basic functionality"
```

**Expected Output:**
```
Processing: my-api
  Staging changes...
  Committing...
  Merging latest develop...
  ✓ Merged develop successfully
  Pushing to remote...
  ✓ Pushed to origin/test/plugin-test
  Creating pull request...
  ✓ PR created: https://github.com/you/my-api/pull/XXX

Cleaning worktrees...
  ✓ Removed worktree for my-api

Updating base repositories...
  ✓ my-api updated

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ WORKTREE RELEASED SUCCESSFULLY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Agent: agent-001 (now FREE)
Branch: test/plugin-test

Pull Requests Created:
  • https://github.com/you/my-api/pull/XXX

Ready for next task! 🚀
```

**✅ PASS if:**
- Changes committed
- PR created
- Worktree cleaned
- Agent shows as FREE in `/worktree:status`

**❌ FAIL if:**
- Errors during release
- Worktree not cleaned
- Agent still BUSY

---

### Test 8: Pattern Search

**In Claude Code, type:**
```
/patterns:search merge
```

**Expected Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PATTERN SEARCH: "merge"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Pattern 52: Merge Develop Before Creating PR
File: patterns/git/pattern-052-merge-develop-first.md

Matching excerpt:
    ALWAYS merge origin/develop into feature branch BEFORE creating PR
    ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Pattern 4: Large File Merge Conflicts
File: patterns/git/pattern-004-large-merge-conflicts.md

Found 2 pattern(s) matching "merge"
```

**✅ PASS if:** Patterns found and displayed
**❌ FAIL if:** No results or error

---

### Test 9: Dashboard

**In Claude Code, type:**
```
/dashboard
```

**Expected Output:**
```
╔═══════════════════════════════════════════════════════════╗
║                  REPOSITORY DASHBOARD                      ║
╚═══════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 my-api
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Branch: develop ✅ Clean (0 uncommitted, 0 unpushed)
Last updated: 5 minutes ago

Recent Commits:
  abc1234  test: Verify plugin installation (5m ago)
  ...

Open PRs: 1
  #XXX test: Verify plugin installation ✅ MERGEABLE
       CI: ✅ Build passing
       Base: develop | Created 5m ago

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 AGENT POOL STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Pool: 12 agents
FREE: 12 agents (100%) ✅ Healthy
```

**✅ PASS if:** Dashboard shows repo status and agent pool
**❌ FAIL if:** Error or missing information

---

## 📝 Reporting Your Results

### What to Report

Please create a GitHub issue with your test results:

**Go to:** https://github.com/martiendejong/autonomous-dev-system/issues/new

**Title:** `[TEST RESULTS] v1.0.0 - [PASS/FAIL]`

**Body Template:**
```markdown
## Test Environment

- **OS:** Windows 11 / macOS 14.1 / Ubuntu 22.04
- **Shell:** Git Bash / PowerShell / Bash / Zsh
- **Claude Code Version:** 0.10.x
- **Node.js Version:** 16.x.x
- **Git Version:** 2.x.x

## Test Results

- [ ] Test 1: Worktree Status - PASS/FAIL
- [ ] Test 2: Worktree Allocation - PASS/FAIL
- [ ] Test 3: Verify Worktree Created - PASS/FAIL
- [ ] Test 4: Pool Status Updated - PASS/FAIL
- [ ] Test 5: Zero-Tolerance Enforcement - PASS/FAIL
- [ ] Test 6: Make Change in Worktree - PASS/FAIL
- [ ] Test 7: Worktree Release - PASS/FAIL
- [ ] Test 8: Pattern Search - PASS/FAIL
- [ ] Test 9: Dashboard - PASS/FAIL

## Issues Encountered

[Describe any problems, errors, or unexpected behavior]

## Screenshots

[If possible, attach screenshots of errors or unexpected output]

## Suggestions

[Any ideas for improvements or features you'd like to see]

## Overall Experience

[Would you use this plugin? Easy to install? Documentation clear?]
```

---

## 🐛 Common Issues & Solutions

### Issue: "Config not found"

**Solution:**
```bash
# Re-run setup wizard
bash setup.sh

# Verify config created
cat ~/.autonomous-dev/config.json
```

### Issue: "No FREE agents"

**Solution:**
```bash
# Check pool status
/worktree:status

# If all BUSY, release them
/worktree:release agent-001 "cleanup"
```

### Issue: "Script not executable"

**Solution:**
```bash
cd ~/Downloads/autonomous-dev-system
chmod +x scripts/*.sh
```

### Issue: "Command not found"

**Solution:**
- Plugin may not be installed correctly
- Try: `claude plugin list` to see if it's there
- Reinstall: `claude plugin install --local ~/path/to/autonomous-dev-system`

---

## 💬 Need Help?

- **GitHub Issues:** https://github.com/martiendejong/autonomous-dev-system/issues
- **Email the developer:** [Include if you want]
- **Check Documentation:** https://github.com/martiendejong/autonomous-dev-system/blob/master/README.md

---

## 🙏 Thank You!

Your testing helps make this plugin better for everyone. We appreciate your time and feedback!

**After testing, please:**
1. Submit your test results as a GitHub issue
2. Star the repo if you found it useful: https://github.com/martiendejong/autonomous-dev-system
3. Share with others who might benefit!

---

**Happy Testing! 🚀**
