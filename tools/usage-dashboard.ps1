# Usage Dashboard - Real-time tool usage analytics
# Replaces usage-heatmap-tracker with real-time data

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('dashboard', 'top10', 'today', 'validate', 'export')]
    [string]$View = 'dashboard',

    [Parameter(Mandatory=$false)]
    [string]$ExportPath
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$StatsFile = "C:\scripts\_machine\tool-usage-stats.json"
$LogFile = "C:\scripts\_machine\tool-usage-log.jsonl"

if (-not (Test-Path $StatsFile)) {
    Write-Host "No usage data yet. Tools will auto-log when used." -ForegroundColor Yellow
    exit 0
}

$stats = Get-Content $StatsFile -Raw | ConvertFrom-Json

function Show-Dashboard {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  TOOL USAGE DASHBOARD (Real-Time)" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    $tools = @()
    foreach ($toolName in $stats.Tools.PSObject.Properties.Name) {
        $tool = $stats.Tools.$toolName
        $tools += [PSCustomObject]@{
            Tool = $toolName
            TotalCalls = $tool.TotalCalls
            FirstUsed = $tool.FirstUsed
            LastUsed = $tool.LastUsed
            Category = Get-UsageCategory -TotalCalls $tool.TotalCalls
        }
    }

    # Sort by total calls
    $tools = $tools | Sort-Object TotalCalls -Descending

    # Top 10
    Write-Host "TOP 10 MOST USED TOOLS:" -ForegroundColor Yellow
    $tools | Select-Object -First 10 | Format-Table -AutoSize -Property @(
        @{Label='Tool'; Expression={$_.Tool}; Width=35}
        @{Label='Calls'; Expression={$_.TotalCalls}; Align='Right'}
        @{Label='Last Used'; Expression={$_.LastUsed}}
        @{Label='Category'; Expression={$_.Category}}
    )

    # Summary stats
    Write-Host ""
    Write-Host "SUMMARY:" -ForegroundColor Yellow
    Write-Host "  Total tools tracked: $($tools.Count)" -ForegroundColor Gray
    Write-Host "  Heavy use (>10 calls): $(($tools | Where-Object {$_.TotalCalls -gt 10}).Count)" -ForegroundColor Green
    Write-Host "  Light use (1-10 calls): $(($tools | Where-Object {$_.TotalCalls -le 10 -and $_.TotalCalls -gt 0}).Count)" -ForegroundColor Yellow
    Write-Host "  Never used: $(117 - $tools.Count)" -ForegroundColor Red
    Write-Host ""
}

function Show-Top10 {
    $tools = @()
    foreach ($toolName in $stats.Tools.PSObject.Properties.Name) {
        $tool = $stats.Tools.$toolName
        $tools += [PSCustomObject]@{
            Tool = $toolName
            Calls = $tool.TotalCalls
        }
    }

    Write-Host "TOP 10 TOOLS:" -ForegroundColor Cyan
    $tools | Sort-Object Calls -Descending | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $($_.Calls)x - $($_.Tool)" -ForegroundColor White
    }
}

function Show-Today {
    if (-not (Test-Path $LogFile)) {
        Write-Host "No log data available" -ForegroundColor Yellow
        return
    }

    $today = (Get-Date).Date
    $logs = Get-Content $LogFile -Encoding UTF8 | ForEach-Object {
        $_ | ConvertFrom-Json
    } | Where-Object {
        [DateTime]::Parse($_.Timestamp).Date -eq $today
    }

    Write-Host "TODAY'S USAGE:" -ForegroundColor Cyan
    Write-Host ""

    $todayStats = $logs | Group-Object Tool | Sort-Object Count -Descending

    $todayStats | ForEach-Object {
        Write-Host "  $($_.Count)x - $($_.Name)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "Total calls today: $($logs.Count)" -ForegroundColor Gray
}

function Validate-Estimates {
    Write-Host "VALIDATING VALUE ESTIMATES:" -ForegroundColor Cyan
    Write-Host ""

    # Expected usage patterns from META_OPTIMIZATION
    $estimates = @{
        'context-snapshot' = 'daily'  # Expected: high usage
        'code-hotspot-analyzer' = 'monthly'
        'daily-tool-review' = 'daily'
        'agent-work-queue' = 'daily'
    }

    foreach ($toolName in $estimates.Keys) {
        $expected = $estimates[$toolName]
        $actual = $stats.Tools.$toolName

        if ($actual) {
            $calls = $actual.TotalCalls
            $category = Get-UsageCategory -TotalCalls $calls

            $match = if ($expected -eq 'daily' -and $calls -gt 5) { $true }
                     elseif ($expected -eq 'weekly' -and $calls -gt 2) { $true }
                     elseif ($expected -eq 'monthly' -and $calls -gt 0) { $true }
                     else { $false }

            if ($match) {
                Write-Host "[$toolName] VALIDATED" -ForegroundColor Green
                Write-Host "  Expected: $expected, Actual: $calls calls" -ForegroundColor Gray
            } else {
                Write-Host "[$toolName] UNDERUSED" -ForegroundColor Yellow
                Write-Host "  Expected: $expected, Actual: $calls calls" -ForegroundColor Gray
                Write-Host "  Recommendation: Investigate why or reduce priority" -ForegroundColor Cyan
            }
        } else {
            Write-Host "[$toolName] NEVER USED" -ForegroundColor Red
            Write-Host "  Expected: $expected, Actual: 0 calls" -ForegroundColor Gray
            Write-Host "  Recommendation: Consider removing from quick reference" -ForegroundColor Cyan
        }
        Write-Host ""
    }
}

function Export-Data {
    param([string]$Path)

    if (-not $Path) {
        $Path = "tool-usage-export-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    }

    $export = @{
        ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Stats = $stats
        Logs = if (Test-Path $LogFile) {
            Get-Content $LogFile -Encoding UTF8 | ForEach-Object { $_ | ConvertFrom-Json }
        } else { @() }
    }

    $export | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8

    Write-Host "Data exported to: $Path" -ForegroundColor Green
}

function Get-UsageCategory {
    param([int]$TotalCalls)

    if ($TotalCalls -eq 0) { return "NEVER_USED" }
    elseif ($TotalCalls -ge 20) { return "HEAVY_USE" }
    elseif ($TotalCalls -ge 5) { return "REGULAR_USE" }
    else { return "LIGHT_USE" }
}

# Execute view
switch ($View) {
    'dashboard' { Show-Dashboard }
    'top10' { Show-Top10 }
    'today' { Show-Today }
    'validate' { Validate-Estimates }
    'export' { Export-Data -Path $ExportPath }
}
