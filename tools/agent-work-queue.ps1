<#
.SYNOPSIS
    Multi-agent work queue - coordinate tasks across multiple Claude sessions

.DESCRIPTION
    Shared task queue for multiple agents running in parallel:
    - Claim tasks (mark as in-progress)
    - Release tasks (mark as complete)
    - View available work
    - Prevent duplicate work

    Critical for environments with 2+ Claude sessions active.

.PARAMETER Action
    claim, release, list, add

.PARAMETER TaskId
    Task identifier (for claim/release)

.PARAMETER Description
    Task description (for add)

.PARAMETER AgentId
    Agent identifier (auto-detected from worktree if not specified)

.EXAMPLE
    # List available work
    .\agent-work-queue.ps1 -Action list

.EXAMPLE
    # Claim a task
    .\agent-work-queue.ps1 -Action claim -TaskId "task-001"

.EXAMPLE
    # Release completed task
    .\agent-work-queue.ps1 -Action release -TaskId "task-001"

.EXAMPLE
    # Add new task to queue
    .\agent-work-queue.ps1 -Action add -Description "Implement feature X"

.NOTES
    Value: 10/10 - Critical for multi-agent coordination
    Effort: 1/10 - JSON file + claim protocol
    Ratio: 10.0 (TIER S+ - Wave 2 #1)

    Wave 2 insight: Wave 1 assumed single agent, but monitor-activity
    showed 2 Claude sessions active = coordination needed
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('claim', 'release', 'list', 'add', 'status')]
    [string]$Action,

    [Parameter(Mandatory=$false)]
    [string]$TaskId,

    [Parameter(Mandatory=$false)]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [string]$AgentId
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$QueueFile = "C:\scripts\_machine\agent-work-queue.json"

# Auto-detect agent ID from current directory if not specified
if (-not $AgentId) {
    $currentPath = Get-Location
    if ($currentPath -match 'agent-(\d+)') {
        $AgentId = "agent-$($Matches[1])"
    } else {
        $AgentId = "agent-unknown-$(Get-Date -Format 'HHmmss')"
    }
}

# Initialize queue if not exists
if (-not (Test-Path $QueueFile)) {
    $queue = @{
        Tasks = @()
        LastUpdated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    $queue | ConvertTo-Json -Depth 10 | Set-Content $QueueFile -Encoding UTF8
}

# Read queue
$queue = Get-Content $QueueFile -Raw | ConvertFrom-Json

function Add-Task {
    param([string]$Description)

    $taskId = "task-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    $task = [PSCustomObject]@{
        TaskId = $taskId
        Description = $Description
        Status = "available"
        ClaimedBy = $null
        ClaimedAt = $null
        CreatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        CompletedAt = $null
    }

    $queue.Tasks = @($queue.Tasks) + $task
    $queue.LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Save-Queue

    Write-Host "Task added: $taskId" -ForegroundColor Green
    Write-Host "  Description: $Description" -ForegroundColor Gray
    return $task
}

function Claim-Task {
    param([string]$TaskId, [string]$AgentId)

    $task = $queue.Tasks | Where-Object { $_.TaskId -eq $TaskId }

    if (-not $task) {
        Write-Host "ERROR: Task not found: $TaskId" -ForegroundColor Red
        exit 1
    }

    if ($task.Status -ne "available") {
        Write-Host "ERROR: Task already claimed by $($task.ClaimedBy)" -ForegroundColor Red
        Write-Host "  Claimed at: $($task.ClaimedAt)" -ForegroundColor Gray
        exit 1
    }

    $task.Status = "in-progress"
    $task.ClaimedBy = $AgentId
    $task.ClaimedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $queue.LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Save-Queue

    Write-Host "Task claimed: $TaskId" -ForegroundColor Green
    Write-Host "  Agent: $AgentId" -ForegroundColor Gray
    Write-Host "  Description: $($task.Description)" -ForegroundColor Gray
    return $task
}

