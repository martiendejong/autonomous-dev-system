<#
.SYNOPSIS
    One-Click Feature Setup
    50-Expert Council V2 Improvement #11 | Priority: 2.0

.DESCRIPTION
    Creates branch + worktree + todos + skeleton in one command.
    Complete feature development environment instantly.

.PARAMETER Name
    Feature name (will be used for branch).

.PARAMETER Repo
    Repository (client-manager, hazina).

.PARAMETER Type
    Type (feature, fix, refactor).

.PARAMETER Paired
    Create paired worktrees for both repos.

.EXAMPLE
    feature-setup.ps1 -Name "user-auth" -Repo client-manager
    feature-setup.ps1 -Name "api-refactor" -Type refactor -Paired
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    [string]$Repo = "client-manager",
    [string]$Type = "feature",
    [switch]$Paired,
    [string]$Description = ""
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$PoolFile = "C:\scripts\_machine\worktrees.pool.json"
$BaseDir = "C:\Projects"
$WorktreeBase = "C:\Projects\worker-agents"

function Get-FreeAgent {
    $pool = Get-Content $PoolFile -Raw | ConvertFrom-Json

    foreach ($agent in $pool.agents) {
        if ($agent.status -eq "FREE") {
            return $agent
        }
    }

    return $null
}

function Mark-AgentBusy {
    param([string]$AgentId, [string]$Branch, [string]$Repo)

    $pool = Get-Content $PoolFile -Raw | ConvertFrom-Json

    foreach ($agent in $pool.agents) {
        if ($agent.id -eq $AgentId) {
            $agent.status = "BUSY"
            $agent.branch = $Branch
            $agent.repo = $Repo
            $agent.startTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }

    $pool | ConvertTo-Json -Depth 10 | Set-Content $PoolFile -Encoding UTF8
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           ONE-CLICK FEATURE SETUP                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Find free agent
Write-Host "1. Finding free agent..." -ForegroundColor Yellow
$agent = Get-FreeAgent

if (-not $agent) {
    Write-Host "   ✗ No free agents available!" -ForegroundColor Red
    Write-Host "   Run: worktree-status.ps1 to check pool" -ForegroundColor Gray
    exit 1
}

Write-Host "   ✓ Found: $($agent.id)" -ForegroundColor Green

# Step 2: Create branch name
$branchName = "$Type/$Name"
Write-Host ""
Write-Host "2. Branch: $branchName" -ForegroundColor Yellow

# Step 3: Create worktree
Write-Host ""
Write-Host "3. Creating worktree..." -ForegroundColor Yellow

$worktreePath = "$WorktreeBase\$($agent.id)\$Repo"
$repoPath = "$BaseDir\$Repo"

# Ensure base exists
if (-not (Test-Path $worktreePath)) {
    New-Item -ItemType Directory -Path (Split-Path $worktreePath) -Force | Out-Null
}

# Create worktree with new branch
Push-Location $repoPath
git fetch origin 2>&1 | Out-Null
git worktree add -b $branchName $worktreePath develop 2>&1

if ($LASTEXITCODE -ne 0) {
    # Branch might exist, try without -b
    git worktree add $worktreePath $branchName 2>&1
}

Pop-Location

if (Test-Path $worktreePath) {
    Write-Host "   ✓ Worktree created: $worktreePath" -ForegroundColor Green
}
else {
    Write-Host "   ✗ Failed to create worktree" -ForegroundColor Red
    exit 1
}

# Step 4: Mark agent busy
Write-Host ""
Write-Host "4. Marking agent busy..." -ForegroundColor Yellow
Mark-AgentBusy -AgentId $agent.id -Branch $branchName -Repo $Repo
Write-Host "   ✓ $($agent.id) marked BUSY" -ForegroundColor Green

# Step 5: Create paired worktree if requested
if ($Paired) {
    Write-Host ""
    Write-Host "5. Creating paired worktree..." -ForegroundColor Yellow

    $pairedRepo = if ($Repo -eq "client-manager") { "hazina" } else { "client-manager" }
    $pairedPath = "$WorktreeBase\$($agent.id)\$pairedRepo"
    $pairedRepoPath = "$BaseDir\$pairedRepo"

    Push-Location $pairedRepoPath
    git fetch origin 2>&1 | Out-Null
    git worktree add -b $branchName $pairedPath develop 2>&1

    if ($LASTEXITCODE -ne 0) {
        git worktree add $pairedPath $branchName 2>&1
    }
    Pop-Location

    if (Test-Path $pairedPath) {
        Write-Host "   ✓ Paired: $pairedPath" -ForegroundColor Green
    }
}

# Step 6: Create todo list
Write-Host ""
Write-Host "6. Creating todo list..." -ForegroundColor Yellow

$todos = @"
# Feature: $Name

## Tasks
- [ ] Review existing code
- [ ] Plan implementation
- [ ] Implement core functionality
- [ ] Add unit tests
- [ ] Update documentation
- [ ] Create PR

## Notes
Branch: $branchName
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm")
"@

$todoPath = "$worktreePath\TODO.md"
Set-Content -Path $todoPath -Value $todos -Encoding UTF8
Write-Host "   ✓ TODO.md created" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ FEATURE SETUP COMPLETE!" -ForegroundColor Green
Write-Host ""
Write-Host "  Branch:    $branchName" -ForegroundColor White
Write-Host "  Agent:     $($agent.id)" -ForegroundColor White
Write-Host "  Worktree:  $worktreePath" -ForegroundColor White
if ($Paired) {
    Write-Host "  Paired:    $pairedPath" -ForegroundColor White
}
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "    cd $worktreePath" -ForegroundColor Gray
Write-Host "    code ." -ForegroundColor Gray
Write-Host ""
