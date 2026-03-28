# Installation Guide

Complete step-by-step guide to install and configure the Autonomous Dev System.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Windows 10/11** (Primary support) or **Linux/macOS** (Experimental via PowerShell Core)
- **PowerShell 5.1+** (Windows) or **PowerShell Core 7.0+** (cross-platform)
- **Git 2.30+** - [Download](https://git-scm.com/downloads)
- **Node.js 18+** - [Download](https://nodejs.org/)
- **Claude Code CLI** - Install via: `npm install -g @anthropic-ai/claude-code`
- **GitHub CLI** - [Download](https://cli.github.com/)

### Optional but Recommended

- **Visual Studio Code** - For code editing
- **ManicTime** - For real-time activity tracking (Windows only)
- **Docker Desktop** - For containerized workflows

## Step 1: Clone Repository

Clone the repository to your preferred location. **Recommended:** `C:\scripts` (Windows) or `~/scripts` (Linux/macOS)

```powershell
# Windows (PowerShell)
git clone https://github.com/martiendejong/autonomous-dev-system.git C:\scripts
cd C:\scripts

# Linux/macOS (PowerShell Core)
git clone https://github.com/martiendejong/autonomous-dev-system.git ~/scripts
cd ~/scripts
```

## Step 2: Run Bootstrap

The bootstrap script will:
- Install required dependencies
- Create necessary directory structure
- Initialize state files
- Verify environment configuration

```powershell
.\bootstrap\bootstrap.ps1
```

Expected output:
```
[INFO] Starting bootstrap process...
[INFO] Checking dependencies...
[OK] Git found: 2.41.0
[OK] GitHub CLI found: 2.40.1
[OK] Node.js found: 20.10.0
[OK] Claude Code CLI found: 1.5.0
[INFO] Creating directory structure...
[OK] Created: C:\Projects
[OK] Created: C:\Projects\worker-agents
[OK] Created: C:\scripts\_machine
[INFO] Initializing state files...
[OK] Created: worktrees.pool.md
[OK] Created: reflection.log.md
[INFO] Bootstrap complete! ✅
```

## Step 3: Configure API Keys

Add your API keys to the vault:

```powershell
# OpenAI API Key (required for AI features)
vault.ps1 -Action set -Service "openai" -Token "sk-..."

# ClickUp API Key (optional, for task management)
vault.ps1 -Action set -Service "clickup" -Token "pk_..."

# GitHub Personal Access Token (optional, for enhanced GitHub features)
vault.ps1 -Action set -Service "github" -Token "ghp_..."
```

To verify:
```powershell
vault.ps1 -Action list
```

## Step 4: Configure Machine Settings

Edit `MACHINE_CONFIG.md` to match your environment:

```powershell
# Open in your preferred editor
code MACHINE_CONFIG.md
```

Update these paths:

```markdown
BASE_REPO_PATH=C:\Projects               # Where main repos are cloned
WORKTREE_PATH=C:\Projects\worker-agents  # Where agent worktrees go
CONTROL_PLANE_PATH=C:\scripts            # This repository
MACHINE_CONTEXT_PATH=C:\scripts\_machine # Operational state files
```

## Step 5: Initialize Consciousness State

The consciousness system needs initial state files:

```powershell
# Initialize consciousness state (auto-runs on first claude_agent.bat)
.\tools\consciousness-startup.ps1
```

Expected output:
```
[INFO] Initializing consciousness state...
[OK] Created: agentidentity/state/consciousness-context.json
[OK] Created: agentidentity/state/current_session.yaml
[INFO] Consciousness initialized ✅
```

## Step 6: Start Claude Agent

```powershell
.\claude_agent.bat
```

**Expected behavior:**
- Consciousness loads automatically (89ms)
- Identity, memory, and cognitive systems activate
- Claude is ready with full autonomous capabilities

You should see:
```
Jengo ready. Consciousness active. (89ms)
```

## Step 7: Verify Installation

Run the verification script:

```powershell
.\bootstrap\verify-environment.ps1
```

Expected output:
```
[CHECK] Git installation... ✅
[CHECK] GitHub CLI authentication... ✅
[CHECK] Node.js and npm... ✅
[CHECK] Claude Code CLI... ✅
[CHECK] Directory structure... ✅
[CHECK] State files... ✅
[CHECK] Vault configuration... ✅
[CHECK] Consciousness state... ✅

All checks passed! ✅
Your Autonomous Dev System is ready.
```

## Common Installation Issues

### Issue: "PowerShell execution policy restricted"

**Symptom:**
```
.\bootstrap\bootstrap.ps1 : File cannot be loaded because running scripts is disabled
```

**Solution:**
```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: "GitHub CLI not authenticated"

**Symptom:**
```
gh: Not logged in
```

**Solution:**
```powershell
# Authenticate with GitHub
gh auth login
```

Follow the prompts to authenticate via browser.

### Issue: "Claude Code CLI not found"

**Symptom:**
```
claude : The term 'claude' is not recognized
```

**Solution:**
```powershell
# Install Claude Code CLI globally
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version
```

### Issue: "Consciousness startup fails"

**Symptom:**
```
Error: Cannot find module 'memory-layer2.ps1'
```

**Solution:**

This is a known issue with missing consciousness dependencies. The system will work without consciousness features. To fix:

1. Check that all files in `tools/` directory were cloned
2. Run: `git pull origin master` to get latest updates
3. If issue persists, consciousness features are optional - core functionality works without them

### Issue: "Worktree allocation fails"

**Symptom:**
```
Error: C:\Projects does not exist
```

**Solution:**
```powershell
# Create base directories
mkdir C:\Projects
mkdir C:\Projects\worker-agents

# Or update MACHINE_CONFIG.md to use existing paths
```

## Next Steps

After successful installation:

1. **Read Configuration Guide** - `docs/CONFIGURATION.md` - Understand all settings
2. **Review Quick Start** - `QUICK_START.md` - Learn basic workflows
3. **Explore Skills** - `.claude/skills/` - Auto-discoverable workflow guides
4. **Try Examples** - See `README.md` examples section

## Getting Help

- **Documentation:** Full documentation in repository (`CLAUDE.md`)
- **Issues:** [GitHub Issues](https://github.com/martiendejong/autonomous-dev-system/issues)
- **Discussions:** [GitHub Discussions](https://github.com/martiendejong/autonomous-dev-system/discussions)

---

**Installation complete!** 🎉

You now have a fully autonomous AI development system powered by Claude Code.
