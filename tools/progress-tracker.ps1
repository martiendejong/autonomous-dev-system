<#
.SYNOPSIS
    Progress Tracker
    50-Expert Council V2 Improvement #32 | Priority: 2.0

.DESCRIPTION
    Visual progress on multi-step tasks.

.PARAMETER Start
    Start tracking a task.

.PARAMETER Name
    Task name.

.PARAMETER Steps
    Number of steps.

.PARAMETER Update
    Update progress.

.PARAMETER Step
    Current step.

.PARAMETER Complete
    Mark task complete.

.PARAMETER Status
    Show all tracked tasks.

.EXAMPLE
    progress-tracker.ps1 -Start -Name "Feature X" -Steps 5
    progress-tracker.ps1 -Update -Name "Feature X" -Step 3
#>

param(
    [switch]$Start,
    [string]$Name = "",
    [int]$Steps = 0,
    [switch]$Update,
    [int]$Step = 0,
    [switch]$Complete,
    [switch]$Status
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ProgressFile = "C:\scripts\_machine\progress_tracking.json"

if (-not (Test-Path $ProgressFile)) {
    @{
        tasks = @{}
        completed = @()
    } | ConvertTo-Json -Depth 10 | Set-Content $ProgressFile -Encoding UTF8
}

$data = Get-Content $ProgressFile -Raw | ConvertFrom-Json

function Show-ProgressBar {
    param([int]$Current, [int]$Total, [string]$Name)

    $percent = [Math]::Round(($Current / $Total) * 100)
    $filled = [Math]::Round($percent / 5)
    $empty = 20 - $filled
    $bar = "█" * $filled + "░" * $empty

    $color = if ($percent -ge 100) { "Green" } elseif ($percent -ge 50) { "Yellow" } else { "Cyan" }

    Write-Host "  $Name" -ForegroundColor White
    Write-Host "  [$bar] $percent% ($Current/$Total)" -ForegroundColor $color
}

if ($Start -and $Name -and $Steps -gt 0) {
    $task = @{
        name = $Name
        totalSteps = $Steps
        currentStep = 0
        startTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        lastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    if (-not $data.tasks) { $data.tasks = @{} }
    $data.tasks | Add-Member -NotePropertyName $Name -NotePropertyValue $task -Force
    $data | ConvertTo-Json -Depth 10 | Set-Content $ProgressFile -Encoding UTF8

    Write-Host "✓ Started tracking: $Name ($Steps steps)" -ForegroundColor Green
    Write-Host ""
    Show-ProgressBar -Current 0 -Total $Steps -Name $Name
}
elseif ($Update -and $Name -and $Step -gt 0) {
    if ($data.tasks.$Name) {
        $data.tasks.$Name.currentStep = $Step
        $data.tasks.$Name.lastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $data | ConvertTo-Json -Depth 10 | Set-Content $ProgressFile -Encoding UTF8

        Write-Host "✓ Updated: $Name" -ForegroundColor Green
        Write-Host ""
        Show-ProgressBar -Current $Step -Total $data.tasks.$Name.totalSteps -Name $Name
    }
    else {
        Write-Host "Task not found: $Name" -ForegroundColor Red
    }
}
elseif ($Complete -and $Name) {
    if ($data.tasks.$Name) {
        $task = $data.tasks.$Name
        $task.currentStep = $task.totalSteps
        $task.completedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

        $data.completed += $task
        $data.tasks.PSObject.Properties.Remove($Name)
        $data | ConvertTo-Json -Depth 10 | Set-Content $ProgressFile -Encoding UTF8

        Write-Host ""
        Write-Host "  ╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "  ║    ✅  TASK COMPLETED: $($Name.PadRight(33))  ║" -ForegroundColor Green
        Write-Host "  ╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""

        # Celebrate!
        & "$PSScriptRoot\celebrate.ps1" -Win -Message "Completed: $Name"
    }
    else {
        Write-Host "Task not found: $Name" -ForegroundColor Red
    }
}
elseif ($Status) {
    Write-Host "=== PROGRESS TRACKER ===" -ForegroundColor Cyan
    Write-Host ""

    $activeTasks = $data.tasks.PSObject.Properties

    if ($activeTasks.Count -eq 0) {
        Write-Host "  No active tasks being tracked" -ForegroundColor Gray
    }
    else {
        Write-Host "ACTIVE TASKS:" -ForegroundColor Yellow
        Write-Host ""
        foreach ($t in $activeTasks) {
            $task = $t.Value
            Show-ProgressBar -Current $task.currentStep -Total $task.totalSteps -Name $task.name
            Write-Host ""
        }
    }

    if ($data.completed.Count -gt 0) {
        Write-Host "RECENTLY COMPLETED:" -ForegroundColor Green
        $data.completed | Select-Object -Last 5 | ForEach-Object {
            Write-Host "  ✓ $($_.name)" -ForegroundColor Gray
        }
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Start -Name 'x' -Steps n   Start tracking" -ForegroundColor White
    Write-Host "  -Update -Name 'x' -Step n   Update progress" -ForegroundColor White
    Write-Host "  -Complete -Name 'x'         Mark complete" -ForegroundColor White
    Write-Host "  -Status                     Show all tasks" -ForegroundColor White
}
