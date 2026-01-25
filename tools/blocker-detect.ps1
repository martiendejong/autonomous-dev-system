<#
.SYNOPSIS
    Blocker Detector
    50-Expert Council V2 Improvement #33 | Priority: 1.8

.DESCRIPTION
    Auto-identifies and escalates blockers.

.PARAMETER Detect
    Detect blockers.

.PARAMETER Log
    Log a blocker.

.PARAMETER Message
    Blocker description.

.PARAMETER Resolve
    Mark blocker as resolved.

.PARAMETER Id
    Blocker ID.

.EXAMPLE
    blocker-detect.ps1 -Detect
    blocker-detect.ps1 -Log -Message "Waiting for API access"
#>

param(
    [switch]$Detect,
    [switch]$Log,
    [string]$Message = "",
    [switch]$Resolve,
    [int]$Id = 0,
    [switch]$List
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$BlockerFile = "C:\scripts\_machine\blockers.json"

if (-not (Test-Path $BlockerFile)) {
    @{
        blockers = @()
        resolved = @()
        nextId = 1
    } | ConvertTo-Json -Depth 10 | Set-Content $BlockerFile -Encoding UTF8
}

$data = Get-Content $BlockerFile -Raw | ConvertFrom-Json

function Detect-AutoBlockers {
    $detected = @()

    # Check for long-running processes
    $longTasks = Get-Process | Where-Object { $_.CPU -gt 300 }
    if ($longTasks) {
        $detected += "High CPU process detected (possible stuck build)"
    }

    # Check worktree status
    $poolFile = "C:\scripts\_machine\worktrees.pool.json"
    if (Test-Path $poolFile) {
        $pool = Get-Content $poolFile -Raw | ConvertFrom-Json
        $busy = ($pool.agents | Where-Object { $_.status -eq "BUSY" }).Count
        $total = $pool.agents.Count
        if ($busy -eq $total) {
            $detected += "All worktree agents are BUSY - may need to release some"
        }
    }

    # Check for failed CI
    try {
        $prChecks = gh pr checks 2>&1
        if ($prChecks -match 'fail|error') {
            $detected += "CI checks failing on current PR"
        }
    } catch {}

    # Check git status
    $gitStatus = git status --porcelain 2>&1
    $uncommitted = ($gitStatus -split "`n" | Where-Object { $_ }).Count
    if ($uncommitted -gt 50) {
        $detected += "Large number of uncommitted changes ($uncommitted files)"
    }

    return $detected
}

if ($Detect) {
    Write-Host "=== BLOCKER DETECTION ===" -ForegroundColor Cyan
    Write-Host ""

    $autoBlockers = Detect-AutoBlockers

    Write-Host "AUTO-DETECTED BLOCKERS:" -ForegroundColor Yellow
    if ($autoBlockers.Count -eq 0) {
        Write-Host "  ✓ No blockers detected" -ForegroundColor Green
    }
    else {
        foreach ($b in $autoBlockers) {
            Write-Host "  ⚠ $b" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "MANUALLY LOGGED BLOCKERS:" -ForegroundColor Yellow
    $active = $data.blockers | Where-Object { -not $_.resolved }
    if ($active.Count -eq 0) {
        Write-Host "  ✓ No active blockers" -ForegroundColor Green
    }
    else {
        foreach ($b in $active) {
            $age = [Math]::Round(((Get-Date) - [datetime]::Parse($b.logged)).TotalHours, 1)
            $urgency = if ($age -gt 24) { "🔴" } elseif ($age -gt 4) { "🟡" } else { "🟢" }
            Write-Host "  $urgency [$($b.id)] $($b.message) (${age}h ago)" -ForegroundColor White
        }
    }

    $totalBlockers = $autoBlockers.Count + $active.Count
    Write-Host ""
    if ($totalBlockers -gt 0) {
        Write-Host "⚠ Total blockers: $totalBlockers" -ForegroundColor Red
        Write-Host "  Consider: recovery-mode.ps1 -Activate" -ForegroundColor Gray
    }
}
elseif ($Log -and $Message) {
    $blocker = @{
        id = $data.nextId
        message = $Message
        logged = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        resolved = $false
    }

    $data.blockers += $blocker
    $data.nextId++
    $data | ConvertTo-Json -Depth 10 | Set-Content $BlockerFile -Encoding UTF8

    Write-Host "✓ Blocker logged: [$($blocker.id)] $Message" -ForegroundColor Yellow
}
elseif ($Resolve -and $Id -gt 0) {
    $blocker = $data.blockers | Where-Object { $_.id -eq $Id }
    if ($blocker) {
        $blocker.resolved = $true
        $blocker.resolvedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $data | ConvertTo-Json -Depth 10 | Set-Content $BlockerFile -Encoding UTF8

        Write-Host "✓ Blocker resolved: [$Id] $($blocker.message)" -ForegroundColor Green
    }
    else {
        Write-Host "Blocker not found: $Id" -ForegroundColor Red
    }
}
elseif ($List) {
    Write-Host "=== ALL BLOCKERS ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "ACTIVE:" -ForegroundColor Yellow
    $data.blockers | Where-Object { -not $_.resolved } | ForEach-Object {
        Write-Host "  [$($_.id)] $($_.message)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "RESOLVED (recent):" -ForegroundColor Green
    $data.blockers | Where-Object { $_.resolved } | Select-Object -Last 5 | ForEach-Object {
        Write-Host "  [$($_.id)] $($_.message)" -ForegroundColor Gray
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Detect                  Auto-detect blockers" -ForegroundColor White
    Write-Host "  -Log -Message 'x'        Log a blocker" -ForegroundColor White
    Write-Host "  -Resolve -Id n           Resolve blocker" -ForegroundColor White
    Write-Host "  -List                    List all blockers" -ForegroundColor White
}
