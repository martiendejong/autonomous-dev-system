#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Agent Development Environment Bootstrap

.DESCRIPTION
    Fully automated setup for the Claude Agent development environment.
    Run this script after cloning the repository to set up everything
    Claude needs to operate autonomously.

.PARAMETER ConfigFile
    Path to machine-specific configuration JSON file.
    If not provided, will prompt for required values.

.PARAMETER NonInteractive
    Skip prompts and use defaults where possible.
    Requires -ConfigFile to be specified.

.PARAMETER SkipDependencies
    Skip software installation (useful if dependencies already installed)

.EXAMPLE
    # Interactive setup (recommended for first time)
    .\bootstrap.ps1

.EXAMPLE
    # Automated setup with config file
    .\bootstrap.ps1 -ConfigFile .\my-config.json -NonInteractive

.NOTES
    Author: Claude Agent (Self-improving)
    Version: 1.0.0
    Last Updated: 2026-01-13
#>

[CmdletBinding()]
param(
    [string]$ConfigFile,
    [switch]$NonInteractive,
    [switch]$SkipDependencies,
    [switch]$Force
)

# === CONFIGURATION ===
$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot
$RepoRoot = Split-Path $ScriptRoot -Parent

# === HELPER FUNCTIONS ===
function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    $color = switch ($Type) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        "Info"    { "Cyan" }
        default   { "White" }
    }
    $prefix = switch ($Type) {
        "Success" { "[OK]" }
        "Warning" { "[WARN]" }
        "Error"   { "[ERROR]" }
        "Info"    { "[INFO]" }
        default   { "[*]" }
    }
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Magenta
    Write-Host "  $Title" -ForegroundColor Magenta
    Write-Host ("=" * 60) -ForegroundColor Magenta
    Write-Host ""
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-BootstrapScript {
    param([string]$ScriptName, [hashtable]$Parameters = @{})
    $scriptPath = Join-Path $ScriptRoot $ScriptName
    if (Test-Path $scriptPath) {
        Write-Status "Running $ScriptName..." "Info"
        & $scriptPath @Parameters
        return $LASTEXITCODE -eq 0
    } else {
        Write-Status "Script not found: $ScriptName" "Error"
        return $false
    }
}

