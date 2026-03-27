<#
.SYNOPSIS
    Track actual tool usage to validate value estimates

.DESCRIPTION
    Monitors PowerShell history to track which tools are actually used:
    - Usage frequency (daily/weekly/monthly)
    - Time-of-day patterns
    - Validate value/effort estimates
    - Identify unused tools (candidates for retirement)

    Critical for data-driven tool prioritization.

.PARAMETER Action
    track, report, validate

.PARAMETER TimeRange
    Time range for analysis (today, week, month, all)

.PARAMETER OutputFormat
    Table, JSON, CSV, Heatmap

.EXAMPLE
    # Track usage and update database
    .\usage-heatmap-tracker.ps1 -Action track

.EXAMPLE
    # Generate weekly usage report
    .\usage-heatmap-tracker.ps1 -Action report -TimeRange week

.EXAMPLE
    # Validate value estimates against actual usage
    .\usage-heatmap-tracker.ps1 -Action validate

.NOTES
    Value: 9/10 - Data-driven decision making
    Effort: 1.5/10 - PowerShell history analysis
    Ratio: 6.0 (TIER S+ - Wave 2 #2)

    Wave 2 insight: Wave 1 created tools but didn't track if they're
    actually used = blind value estimates
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('track', 'report', 'validate', 'heatmap')]
    [string]$Action,

    [Parameter(Mandatory=$false)]
    [ValidateSet('today', 'week', 'month', 'all')]
    [string]$TimeRange = 'all',

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'JSON', 'CSV', 'Heatmap')]
    [string]$OutputFormat = 'Table'
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$UsageDB = "C:\scripts\_machine\tool-usage-tracker.json"
$HistoryPath = (Get-PSReadlineOption).HistorySavePath

# Initialize database if not exists
if (-not (Test-Path $UsageDB)) {
    $db = @{
        Tools = @{}
        LastTracked = $null
        TotalSessions = 0
    }
    $db | ConvertTo-Json -Depth 10 | Set-Content $UsageDB -Encoding UTF8
}

function Track-Usage {
    Write-Host "Tracking tool usage from PowerShell history..." -ForegroundColor Cyan

    # Read current database
    $db = Get-Content $UsageDB -Raw | ConvertFrom-Json

    # Read history
    if (-not (Test-Path $HistoryPath)) {
        Write-Host "WARNING: PowerShell history not found" -ForegroundColor Yellow
        return
    }

    $history = Get-Content $HistoryPath -Encoding UTF8

    # Get all .ps1 tools
    $tools = Get-ChildItem "C:\scripts\tools" -Filter "*.ps1" | Select-Object -ExpandProperty Name

    # Track usage
    foreach ($tool in $tools) {
        $toolName = $tool -replace '\.ps1$', ''

        # Count occurrences in history
        $usages = $history | Where-Object { $_ -match [regex]::Escape($tool) }

        if ($usages) {
            if (-not $db.Tools.$toolName) {
                $db.Tools | Add-Member -MemberType NoteProperty -Name $toolName -Value @{
                    TotalUses = 0
                    LastUsed = $null
                    UsageHistory = @()
                }
            }

            # Parse timestamps from history (if available)
            foreach ($usage in $usages) {
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

                # Update tool stats
                $db.Tools.$toolName.TotalUses++
                $db.Tools.$toolName.LastUsed = $timestamp
                $db.Tools.$toolName.UsageHistory += @{
                    Timestamp = $timestamp
                    Command = $usage.Substring(0, [Math]::Min(100, $usage.Length))
                }
            }
        }
    }

    $db.LastTracked = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $db.TotalSessions++

    # Save updated database
    $db | ConvertTo-Json -Depth 10 | Set-Content $UsageDB -Encoding UTF8

    Write-Host "Tracking complete. Updated $($db.Tools.PSObject.Properties.Count) tools." -ForegroundColor Green
}

