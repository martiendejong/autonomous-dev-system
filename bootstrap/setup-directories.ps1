#Requires -Version 5.1
<#
.SYNOPSIS
    Setup directory structure for Claude Agent environment

.DESCRIPTION
    Creates all required directories for the Claude Agent to operate:
    - Base repository path for project clones
    - Worktree path for agent working directories
    - Machine context path for state files
    - Agent seats (agent-001, agent-002, etc.)

.PARAMETER BaseRepoPath
    Path where repositories will be cloned (default: C:\Projects)

.PARAMETER WorktreePath
    Path where agent worktrees will be created (default: C:\Projects\worker-agents)

.PARAMETER ControlPlanePath
    Path to this scripts repository (default: current script root parent)

.PARAMETER MachineContextPath
    Path for machine-specific state files (default: ControlPlanePath\_machine)

.PARAMETER AgentCount
    Number of agent seats to pre-create (default: 3)
#>

[CmdletBinding()]
param(
    [string]$BaseRepoPath = "C:\Projects",
    [string]$WorktreePath = "C:\Projects\worker-agents",
    [string]$ControlPlanePath = $null,
    [string]$MachineContextPath = $null,
    [int]$AgentCount = 3
)

$ErrorActionPreference = "Stop"

# Set defaults if not provided
if (-not $ControlPlanePath) {
    $ControlPlanePath = Split-Path $PSScriptRoot -Parent
}
if (-not $MachineContextPath) {
    $MachineContextPath = Join-Path $ControlPlanePath "_machine"
}

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

function Ensure-Directory {
    param([string]$Path, [string]$Description)

    if (Test-Path $Path) {
        Write-Status "$Description already exists: $Path" "Success"
        return $true
    }

    try {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Status "$Description created: $Path" "Success"
        return $true
    } catch {
        Write-Status "Failed to create $Description at $Path : $_" "Error"
        return $false
    }
}

# === MAIN ===
Write-Host ""
Write-Host "Setting Up Directory Structure" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

$createdCount = 0
$existedCount = 0
$failedCount = 0

# 1. Base Repository Path
Write-Status "Creating base repository directory..." "Info"
if (Ensure-Directory $BaseRepoPath "Base repository path") {
    $createdCount++
}

# 2. Worktree Path
Write-Status "Creating worktree directory..." "Info"
if (Ensure-Directory $WorktreePath "Worktree path") {
    $createdCount++
}

# 3. Agent Seats
Write-Host ""
Write-Status "Creating agent seats..." "Info"
for ($i = 1; $i -le $AgentCount; $i++) {
    $agentNum = $i.ToString().PadLeft(3, '0')
    $agentPath = Join-Path $WorktreePath "agent-$agentNum"

    if (Ensure-Directory $agentPath "Agent seat agent-$agentNum") {
        $createdCount++
    }
}

# 4. Machine Context Path
Write-Host ""
Write-Status "Creating machine context directory..." "Info"
if (Ensure-Directory $MachineContextPath "Machine context path") {
    $createdCount++
}

# 5. Subdirectories in machine context
$machineSubdirs = @(
    "archive",
    "best-practices",
    "knowledge",
    "lessons",
    "ADR"
)

foreach ($subdir in $machineSubdirs) {
    $subdirPath = Join-Path $MachineContextPath $subdir
    if (Ensure-Directory $subdirPath "Machine context/$subdir") {
        $createdCount++
    }
}

# 6. Control plane subdirectories
Write-Host ""
Write-Status "Creating control plane subdirectories..." "Info"

$controlPlaneSubdirs = @(
    "logs",
    "plans",
    "status",
    "tasks",
    "agents",
    "prompts",
    "tools",
    "docs"
)

foreach ($subdir in $controlPlaneSubdirs) {
    $subdirPath = Join-Path $ControlPlanePath $subdir
    if (Ensure-Directory $subdirPath "Control plane/$subdir") {
        $createdCount++
    }
}

# 7. Skills directory structure (for Claude skills)
Write-Host ""
Write-Status "Creating Claude skills directory..." "Info"

$claudeDir = Join-Path $ControlPlanePath ".claude"
$skillsDir = Join-Path $claudeDir "skills"

Ensure-Directory $claudeDir ".claude directory"
Ensure-Directory $skillsDir "Skills directory"

# === SUMMARY ===
Write-Host ""
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "  Directory Setup Summary" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Directories created/verified: $createdCount" -ForegroundColor Green
Write-Host ""
Write-Host "  Structure:" -ForegroundColor White
Write-Host "    Projects:      $BaseRepoPath" -ForegroundColor DarkGray
Write-Host "    Worktrees:     $WorktreePath" -ForegroundColor DarkGray
Write-Host "    Control Plane: $ControlPlanePath" -ForegroundColor DarkGray
Write-Host "    Machine State: $MachineContextPath" -ForegroundColor DarkGray
Write-Host ""

Write-Status "Directory setup complete" "Success"
exit 0