# === MAIN BOOTSTRAP ===
Clear-Host
Write-Host @"

   ____  _                 _         _                    _
  / ___|| |  __ _  _   _  __| |  ___  / \    __ _   ___  _ __  | |_
 | |    | | / _` || | | |/ _` | / _ \/  \  / _` | / _ \| '_ \ | __|
 | |___ | || (_| || |_| | (_| ||  __/ /\ \| (_| ||  __/| | | || |_
  \____||_| \__,_| \__,_|\__,_| \___\_\ /_/ \__, | \___||_| |_| \__|
                                           |___/
          Development Environment Bootstrap v1.0

"@ -ForegroundColor Cyan

Write-Host "Repository: $RepoRoot" -ForegroundColor DarkGray
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
Write-Host ""

# === PRE-FLIGHT CHECKS ===
Write-Header "Pre-flight Checks"

# Check Windows version
$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -lt 10) {
    Write-Status "Windows 10 or later is required. Found: $osVersion" "Error"
    exit 1
}
Write-Status "Windows version: $osVersion" "Success"

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Status "PowerShell 5.1 or later required. Found: $($PSVersionTable.PSVersion)" "Error"
    exit 1
}
Write-Status "PowerShell version: $($PSVersionTable.PSVersion)" "Success"

# Check admin status (warn only)
if (-not (Test-Administrator)) {
    Write-Status "Not running as Administrator. Some operations may require elevation." "Warning"
}

# === LOAD OR CREATE CONFIGURATION ===
Write-Header "Configuration"

$Config = @{
    BASE_REPO_PATH = "C:\Projects"
    WORKTREE_PATH = "C:\Projects\worker-agents"
    CONTROL_PLANE_PATH = $RepoRoot
    MACHINE_CONTEXT_PATH = Join-Path $RepoRoot "_machine"
    GITHUB_USER = ""
    MAIN_BRANCH = "develop"
    PROJECTS = @()
}

if ($ConfigFile -and (Test-Path $ConfigFile)) {
    Write-Status "Loading configuration from: $ConfigFile" "Info"
    $loadedConfig = Get-Content $ConfigFile | ConvertFrom-Json
    foreach ($prop in $loadedConfig.PSObject.Properties) {
        $Config[$prop.Name] = $prop.Value
    }
    Write-Status "Configuration loaded" "Success"
} elseif (-not $NonInteractive) {
    Write-Status "Interactive configuration mode" "Info"
    Write-Host ""

    # Prompt for paths
    $input = Read-Host "Base repository path [$($Config.BASE_REPO_PATH)]"
    if ($input) { $Config.BASE_REPO_PATH = $input }

    $Config.WORKTREE_PATH = Join-Path $Config.BASE_REPO_PATH "worker-agents"
    $input = Read-Host "Worktree path [$($Config.WORKTREE_PATH)]"
    if ($input) { $Config.WORKTREE_PATH = $input }

    $input = Read-Host "Main branch name [$($Config.MAIN_BRANCH)]"
    if ($input) { $Config.MAIN_BRANCH = $input }

    # GitHub user
    $ghUser = & git config --global user.name 2>$null
    if ($ghUser) { $Config.GITHUB_USER = $ghUser }
    $input = Read-Host "GitHub username [$($Config.GITHUB_USER)]"
    if ($input) { $Config.GITHUB_USER = $input }

    Write-Host ""
    Write-Status "Configuration collected" "Success"
} else {
    Write-Status "Using default configuration (non-interactive mode)" "Info"
}

# Export config for sub-scripts
$env:BOOTSTRAP_CONFIG = $Config | ConvertTo-Json -Compress

# === STEP 1: INSTALL DEPENDENCIES ===
if (-not $SkipDependencies) {
    Write-Header "Step 1: Installing Dependencies"

    $depParams = @{}
    if ($NonInteractive) { $depParams["NonInteractive"] = $true }
    if ($Force) { $depParams["Force"] = $true }

    $success = Invoke-BootstrapScript "install-dependencies.ps1" $depParams
    if (-not $success) {
        Write-Status "Dependency installation had issues. Review and retry with -SkipDependencies if already installed." "Warning"
    }
} else {
    Write-Status "Skipping dependency installation" "Info"
}

# === STEP 2: SETUP DIRECTORIES ===
Write-Header "Step 2: Setting Up Directory Structure"

$dirParams = @{
    "BaseRepoPath" = $Config.BASE_REPO_PATH
    "WorktreePath" = $Config.WORKTREE_PATH
    "ControlPlanePath" = $Config.CONTROL_PLANE_PATH
    "MachineContextPath" = $Config.MACHINE_CONTEXT_PATH
}
Invoke-BootstrapScript "setup-directories.ps1" $dirParams

# === STEP 3: INITIALIZE MACHINE STATE ===
Write-Header "Step 3: Initializing Machine State"

$stateParams = @{
    "MachineContextPath" = $Config.MACHINE_CONTEXT_PATH
    "Force" = $Force.IsPresent
}
Invoke-BootstrapScript "init-machine-state.ps1" $stateParams

# === STEP 4: UPDATE MACHINE CONFIG ===
Write-Header "Step 4: Updating Machine Configuration"

$machineConfigPath = Join-Path $RepoRoot "MACHINE_CONFIG.md"
$machineConfigContent = @"
# Machine-Specific Configuration

**PURPOSE:** This file contains all machine/user-specific paths, projects, and configuration.
**GENERATED:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') by bootstrap.ps1

---

## Directory Structure

### Base Repository Path
``````
BASE_REPO_PATH=$($Config.BASE_REPO_PATH)
``````

### Worktree Path
``````
WORKTREE_PATH=$($Config.WORKTREE_PATH)
``````

### Control Plane Path
``````
CONTROL_PLANE_PATH=$($Config.CONTROL_PLANE_PATH)
``````

### Machine Context Path
``````
MACHINE_CONTEXT_PATH=$($Config.MACHINE_CONTEXT_PATH)
``````

---

## GitHub Configuration

``````
GITHUB_USER=$($Config.GITHUB_USER)
MAIN_BRANCH=$($Config.MAIN_BRANCH)
``````

---

## Worktree Pool Configuration

### Agent Seats
``````
agent-001 - $($Config.WORKTREE_PATH)\agent-001\
agent-002 - $($Config.WORKTREE_PATH)\agent-002\
agent-003 - $($Config.WORKTREE_PATH)\agent-003\
(Auto-provision agent-004, agent-005, etc. as needed)
``````

---

## Projects

> Add your projects here after cloning them to BASE_REPO_PATH

### Example Project Entry:
``````markdown
### Project: my-project
**Type:** Description of the project
**Paths:**
- Code: $($Config.BASE_REPO_PATH)\my-project
**Repository URL:** https://github.com/username/my-project
**Main Branch:** $($Config.MAIN_BRANCH)
``````

---

**Last Updated:** $(Get-Date -Format 'yyyy-MM-dd')
**Generated By:** bootstrap.ps1
"@

Set-Content -Path $machineConfigPath -Value $machineConfigContent -Encoding UTF8
Write-Status "Updated MACHINE_CONFIG.md" "Success"

# === STEP 5: VERIFY ENVIRONMENT ===
Write-Header "Step 5: Verifying Environment"

Invoke-BootstrapScript "verify-environment.ps1"

# === STEP 6: SETUP CLAUDE CODE ===
Write-Header "Step 6: Setting Up Claude Code"

# Check if Claude CLI is installed
$claudeInstalled = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeInstalled) {
    Write-Status "Claude Code CLI not found. Installing..." "Info"

    # Try npm install
    $npmInstalled = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmInstalled) {
        Write-Status "Installing Claude Code via npm..." "Info"
        & npm install -g @anthropic-ai/claude-code 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Claude Code installed successfully" "Success"
        } else {
            Write-Status "Failed to install Claude Code. Install manually: npm install -g @anthropic-ai/claude-code" "Warning"
        }
    } else {
        Write-Status "npm not found. Install Claude Code manually after Node.js is installed." "Warning"
    }
} else {
    $claudeVersion = & claude --version 2>&1
    Write-Status "Claude Code already installed: $claudeVersion" "Success"
}

# Initialize Claude settings directory
$claudeDir = Join-Path $RepoRoot ".claude"
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

# Create default settings.json if not exists
$settingsPath = Join-Path $claudeDir "settings.json"
if (-not (Test-Path $settingsPath)) {
    $defaultSettings = @{
        "model" = "sonnet"
        "dangerouslySkipPermissions" = $false
    }
    $defaultSettings | ConvertTo-Json | Set-Content $settingsPath -Encoding UTF8
    Write-Status "Created default Claude settings" "Success"
}

# === COMPLETE ===
Write-Header "Bootstrap Complete!"

Write-Host @"
Your Claude Agent development environment is ready!

Next steps:
1. Clone your project repositories to: $($Config.BASE_REPO_PATH)
2. Update MACHINE_CONFIG.md with your project details
3. Start Claude Agent with: .\claude_agent.bat

Directory structure:
  Control Plane:  $RepoRoot
  Projects:       $($Config.BASE_REPO_PATH)
  Worktrees:      $($Config.WORKTREE_PATH)
  Machine State:  $($Config.MACHINE_CONTEXT_PATH)

For help, see: BOOTSTRAP_README.md

"@ -ForegroundColor Green

# Save configuration for future reference
$configOutPath = Join-Path $RepoRoot "bootstrap\last-config.json"
$Config | ConvertTo-Json -Depth 3 | Set-Content $configOutPath -Encoding UTF8
Write-Status "Configuration saved to: $configOutPath" "Info"

Write-Host ""
Write-Status "Bootstrap completed successfully!" "Success"
