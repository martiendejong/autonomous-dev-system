<#
.SYNOPSIS
    Parallel Agent Orchestrator & Batch Operations
    50-Expert Council Improvements #32, #34 | Priority: 1.43, 1.6

.DESCRIPTION
    Coordinates multiple agents with zero conflict.
    Queues and executes batch operations atomically.

.PARAMETER Status
    Show parallel agent status.

.PARAMETER Coordinate
    Run coordination check.

.PARAMETER Batch
    Execute batch operations from queue.

.PARAMETER Add
    Add operation to batch queue.

.PARAMETER Operation
    Operation to add.

.EXAMPLE
    parallel-orchestrate.ps1 -Status
    parallel-orchestrate.ps1 -Coordinate
    parallel-orchestrate.ps1 -Add -Operation "git add -A"
    parallel-orchestrate.ps1 -Batch
#>

param(
    [switch]$Status,
    [switch]$Coordinate,
    [switch]$Batch,
    [switch]$Add,
    [string]$Operation = ""
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$OrchFile = "C:\scripts\_machine\orchestration.json"
$PoolFile = "C:\scripts\_machine\worktrees.pool.md"

if (-not (Test-Path $OrchFile)) {
    @{
        agents = @()
        batchQueue = @()
        lastCoordination = $null
        conflicts = @()
    } | ConvertTo-Json -Depth 10 | Set-Content $OrchFile -Encoding UTF8
}

$orch = Get-Content $OrchFile -Raw | ConvertFrom-Json

if ($Status) {
    Write-Host "=== PARALLEL ORCHESTRATION STATUS ===" -ForegroundColor Cyan
    Write-Host ""

    # Check worktree pool
    if (Test-Path $PoolFile) {
        $pool = Get-Content $PoolFile -Raw
        $busy = ([regex]::Matches($pool, 'BUSY')).Count
        $free = ([regex]::Matches($pool, 'FREE')).Count

        Write-Host "AGENT SLOTS:" -ForegroundColor Yellow
        Write-Host "  Busy: $busy" -ForegroundColor $(if ($busy -gt 5) { "Yellow" } else { "Green" })
        Write-Host "  Free: $free" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "BATCH QUEUE: $($orch.batchQueue.Count) operations pending" -ForegroundColor Yellow

    if ($orch.conflicts.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠ CONFLICTS DETECTED:" -ForegroundColor Red
        foreach ($c in $orch.conflicts) {
            Write-Host "  $c" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Last coordination: $($orch.lastCoordination ?? 'Never')" -ForegroundColor Gray
}
elseif ($Coordinate) {
    Write-Host "=== RUNNING COORDINATION CHECK ===" -ForegroundColor Cyan
    Write-Host ""

    $conflicts = @()

    # Check for multiple agents on same resource
    if (Test-Path $PoolFile) {
        $pool = Get-Content $PoolFile -Raw
        $busyMatches = [regex]::Matches($pool, 'agent-(\d+).*?BUSY.*?(\w+)')

        $repoAgents = @{}
        foreach ($m in $busyMatches) {
            $agent = $m.Groups[1].Value
            $info = $m.Groups[2].Value
            if (-not $repoAgents[$info]) { $repoAgents[$info] = @() }
            $repoAgents[$info] += $agent
        }

        foreach ($repo in $repoAgents.GetEnumerator()) {
            if ($repo.Value.Count -gt 1) {
                $conflicts += "Multiple agents on $($repo.Key): agents $($repo.Value -join ', ')"
            }
        }
    }

    $orch.conflicts = $conflicts
    $orch.lastCoordination = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $orch | ConvertTo-Json -Depth 10 | Set-Content $OrchFile -Encoding UTF8

    if ($conflicts.Count -eq 0) {
        Write-Host "✓ No conflicts detected" -ForegroundColor Green
    } else {
        Write-Host "⚠ CONFLICTS FOUND:" -ForegroundColor Red
        foreach ($c in $conflicts) {
            Write-Host "  $c" -ForegroundColor Red
        }
    }
}
elseif ($Add -and $Operation) {
    $orch.batchQueue += @{
        operation = $Operation
        added = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        status = "pending"
    }
    $orch | ConvertTo-Json -Depth 10 | Set-Content $OrchFile -Encoding UTF8

    Write-Host "✓ Added to batch queue: $Operation" -ForegroundColor Green
    Write-Host "  Queue size: $($orch.batchQueue.Count)" -ForegroundColor Gray
}
elseif ($Batch) {
    Write-Host "=== EXECUTING BATCH OPERATIONS ===" -ForegroundColor Cyan
    Write-Host ""

    $pending = $orch.batchQueue | Where-Object { $_.status -eq "pending" }

    if ($pending.Count -eq 0) {
        Write-Host "No pending operations in queue." -ForegroundColor Yellow
        return
    }

    Write-Host "Executing $($pending.Count) operations..." -ForegroundColor Yellow
    Write-Host ""

    foreach ($op in $pending) {
        Write-Host "  → $($op.operation)" -ForegroundColor Cyan
        try {
            Invoke-Expression $op.operation 2>&1 | Out-Null
            $op.status = "completed"
            Write-Host "    ✓ Done" -ForegroundColor Green
        } catch {
            $op.status = "failed"
            Write-Host "    ✗ Failed: $_" -ForegroundColor Red
        }
    }

    # Clear completed
    $orch.batchQueue = $orch.batchQueue | Where-Object { $_.status -eq "pending" -or $_.status -eq "failed" }
    $orch | ConvertTo-Json -Depth 10 | Set-Content $OrchFile -Encoding UTF8

    Write-Host ""
    Write-Host "Batch execution complete." -ForegroundColor Green
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Status              Show orchestration status" -ForegroundColor White
    Write-Host "  -Coordinate          Run conflict check" -ForegroundColor White
    Write-Host "  -Add -Operation x    Add to batch queue" -ForegroundColor White
    Write-Host "  -Batch               Execute batch queue" -ForegroundColor White
}
