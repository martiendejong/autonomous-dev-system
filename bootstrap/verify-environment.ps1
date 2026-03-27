#Requires -Version 5.1
<#
.SYNOPSIS
    Verify Claude Agent development environment setup

.DESCRIPTION
    Performs comprehensive verification of the environment:
    - Required software installed and accessible
    - Directory structure exists
    - State files initialized
    - Git configured properly
    - GitHub CLI authenticated
    - Claude Code ready

.PARAMETER Verbose
    Show detailed output for each check

.PARAMETER Fix
    Attempt to fix issues when possible
#>

[CmdletBinding()]
param(
    [switch]$Fix
)

$ErrorActionPreference = "Continue"
$ScriptRoot = $PSScriptRoot
$RepoRoot = Split-Path $ScriptRoot -Parent

function Write-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Details = ""
    )

    if ($Passed) {
        Write-Host "  [PASS] " -NoNewline -ForegroundColor Green
        Write-Host $Name -NoNewline
        if ($Details) {
            Write-Host " - $Details" -ForegroundColor DarkGray
        } else {
            Write-Host ""
        }
        return 1
    } else {
        Write-Host "  [FAIL] " -NoNewline -ForegroundColor Red
        Write-Host $Name -NoNewline
        if ($Details) {
            Write-Host " - $Details" -ForegroundColor Yellow
        } else {
            Write-Host ""
        }
        return 0
    }
}