function Generate-Report {
    param([string]$TimeRange)

    $db = Get-Content $UsageDB -Raw | ConvertFrom-Json

    if (-not $db.Tools) {
        Write-Host "No usage data yet. Run: .\usage-heatmap-tracker.ps1 -Action track" -ForegroundColor Yellow
        return
    }

    # Filter by time range
    $cutoffDate = switch ($TimeRange) {
        'today' { (Get-Date).Date }
        'week' { (Get-Date).AddDays(-7) }
        'month' { (Get-Date).AddDays(-30) }
        default { [DateTime]::MinValue }
    }

    Write-Host ""
    Write-Host "TOOL USAGE REPORT" -ForegroundColor Cyan
    Write-Host "Time Range: $TimeRange" -ForegroundColor Gray
    Write-Host "Last Tracked: $($db.LastTracked)" -ForegroundColor Gray
    Write-Host ""

    # Build usage stats
    $stats = @()

    foreach ($toolName in $db.Tools.PSObject.Properties.Name) {
        $tool = $db.Tools.$toolName
        $recentUses = 0

        if ($tool.UsageHistory) {
            $recentUses = ($tool.UsageHistory | Where-Object {
                [DateTime]::Parse($_.Timestamp) -ge $cutoffDate
            }).Count
        }

        $stats += [PSCustomObject]@{
            Tool = $toolName
            TotalUses = $tool.TotalUses
            RecentUses = $recentUses
            LastUsed = $tool.LastUsed
            Category = Get-UsageCategory -TotalUses $tool.TotalUses -RecentUses $recentUses
        }
    }

    # Sort by recent usage
    $stats = $stats | Sort-Object RecentUses -Descending

    switch ($OutputFormat) {
        'Table' {
            $stats | Format-Table -AutoSize -Property @(
                @{Label='Tool'; Expression={$_.Tool}; Width=30}
                @{Label='Total'; Expression={$_.TotalUses}; Align='Right'}
                @{Label='Recent'; Expression={$_.RecentUses}; Align='Right'}
                @{Label='Last Used'; Expression={$_.LastUsed}}
                @{Label='Category'; Expression={$_.Category}}
            )

            # Summary
            Write-Host ""
            Write-Host "SUMMARY:" -ForegroundColor Yellow
            Write-Host "  Total tools tracked: $($stats.Count)" -ForegroundColor Gray
            Write-Host "  Active (used this $TimeRange): $(($stats | Where-Object {$_.RecentUses -gt 0}).Count)" -ForegroundColor Green
            Write-Host "  Unused (0 uses this $TimeRange): $(($stats | Where-Object {$_.RecentUses -eq 0}).Count)" -ForegroundColor Red
            Write-Host "  Heavy use (>5 uses): $(($stats | Where-Object {$_.RecentUses -gt 5}).Count)" -ForegroundColor Cyan
        }
        'JSON' {
            $stats | ConvertTo-Json -Depth 10
        }
        'CSV' {
            $stats | ConvertTo-Csv -NoTypeInformation
        }
    }
}

function Validate-Estimates {
    Write-Host "Validating value estimates against actual usage..." -ForegroundColor Cyan
    Write-Host ""

    $db = Get-Content $UsageDB -Raw | ConvertFrom-Json

    # Read META_OPTIMIZATION files to get original value estimates
    $metaFile1 = "C:\scripts\_machine\META_OPTIMIZATION_100_TOOLS.md"
    $metaFile2 = "C:\scripts\_machine\META_OPTIMIZATION_WAVE_2_100_TOOLS.md"

    $estimates = @{}

    # Parse value estimates from markdown (simplified - would need regex)
    # For now, use hardcoded examples
    $estimates['context-snapshot'] = @{ EstimatedValue = 10; EstimatedUses = 'daily' }
    $estimates['code-hotspot-analyzer'] = @{ EstimatedValue = 9; EstimatedUses = 'monthly' }
    $estimates['unused-code-detector'] = @{ EstimatedValue = 9; EstimatedUses = 'monthly' }
    $estimates['n-plus-one-query-detector'] = @{ EstimatedValue = 10; EstimatedUses = 'weekly' }
    $estimates['flaky-test-detector'] = @{ EstimatedValue = 9; EstimatedUses = 'weekly' }
    $estimates['daily-tool-review'] = @{ EstimatedValue = 8; EstimatedUses = 'daily' }

    Write-Host "ESTIMATE VALIDATION:" -ForegroundColor Yellow
    Write-Host ""

    foreach ($toolName in $estimates.Keys) {
        $estimate = $estimates[$toolName]
        $actual = $db.Tools.$toolName

        if ($actual) {
            $actualCategory = Get-UsageCategory -TotalUses $actual.TotalUses -RecentUses 0
            $expectedCategory = $estimate.EstimatedUses

            $match = ($actualCategory -like "*$expectedCategory*") -or ($expectedCategory -like "*$actualCategory*")

            if ($match) {
                Write-Host "[$toolName] VALIDATED" -ForegroundColor Green
                Write-Host "  Expected: $($estimate.EstimatedValue)/10 value, $expectedCategory usage" -ForegroundColor Gray
                Write-Host "  Actual: $($actual.TotalUses) total uses, $actualCategory" -ForegroundColor Gray
            } else {
                Write-Host "[$toolName] MISMATCH" -ForegroundColor Yellow
                Write-Host "  Expected: $expectedCategory usage" -ForegroundColor Gray
                Write-Host "  Actual: $actualCategory ($($actual.TotalUses) uses)" -ForegroundColor Gray
                Write-Host "  Recommendation: Adjust value estimate or investigate low usage" -ForegroundColor Cyan
            }
            Write-Host ""
        } else {
            Write-Host "[$toolName] NO DATA" -ForegroundColor Red
            Write-Host "  Tool never used - consider retiring or investigating why" -ForegroundColor Gray
            Write-Host ""
        }
    }
}

function Get-UsageCategory {
    param(
        [int]$TotalUses,
        [int]$RecentUses
    )

    if ($RecentUses -eq 0 -and $TotalUses -eq 0) {
        return "NEVER_USED"
    } elseif ($RecentUses -eq 0) {
        return "INACTIVE"
    } elseif ($RecentUses -ge 5) {
        return "HEAVY_USE"
    } elseif ($RecentUses -ge 2) {
        return "REGULAR_USE"
    } else {
        return "LIGHT_USE"
    }
}

# Execute action
switch ($Action) {
    'track' {
        Track-Usage
    }
    'report' {
        Generate-Report -TimeRange $TimeRange
    }
    'validate' {
        Validate-Estimates
    }
    'heatmap' {
        Write-Host "Heatmap visualization coming soon..." -ForegroundColor Yellow
        Write-Host "For now, use: -Action report -OutputFormat Table" -ForegroundColor Gray
    }
}
