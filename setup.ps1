# Autonomous Development System - First-Time Setup (PowerShell)
# Cross-platform installation wizard for Windows
#
# Usage: powershell -ExecutionPolicy Bypass -File setup.ps1

$ErrorActionPreference = "Stop"

# Colors
function Write-Title { param($text) Write-Host $text -ForegroundColor Blue }
function Write-Success { param($text) Write-Host $text -ForegroundColor Green }
function Write-Warning { param($text) Write-Host $text -ForegroundColor Yellow }
function Write-Error { param($text) Write-Host $text -ForegroundColor Red }
function Write-Info { param($text) Write-Host $text -ForegroundColor Cyan }

Write-Title @"

╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   AUTONOMOUS DEVELOPMENT SYSTEM                           ║
║   First-Time Installation Wizard                          ║
║                                                           ║
║   Battle-tested protocols for multi-repo development     ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

"@

Write-Success "Detected OS: Windows (PowerShell)"
Write-Host ""

# Function to prompt with default
function Prompt-WithDefault {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )

    if ($Default) {
        $result = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($result)) {
            return $Default
        }
        return $result
    } else {
        return Read-Host $Prompt
    }
}

# Function to prompt yes/no
function Prompt-YesNo {
    param(
        [string]$Prompt,
        [string]$Default = "n"
    )

    $suffix = if ($Default -eq "y") { "[Y/n]" } else { "[y/N]" }
    $result = Read-Host "$Prompt $suffix"

    if ([string]::IsNullOrWhiteSpace($result)) {
        $result = $Default
    }

    return $result -match "^[Yy]"
}

# Default paths for Windows
$DefaultControlPlane = Join-Path $env:USERPROFILE ".autonomous-dev"
$DefaultWorktreePath = Join-Path $env:USERPROFILE "Documents\worker-agents"

Write-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Warning "STEP 1: Control Plane Configuration"
Write-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "The control plane stores:"
Write-Host "  • Agent pool status (worktrees.pool.md)"
Write-Host "  • Activity logs (worktrees.activity.md)"
Write-Host "  • Reflection logs (lessons learned)"
Write-Host "  • Pattern library"
Write-Host ""

$ControlPlane = Prompt-WithDefault "Control plane directory" $DefaultControlPlane

Write-Host ""
Write-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Warning "STEP 2: Repository Configuration"
Write-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "Add repositories you want to manage with autonomous development."
Write-Host "These are your BASE repositories (worktrees will be created from them)."
Write-Host ""
Write-Host "Examples:"
Write-Host "  • Name: my-api, Path: C:\Projects\my-api, Branch: develop"
Write-Host "  • Name: frontend, Path: C:\Projects\frontend, Branch: main"
Write-Host ""

$Repos = @()
$RepoCount = 0

while ($true) {
    $RepoCount++

    Write-Success "Repository #$RepoCount"

    $RepoName = Prompt-WithDefault "  Repository short name (or 'done' to finish)" ""

    if ($RepoName -eq "done" -or [string]::IsNullOrWhiteSpace($RepoName)) {
        if ($RepoCount -eq 1) {
            Write-Error "Error: You must add at least one repository!"
            $RepoCount = 0
            continue
        } else {
            break
        }
    }

    $RepoPath = Prompt-WithDefault "  Absolute path to repository" ""

    if (-not (Test-Path $RepoPath)) {
        Write-Warning "  Warning: Directory does not exist: $RepoPath"
        if (-not (Prompt-YesNo "  Add anyway?")) {
            $RepoCount--
            continue
        }
    }

    $RepoBranch = Prompt-WithDefault "  Base branch" "develop"

    $Repos += @{
        name = $RepoName
        path = $RepoPath
        baseBranch = $RepoBranch
    }

    Write-Success "  ✓ Added: $RepoName"
    Write-Host ""

    if (-not (Prompt-YesNo "Add another repository?" "y")) {
        break
    }
    Write-Host ""
}

Write-Host ""
Write-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Warning "STEP 3: Worktree Configuration"
Write-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "Worktrees are isolated working directories for parallel development."
Write-Host "Each agent gets its own worktree to prevent conflicts."
Write-Host ""

$WorktreePath = Prompt-WithDefault "Worktree base path" $DefaultWorktreePath

Write-Host ""
$AgentPoolSizeStr = Prompt-WithDefault "Agent pool size (1-50)" "12"
$AgentPoolSize = [int]$AgentPoolSizeStr

if ($AgentPoolSize -lt 1 -or $AgentPoolSize -gt 50) {
    Write-Warning "Invalid pool size, using default: 12"
    $AgentPoolSize = 12
}

Write-Host ""
Write-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Warning "STEP 4: Shell Preference"
Write-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "Available shells:"
Write-Host "  1) auto (detect automatically)"
Write-Host "  2) pwsh (PowerShell)"
Write-Host "  3) cmd (Command Prompt)"
Write-Host "  4) bash (Git Bash/WSL)"
Write-Host ""

$ShellChoice = Prompt-WithDefault "Select shell [1-4]" "1"

$PreferredShell = switch ($ShellChoice) {
    "1" { "auto" }
    "2" { "pwsh" }
    "3" { "cmd" }
    "4" { "bash" }
    default { "auto" }
}

