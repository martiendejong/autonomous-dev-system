<#
.SYNOPSIS
    Intelligent Prioritization Engine
    50-Expert Council Improvement #9 | Priority: 2.25

.DESCRIPTION
    Auto-sorts tasks by HP's actual preferences (learned from history).
    Uses value/effort scoring based on past decisions.

.PARAMETER Tasks
    Array of tasks to prioritize.

.PARAMETER Learn
    Learn from a completed task's actual priority.

.PARAMETER TaskName
    Task name for learning.

.PARAMETER ActualPriority
    Actual priority (1-10) for learning.

.PARAMETER Show
    Show current priority model.

.EXAMPLE
    intelligent-prioritize.ps1 -Tasks @("Fix bug", "Add feature", "Write docs")
    intelligent-prioritize.ps1 -Learn -TaskName "Fix bug" -ActualPriority 9
#>

param(
    [string[]]$Tasks = @()

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
,
    [switch]$Learn,
    [string]$TaskName = "",
    [int]$ActualPriority = 0,
    [switch]$Show
)

$PriorityFile = "C:\scripts\_machine\priority_model.json"

if (-not (Test-Path $PriorityFile)) {
    @{
        keywords = @{
            "bug" = 9
            "fix" = 8
            "error" = 9
            "urgent" = 10
            "critical" = 10
            "security" = 10
            "feature" = 6
            "refactor" = 5
            "docs" = 4
            "test" = 7
            "ci" = 7
            "deploy" = 8
            "migration" = 7
            "performance" = 6
            "cleanup" = 3
            "todo" = 5
        }
        effortKeywords = @{
            "simple" = 2
            "quick" = 2
            "easy" = 2
            "complex" = 8
            "large" = 7
            "refactor" = 6
            "migration" = 7
            "small" = 3
        }
        history = @()
        lastUpdate = $null
    } | ConvertTo-Json -Depth 10 | Set-Content $PriorityFile -Encoding UTF8
}

$model = Get-Content $PriorityFile -Raw | ConvertFrom-Json

function Score-Task {
    param([string]$Task)

    $lower = $Task.ToLower()
    $value = 5  # Base value
    $effort = 5  # Base effort

    foreach ($kw in $model.keywords.PSObject.Properties) {
        if ($lower -match $kw.Name) {
            $value = [Math]::Max($value, $kw.Value)
        }
    }

    foreach ($kw in $model.effortKeywords.PSObject.Properties) {
        if ($lower -match $kw.Name) {
            $effort = $kw.Value
        }
    }

    # Priority = Value / Effort (higher is better)
    $priority = [Math]::Round($value / [Math]::Max(1, $effort) * 10, 1)

    return @{
        task = $Task
        value = $value
        effort = $effort
        priority = $priority
    }
}

if ($Tasks.Count -gt 0) {
    Write-Host "=== INTELLIGENT PRIORITIZATION ===" -ForegroundColor Cyan
    Write-Host ""

    $scored = $Tasks | ForEach-Object { Score-Task $_ }
    $sorted = $scored | Sort-Object { $_.priority } -Descending

    Write-Host "PRIORITIZED TASKS:" -ForegroundColor Yellow
    $rank = 1
    foreach ($t in $sorted) {
        $color = if ($t.priority -ge 15) { "Green" } elseif ($t.priority -ge 8) { "Yellow" } else { "Gray" }
        Write-Host "  $rank. [$($t.priority.ToString('0.0'))] $($t.task)" -ForegroundColor $color
        Write-Host "     Value: $($t.value)/10 | Effort: $($t.effort)/10" -ForegroundColor DarkGray
        $rank++
    }

    Write-Host ""
    Write-Host "TOP 5 RECOMMENDED:" -ForegroundColor Magenta
    $sorted | Select-Object -First 5 | ForEach-Object {
        Write-Host "  → $($_.task)" -ForegroundColor White
    }
}
elseif ($Learn -and $TaskName -and $ActualPriority -gt 0) {
    # Learn from actual priority
    $lower = $TaskName.ToLower()

    # Extract keywords and update weights
    $words = $lower -split '\s+'
    foreach ($word in $words) {
        if ($word.Length -gt 3) {
            if ($model.keywords.$word) {
                # Adjust existing weight
                $current = $model.keywords.$word
                $new = [Math]::Round(($current + $ActualPriority) / 2)
                $model.keywords | Add-Member -NotePropertyName $word -NotePropertyValue $new -Force
            } else {
                # Add new keyword
                $model.keywords | Add-Member -NotePropertyName $word -NotePropertyValue $ActualPriority -Force
            }
        }
    }

    $model.history += @{
        task = $TaskName
        priority = $ActualPriority
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    $model.lastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $model | ConvertTo-Json -Depth 10 | Set-Content $PriorityFile -Encoding UTF8

    Write-Host "✓ Learned: '$TaskName' = priority $ActualPriority" -ForegroundColor Green
}
elseif ($Show) {
    Write-Host "=== PRIORITY MODEL ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "VALUE KEYWORDS:" -ForegroundColor Yellow
    $model.keywords.PSObject.Properties | Sort-Object Value -Descending | ForEach-Object {
        Write-Host "  $($_.Name.PadRight(15)) $($_.Value)/10" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "EFFORT KEYWORDS:" -ForegroundColor Yellow
    $model.effortKeywords.PSObject.Properties | Sort-Object Value | ForEach-Object {
        Write-Host "  $($_.Name.PadRight(15)) $($_.Value)/10" -ForegroundColor White
    }

    if ($model.history.Count -gt 0) {
        Write-Host ""
        Write-Host "RECENT LEARNINGS:" -ForegroundColor Yellow
        $model.history | Select-Object -Last 5 | ForEach-Object {
            Write-Host "  $($_.task) → $($_.priority)" -ForegroundColor Gray
        }
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Tasks @('t1', 't2')        Prioritize tasks" -ForegroundColor White
    Write-Host "  -Learn -TaskName x -ActualPriority n   Learn from completion" -ForegroundColor White
    Write-Host "  -Show                       Show priority model" -ForegroundColor White
}
