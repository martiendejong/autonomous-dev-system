# Claude Agent Bootstrap System

Fully automated setup for the Claude Agent development environment. Clone this repository, run bootstrap, and Claude will have everything it needs to operate autonomously.

## Quick Start

### On a Fresh Windows Machine

```powershell
# 1. Clone the repository
git clone https://github.com/yourname/claude-scripts.git C:\scripts
cd C:\scripts

# 2. Run bootstrap (interactive)
.\bootstrap\bootstrap.ps1

# 3. Start Claude Agent
.\claude_agent.bat
```

### Non-Interactive Setup

```powershell
# Create config file
@{
    BASE_REPO_PATH = "C:\Projects"
    WORKTREE_PATH = "C:\Projects\worker-agents"
    MAIN_BRANCH = "develop"
    GITHUB_USER = "yourname"
} | ConvertTo-Json | Set-Content config.json

# Run bootstrap
.\bootstrap\bootstrap.ps1 -ConfigFile config.json -NonInteractive
```

## What Bootstrap Does

### 1. Installs Dependencies (`install-dependencies.ps1`)

Automatically installs via `winget` or `chocolatey`:

| Software | Purpose | Required |
|----------|---------|----------|
| Git | Version control | Yes |
| GitHub CLI (gh) | Repository operations | Yes |
| Node.js LTS | Runtime for Claude CLI | Yes |
| npm | Package manager | Yes |
| .NET SDK | C# development | Optional |
| VS Code | Editor | Optional |

Also installs:
- Claude Code CLI (`@anthropic-ai/claude-code`)

### 2. Creates Directory Structure (`setup-directories.ps1`)

```
C:\Projects\                      # BASE_REPO_PATH
  ├── client-manager\             # Your project repos
  ├── hazina\
  └── worker-agents\              # WORKTREE_PATH
      ├── agent-001\              # Agent worktree seats
      ├── agent-002\
      └── agent-003\

C:\scripts\                       # CONTROL_PLANE_PATH
  ├── _machine\                   # MACHINE_CONTEXT_PATH
  │   ├── worktrees.pool.md       # Agent seat tracking
  │   ├── worktrees.activity.md   # Activity log
  │   ├── reflection.log.md       # Learnings
  │   └── pr-dependencies.md      # Cross-repo PR tracking
  ├── .claude\
  │   └── skills\                 # Claude skills (auto-loaded)
  ├── tools\                      # Productivity scripts
  └── bootstrap\                  # This bootstrap system
```

### 3. Initializes Machine State (`init-machine-state.ps1`)

Creates tracking files that Claude uses for:
- **Worktree allocation** - Prevents conflicts when multiple agents run
- **Activity logging** - Audit trail of all operations
- **Reflection logging** - Accumulates learnings across sessions
- **PR dependency tracking** - Manages cross-repo dependencies

### 4. Verifies Environment (`verify-environment.ps1`)

Comprehensive check that everything is ready:
- All required software installed
- Git configured with user name/email
- GitHub CLI authenticated
- All directories exist
- State files initialized
- Skills loaded

## Bootstrap Scripts

| Script | Purpose |
|--------|---------|
| `bootstrap.ps1` | Main entry point - orchestrates everything |
| `install-dependencies.ps1` | Software installation via winget/chocolatey |
| `setup-directories.ps1` | Creates directory structure |
| `init-machine-state.ps1` | Initializes tracking files |
| `verify-environment.ps1` | Validates environment is ready |

## Command Line Options

### bootstrap.ps1

```powershell
# Interactive mode (default)
.\bootstrap\bootstrap.ps1

# Use config file
.\bootstrap\bootstrap.ps1 -ConfigFile .\config.json

# Non-interactive with config
.\bootstrap\bootstrap.ps1 -ConfigFile .\config.json -NonInteractive

# Skip dependency installation (already have git, node, etc.)
.\bootstrap\bootstrap.ps1 -SkipDependencies

# Force overwrite existing files
.\bootstrap\bootstrap.ps1 -Force
```

### verify-environment.ps1

```powershell
# Basic verification
.\bootstrap\verify-environment.ps1

# Attempt to fix issues
.\bootstrap\verify-environment.ps1 -Fix
```

### init-machine-state.ps1

```powershell
# Initialize (skip existing)
.\bootstrap\init-machine-state.ps1

# Force overwrite
.\bootstrap\init-machine-state.ps1 -Force
```

## Configuration File Format

```json
{
    "BASE_REPO_PATH": "C:\\Projects",
    "WORKTREE_PATH": "C:\\Projects\\worker-agents",
    "CONTROL_PLANE_PATH": "C:\\scripts",
    "MACHINE_CONTEXT_PATH": "C:\\scripts\\_machine",
    "GITHUB_USER": "yourname",
    "MAIN_BRANCH": "develop",
    "PROJECTS": [
        {
            "name": "my-project",
            "repo": "github.com/yourname/my-project",
            "path": "C:\\Projects\\my-project"
        }
    ]
}
```

## Post-Bootstrap Steps

### 1. Clone Your Repositories

```powershell
cd C:\Projects
git clone https://github.com/yourname/my-project.git
```

### 2. Update MACHINE_CONFIG.md

Add your project details to `C:\scripts\MACHINE_CONFIG.md`:

```markdown
### Project: my-project
**Type:** Description
**Paths:**
- Code: C:\Projects\my-project
**Repository URL:** https://github.com/yourname/my-project
**Main Branch:** develop
```

### 3. Authenticate GitHub CLI

```powershell
gh auth login
```

### 4. Test Claude Agent

```powershell
.\claude_agent.bat
```

## Troubleshooting

### "winget not found"

Windows Package Manager isn't installed. Either:
1. Install from Microsoft Store: "App Installer"
2. Or install Chocolatey: https://chocolatey.org/install

### "Claude Code CLI not found"

```powershell
npm install -g @anthropic-ai/claude-code
```

### "GitHub CLI not authenticated"

```powershell
gh auth login
```

### "Permission denied" errors

Run PowerShell as Administrator, or adjust execution policy:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### State files missing

```powershell
.\bootstrap\init-machine-state.ps1 -Force
```

## Portability

This bootstrap system is designed for portability:

### What's Tracked in Git
- All bootstrap scripts
- Claude skills (`.claude/skills/`)
- Documentation (`CLAUDE.md`, `GENERAL_*.md`)
- Tools (`tools/`)

### What's NOT Tracked (Machine-Specific)
- `.claude/settings.json` (local Claude config)
- `_machine/*.md` state files (generated by bootstrap)
- `bootstrap/last-config.json` (your configuration)

### Moving to a New Machine

1. Clone the repository
2. Run `bootstrap.ps1`
3. Claude will have the same capabilities and knowledge

## Version History

- **1.0.0** (2026-01-13) - Initial bootstrap system

## Contributing

This is a self-improving system. Claude agents update this documentation and tools as they learn new patterns. See `continuous-improvement.md` for the protocol.