Write-Host ""
Write-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Warning "Configuration Summary"
Write-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "Control Plane: $ControlPlane"
Write-Host "Worktree Path: $WorktreePath"
Write-Host "Agent Pool Size: $AgentPoolSize"
Write-Host "Shell: $PreferredShell"
Write-Host ""
Write-Host "Repositories:"
foreach ($repo in $Repos) {
    Write-Host "  • $($repo.name) → $($repo.path)"
}
Write-Host ""

if (-not (Prompt-YesNo "Proceed with installation?" "y")) {
    Write-Error "Installation cancelled."
    exit 0
}

Write-Host ""
Write-Title "Installing..."

# Create directories
New-Item -ItemType Directory -Force -Path $ControlPlane | Out-Null
New-Item -ItemType Directory -Force -Path "$ControlPlane\_machine" | Out-Null
New-Item -ItemType Directory -Force -Path "$ControlPlane\patterns" | Out-Null
New-Item -ItemType Directory -Force -Path "$ControlPlane\agents" | Out-Null
New-Item -ItemType Directory -Force -Path $WorktreePath | Out-Null

Write-Success "✓ Created directories"

# Build JSON config
$ReposJson = $Repos | ConvertTo-Json -Depth 10 -Compress

$Config = @{
    version = "1.0.0"
    installedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    os = "windows"
    controlPlane = $ControlPlane
    worktreePath = $WorktreePath
    agentPoolSize = $AgentPoolSize
    shell = $PreferredShell
    repos = $Repos
}

$ConfigFile = Join-Path $ControlPlane "config.json"
$Config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigFile -Encoding UTF8

Write-Success "✓ Created configuration: $ConfigFile"

# Initialize pool
$PoolFile = Join-Path $ControlPlane "_machine\worktrees.pool.md"

$PoolHeader = @"
# Worktree Agent Pool

| Seat | Directory | Status | Current Repo | Branch | Last Activity | Notes |
|------|-----------|--------|--------------|--------|---------------|-------|
"@

Set-Content -Path $PoolFile -Value $PoolHeader -Encoding UTF8

$Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

for ($i = 1; $i -le $AgentPoolSize; $i++) {
    $AgentNum = $i.ToString("000")
    $AgentDir = Join-Path $WorktreePath "agent-$AgentNum"

    Add-Content -Path $PoolFile -Value "| agent-$AgentNum | $AgentDir | FREE | - | - | $Timestamp | Initial setup |" -Encoding UTF8

    New-Item -ItemType Directory -Force -Path $AgentDir | Out-Null
}

Write-Success "✓ Initialized agent pool with $AgentPoolSize seats"

# Initialize activity log
$ActivityFile = Join-Path $ControlPlane "_machine\worktrees.activity.md"

$ActivityContent = @"
# Worktree Activity Log

Format: ``TIMESTAMP — action — agent-seat — repo — branch — task-id — executor — description``

## Activity

$Timestamp — init — system — - — - — - — setup — Autonomous Development System installed with $AgentPoolSize agents
"@

Set-Content -Path $ActivityFile -Value $ActivityContent -Encoding UTF8

Write-Success "✓ Created activity log"

# Initialize reflection log
$ReflectionFile = Join-Path $ControlPlane "_machine\reflection.log.md"

$ReflectionContent = @"
# Reflection Log - Lessons Learned

This file contains lessons learned, patterns discovered, and improvements made during development sessions.

## Format

Each entry should follow:
``````
## YYYY-MM-DD HH:MM - [Title]

**Problem:** [What went wrong or what was discovered]
**Root Cause:** [Why it happened]
**Fix:** [How it was resolved]
**Pattern:** [Reusable pattern or lesson learned]
``````

---

## $((Get-Date).ToString("yyyy-MM-dd HH:mm")) - System Installation

**Event:** Autonomous Development System installed
**Configuration:** $AgentPoolSize agents, $($Repos.Count) repositories
**Status:** Ready for use
"@

Set-Content -Path $ReflectionFile -Value $ReflectionContent -Encoding UTF8

Write-Success "✓ Created reflection log"

# Get plugin directory
$PluginDir = $PSScriptRoot

Write-Host ""
Write-Title "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Success "✓ Installation Complete!"
Write-Title "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "Configuration saved to: $ConfigFile"
Write-Host ""
Write-Warning "Next Steps:"
Write-Host ""
Write-Host "1. Install the plugin in Claude Code:"
Write-Info "   claude plugin install --local `"$PluginDir`""
Write-Host ""
Write-Host "2. Or use during development:"
Write-Info "   claude --plugin-dir=`"$PluginDir`""
Write-Host ""
Write-Host "3. Available commands:"
Write-Host "   • /worktree:claim <branch> <description>"
Write-Host "   • /worktree:release <agent-seat> <pr-title>"
Write-Host "   • /worktree:status"
Write-Host "   • /dashboard"
Write-Host "   • /pr:status"
Write-Host "   • /patterns:search <keyword>"
Write-Host ""
Write-Host "4. View configuration:"
Write-Info "   cat $ConfigFile"
Write-Host ""
Write-Success "Happy autonomous developing! 🚀"
Write-Host ""