function Test-Command {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-CommandVersion {
    param([string]$Command, [string]$VersionArg = "--version")
    try {
        $output = & $Command $VersionArg 2>&1 | Select-Object -First 1
        return $output
    } catch {
        return "unknown"
    }
}

# === MAIN ===
Write-Host ""
Write-Host "Environment Verification" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host ""

$totalPassed = 0
$totalFailed = 0

# === SECTION 1: REQUIRED SOFTWARE ===
Write-Host "1. Required Software" -ForegroundColor White
Write-Host ""

# Git
$gitOk = Test-Command "git"
$gitVersion = if ($gitOk) { Get-CommandVersion "git" } else { "not installed" }
$totalPassed += Write-Check "Git" $gitOk $gitVersion

# GitHub CLI
$ghOk = Test-Command "gh"
$ghVersion = if ($ghOk) { Get-CommandVersion "gh" } else { "not installed" }
$totalPassed += Write-Check "GitHub CLI (gh)" $ghOk $ghVersion

# Node.js
$nodeOk = Test-Command "node"
$nodeVersion = if ($nodeOk) { Get-CommandVersion "node" } else { "not installed" }
$totalPassed += Write-Check "Node.js" $nodeOk $nodeVersion

# npm
$npmOk = Test-Command "npm"
$npmVersion = if ($npmOk) { Get-CommandVersion "npm" } else { "not installed" }
$totalPassed += Write-Check "npm" $npmOk $npmVersion

# Claude Code CLI
$claudeOk = Test-Command "claude"
$claudeVersion = if ($claudeOk) { Get-CommandVersion "claude" } else { "not installed" }
$totalPassed += Write-Check "Claude Code CLI" $claudeOk $claudeVersion

# .NET (optional)
$dotnetOk = Test-Command "dotnet"
$dotnetVersion = if ($dotnetOk) { Get-CommandVersion "dotnet" } else { "not installed (optional)" }
if ($dotnetOk) { $totalPassed++ } else { Write-Host "  [SKIP] .NET SDK - not installed (optional)" -ForegroundColor DarkGray }

if (-not $gitOk -or -not $ghOk -or -not $nodeOk) {
    $totalFailed += 1
}

Write-Host ""

# === SECTION 2: GIT CONFIGURATION ===
Write-Host "2. Git Configuration" -ForegroundColor White
Write-Host ""

# User name
$gitName = & git config --global user.name 2>$null
$nameOk = [bool]$gitName
$totalPassed += Write-Check "Git user.name" $nameOk $(if ($gitName) { $gitName } else { "not configured" })

# User email
$gitEmail = & git config --global user.email 2>$null
$emailOk = [bool]$gitEmail
$totalPassed += Write-Check "Git user.email" $emailOk $(if ($gitEmail) { $gitEmail } else { "not configured" })

if (-not $nameOk -or -not $emailOk) {
    Write-Host ""
    Write-Host "  To configure git:" -ForegroundColor Yellow
    Write-Host "    git config --global user.name 'Your Name'" -ForegroundColor DarkGray
    Write-Host "    git config --global user.email 'your@email.com'" -ForegroundColor DarkGray
    $totalFailed += 1
}

Write-Host ""

# === SECTION 3: GITHUB CLI AUTHENTICATION ===
Write-Host "3. GitHub CLI Authentication" -ForegroundColor White
Write-Host ""

if ($ghOk) {
    $authStatus = & gh auth status 2>&1
    $authOk = $LASTEXITCODE -eq 0
    $authDetails = if ($authOk) { "authenticated" } else { "not authenticated" }
    $totalPassed += Write-Check "GitHub CLI auth" $authOk $authDetails

    if (-not $authOk) {
        Write-Host ""
        Write-Host "  To authenticate:" -ForegroundColor Yellow
        Write-Host "    gh auth login" -ForegroundColor DarkGray
        $totalFailed += 1
    }
} else {
    Write-Host "  [SKIP] GitHub CLI not installed" -ForegroundColor DarkGray
}

Write-Host ""

# === SECTION 4: DIRECTORY STRUCTURE ===
Write-Host "4. Directory Structure" -ForegroundColor White
Write-Host ""

# Load config if available
$configPath = Join-Path $RepoRoot "bootstrap\last-config.json"
$config = @{
    BASE_REPO_PATH = "C:\Projects"
    WORKTREE_PATH = "C:\Projects\worker-agents"
    MACHINE_CONTEXT_PATH = Join-Path $RepoRoot "_machine"
}

if (Test-Path $configPath) {
    $loadedConfig = Get-Content $configPath | ConvertFrom-Json
    foreach ($prop in $loadedConfig.PSObject.Properties) {
        $config[$prop.Name] = $prop.Value
    }
}

# Check directories
$baseRepoOk = Test-Path $config.BASE_REPO_PATH
$totalPassed += Write-Check "Base repo path" $baseRepoOk $config.BASE_REPO_PATH

$worktreeOk = Test-Path $config.WORKTREE_PATH
$totalPassed += Write-Check "Worktree path" $worktreeOk $config.WORKTREE_PATH

$machineCtxOk = Test-Path $config.MACHINE_CONTEXT_PATH
$totalPassed += Write-Check "Machine context" $machineCtxOk $config.MACHINE_CONTEXT_PATH

# Check agent seats
$agentSeats = @("agent-001", "agent-002", "agent-003")
$seatsOk = $true
foreach ($seat in $agentSeats) {
    $seatPath = Join-Path $config.WORKTREE_PATH $seat
    if (-not (Test-Path $seatPath)) {
        $seatsOk = $false
        break
    }
}
$totalPassed += Write-Check "Agent seats" $seatsOk "agent-001, agent-002, agent-003"

if (-not $baseRepoOk -or -not $worktreeOk -or -not $machineCtxOk -or -not $seatsOk) {
    Write-Host ""
    Write-Host "  Run setup-directories.ps1 to create missing directories" -ForegroundColor Yellow
    $totalFailed += 1
}

Write-Host ""

# === SECTION 5: STATE FILES ===
Write-Host "5. State Files" -ForegroundColor White
Write-Host ""

$stateFiles = @(
    "worktrees.pool.md",
    "worktrees.activity.md",
    "reflection.log.md",
    "pr-dependencies.md"
)

$stateOk = $true
foreach ($file in $stateFiles) {
    $filePath = Join-Path $config.MACHINE_CONTEXT_PATH $file
    $fileExists = Test-Path $filePath
    $totalPassed += Write-Check $file $fileExists $(if ($fileExists) { "exists" } else { "missing" })
    if (-not $fileExists) { $stateOk = $false }
}

if (-not $stateOk) {
    Write-Host ""
    Write-Host "  Run init-machine-state.ps1 to create missing state files" -ForegroundColor Yellow
    $totalFailed += 1
}

Write-Host ""

# === SECTION 6: DOCUMENTATION ===
Write-Host "6. Documentation Files" -ForegroundColor White
Write-Host ""

$docFiles = @(
    "CLAUDE.md",
    "MACHINE_CONFIG.md",
    "GENERAL_ZERO_TOLERANCE_RULES.md",
    "GENERAL_DUAL_MODE_WORKFLOW.md",
    "GENERAL_WORKTREE_PROTOCOL.md"
)

foreach ($file in $docFiles) {
    $filePath = Join-Path $RepoRoot $file
    $fileExists = Test-Path $filePath
    $totalPassed += Write-Check $file $fileExists $(if ($fileExists) { "exists" } else { "missing" })
}

Write-Host ""

# === SECTION 7: SKILLS ===
Write-Host "7. Claude Skills" -ForegroundColor White
Write-Host ""

$skillsDir = Join-Path $RepoRoot ".claude\skills"
$skillsDirOk = Test-Path $skillsDir
$totalPassed += Write-Check "Skills directory" $skillsDirOk $skillsDir

if ($skillsDirOk) {
    $skillCount = (Get-ChildItem $skillsDir -Directory).Count
    $skillsOk = $skillCount -gt 0
    $totalPassed += Write-Check "Skills loaded" $skillsOk "$skillCount skill(s) found"
}

Write-Host ""

# === SUMMARY ===
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "  Verification Summary" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Checks passed: $totalPassed" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Yellow" })
Write-Host "  Issues found:  $totalFailed" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($totalFailed -eq 0) {
    Write-Host "  Environment is ready!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Start Claude Agent with:" -ForegroundColor White
    Write-Host "    .\claude_agent.bat" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
} else {
    Write-Host "  Some issues need attention." -ForegroundColor Yellow
    Write-Host "  Review the failures above and run the suggested commands." -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}