function Release-Task {
    param([string]$TaskId, [string]$AgentId)

    $task = $queue.Tasks | Where-Object { $_.TaskId -eq $TaskId }

    if (-not $task) {
        Write-Host "ERROR: Task not found: $TaskId" -ForegroundColor Red
        exit 1
    }

    if ($task.ClaimedBy -ne $AgentId) {
        Write-Host "WARNING: Task claimed by $($task.ClaimedBy), not $AgentId" -ForegroundColor Yellow
        Write-Host "  Releasing anyway..." -ForegroundColor Gray
    }

    $task.Status = "completed"
    $task.CompletedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $queue.LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Save-Queue

    Write-Host "Task completed: $TaskId" -ForegroundColor Green
    Write-Host "  Agent: $AgentId" -ForegroundColor Gray
    Write-Host "  Duration: $(Get-Duration $task.ClaimedAt $task.CompletedAt)" -ForegroundColor Gray
    return $task
}

function List-Tasks {
    $available = $queue.Tasks | Where-Object { $_.Status -eq "available" }
    $inProgress = $queue.Tasks | Where-Object { $_.Status -eq "in-progress" }
    $completed = $queue.Tasks | Where-Object { $_.Status -eq "completed" }

    Write-Host ""
    Write-Host "AGENT WORK QUEUE STATUS" -ForegroundColor Cyan
    Write-Host "Last updated: $($queue.LastUpdated)" -ForegroundColor Gray
    Write-Host ""

    if ($available.Count -gt 0) {
        Write-Host "AVAILABLE ($($available.Count)):" -ForegroundColor Green
        $available | ForEach-Object {
            Write-Host "  [$($_.TaskId)] $($_.Description)" -ForegroundColor White
            Write-Host "    Created: $($_.CreatedAt)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($inProgress.Count -gt 0) {
        Write-Host "IN PROGRESS ($($inProgress.Count)):" -ForegroundColor Yellow
        $inProgress | ForEach-Object {
            Write-Host "  [$($_.TaskId)] $($_.Description)" -ForegroundColor White
            Write-Host "    Claimed by: $($_.ClaimedBy) at $($_.ClaimedAt)" -ForegroundColor Gray
            Write-Host "    Duration: $(Get-Duration $_.ClaimedAt)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($completed.Count -gt 0) {
        Write-Host "COMPLETED (last 5):" -ForegroundColor Green
        $completed | Select-Object -Last 5 | ForEach-Object {
            Write-Host "  [$($_.TaskId)] $($_.Description)" -ForegroundColor White
            Write-Host "    By: $($_.ClaimedBy), Duration: $(Get-Duration $_.ClaimedAt $_.CompletedAt)" -ForegroundColor Gray
        }
    }
}

function Get-Status {
    $available = ($queue.Tasks | Where-Object { $_.Status -eq "available" }).Count
    $inProgress = ($queue.Tasks | Where-Object { $_.Status -eq "in-progress" }).Count
    $completed = ($queue.Tasks | Where-Object { $_.Status -eq "completed" }).Count

    [PSCustomObject]@{
        Available = $available
        InProgress = $inProgress
        Completed = $completed
        Total = $queue.Tasks.Count
        LastUpdated = $queue.LastUpdated
    }
}

function Save-Queue {
    $queue | ConvertTo-Json -Depth 10 | Set-Content $QueueFile -Encoding UTF8
}

function Get-Duration {
    param(
        [string]$Start,
        [string]$End = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    )

    $startTime = [DateTime]::ParseExact($Start, "yyyy-MM-dd HH:mm:ss", $null)
    $endTime = [DateTime]::ParseExact($End, "yyyy-MM-dd HH:mm:ss", $null)
    $duration = $endTime - $startTime

    if ($duration.TotalMinutes -lt 1) {
        return "$([Math]::Round($duration.TotalSeconds))s"
    } elseif ($duration.TotalHours -lt 1) {
        return "$([Math]::Round($duration.TotalMinutes))m"
    } else {
        return "$([Math]::Round($duration.TotalHours, 1))h"
    }
}

# Execute action
switch ($Action) {
    'add' {
        if (-not $Description) {
            Write-Host "ERROR: -Description required for add action" -ForegroundColor Red
            exit 1
        }
        Add-Task -Description $Description
    }
    'claim' {
        if (-not $TaskId) {
            Write-Host "ERROR: -TaskId required for claim action" -ForegroundColor Red
            exit 1
        }
        Claim-Task -TaskId $TaskId -AgentId $AgentId
    }
    'release' {
        if (-not $TaskId) {
            Write-Host "ERROR: -TaskId required for release action" -ForegroundColor Red
            exit 1
        }
        Release-Task -TaskId $TaskId -AgentId $AgentId
    }
    'list' {
        List-Tasks
    }
    'status' {
        Get-Status
    }
}
