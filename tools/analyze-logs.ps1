<#
.SYNOPSIS
    Analyzes application logs for errors, patterns, and performance issues.

.DESCRIPTION
    Parses ASP.NET Core and frontend logs to detect error patterns,
    performance bottlenecks, and trends.

    Features:
    - Parse structured logs (JSON, Serilog)
    - Error pattern detection and grouping
    - Performance bottleneck identification
    - Log level statistics
    - Time-based analysis
    - Export to HTML report

.PARAMETER LogPath
    Path to log file or directory

.PARAMETER LogFormat
    Log format: json, text, serilog (default: auto-detect)

.PARAMETER TimeRange
    Time range to analyze: 1h, 24h, 7d (default: 24h)

.PARAMETER MinLevel
    Minimum log level: Trace, Debug, Information, Warning, Error, Critical

.PARAMETER Pattern
    Search pattern (regex)

.PARAMETER Top
    Show top N most common errors (default: 10)

.PARAMETER OutputFormat
    Output format: console, html, json (default: console)

.EXAMPLE
    .\analyze-logs.ps1 -LogPath "C:\Projects\client-manager\logs"
    .\analyze-logs.ps1 -LogPath "app.log" -MinLevel Error
    .\analyze-logs.ps1 -LogPath "logs" -Pattern "timeout|deadlock"
    .\analyze-logs.ps1 -LogPath "logs" -TimeRange 1h -OutputFormat html
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$LogPath,

    [ValidateSet("json", "text", "serilog", "auto")]
    [string]$LogFormat = "auto",

    [ValidateSet("1h", "24h", "7d", "30d")]
    [string]$TimeRange = "24h",

    [ValidateSet("Trace", "Debug", "Information", "Warning", "Error", "Critical")]
    [string]$MinLevel = "Information",

    [string]$Pattern,
    [int]$Top = 10,

    [ValidateSet("console", "html", "json")]
    [string]$OutputFormat = "console"
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$script:LogEntries = @()
$script:ErrorPatterns = @{}

function Get-LogFiles {
    param([string]$Path)

    if (Test-Path $Path -PathType Container) {
        return Get-ChildItem $Path -Filter "*.log" -Recurse | Sort-Object LastWriteTime -Descending
    } elseif (Test-Path $Path) {
        return @(Get-Item $Path)
    } else {
        Write-Host "ERROR: Log path not found: $Path" -ForegroundColor Red
        return @()
    }
}

function Parse-JsonLog {
    param([string]$Line)

    try {
        $entry = $Line | ConvertFrom-Json

        return @{
            "Timestamp" = if ($entry.Timestamp) { [DateTime]::Parse($entry.Timestamp) } else { Get-Date }
            "Level" = $entry.Level -replace '@', ''
            "Message" = $entry.Message
            "Exception" = $entry.Exception
            "Source" = $entry.SourceContext
        }

    } catch {
        return $null
    }
}

function Parse-TextLog {
    param([string]$Line)

    # Try to parse common text log formats
    # Format: 2024-01-16 10:30:45 [Level] Message
    if ($Line -match '(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+\[(\w+)\]\s+(.+)') {
        return @{
            "Timestamp" = [DateTime]::Parse($matches[1])
            "Level" = $matches[2]
            "Message" = $matches[3]
            "Exception" = $null
            "Source" = $null
        }
    }

    return $null
}

function Parse-LogFile {
    param([System.IO.FileInfo]$File, [string]$Format)

    Write-Host "  Parsing: $($File.Name)" -ForegroundColor DarkGray

    $content = Get-Content $File.FullName

    foreach ($line in $content) {
        if (-not $line -or $line.Trim() -eq "") { continue }

        $entry = if ($Format -eq "json" -or ($Format -eq "auto" -and $line -match '^\s*\{')) {
            Parse-JsonLog -Line $line
        } else {
            Parse-TextLog -Line $line
        }

        if ($entry) {
            $script:LogEntries += $entry
        }
    }
}

function Filter-ByTimeRange {
    param([array]$Entries, [string]$Range)

    $cutoff = switch ($Range) {
        "1h" { (Get-Date).AddHours(-1) }
        "24h" { (Get-Date).AddHours(-24) }
        "7d" { (Get-Date).AddDays(-7) }
        "30d" { (Get-Date).AddDays(-30) }
    }

    return $Entries | Where-Object { $_.Timestamp -ge $cutoff }
}

function Filter-ByLevel {
    param([array]$Entries, [string]$MinLevel)

    $levels = @("Trace", "Debug", "Information", "Warning", "Error", "Critical")
    $minIndex = [array]::IndexOf($levels, $MinLevel)

    if ($minIndex -eq -1) { return $Entries }

    return $Entries | Where-Object {
        $levelIndex = [array]::IndexOf($levels, $_.Level)
        $levelIndex -ge $minIndex
    }
}

function Group-ErrorPatterns {
    param([array]$Entries)

    $errors = $Entries | Where-Object { $_.Level -eq "Error" -or $_.Level -eq "Critical" }

    foreach ($error in $errors) {
        # Extract error pattern (first 100 chars without specific values)
        $pattern = $error.Message -replace '\d+', 'N' -replace '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 'GUID'
        $pattern = $pattern.Substring(0, [Math]::Min(100, $pattern.Length))

        if ($script:ErrorPatterns.ContainsKey($pattern)) {
            $script:ErrorPatterns[$pattern].Count++
            $script:ErrorPatterns[$pattern].LastSeen = $error.Timestamp
        } else {
            $script:ErrorPatterns[$pattern] = @{
                "Pattern" = $pattern
                "Count" = 1
                "FirstSeen" = $error.Timestamp
                "LastSeen" = $error.Timestamp
                "Example" = $error.Message
            }
        }
    }
}

function Show-Statistics {
    param([array]$Entries)

    Write-Host ""
    Write-Host "=== Log Statistics ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host ("Total Entries: {0}" -f $Entries.Count) -ForegroundColor White
    Write-Host ""

    # Group by level
    $byLevel = $Entries | Group-Object -Property Level

    Write-Host "By Level:" -ForegroundColor Yellow
    foreach ($group in $byLevel | Sort-Object Name) {
        $color = switch ($group.Name) {
            "Error" { "Red" }
            "Critical" { "Red" }
            "Warning" { "Yellow" }
            default { "White" }
        }

        Write-Host ("  {0,-15} {1,6}" -f $group.Name, $group.Count) -ForegroundColor $color
    }

    Write-Host ""

    # Time distribution
    $byHour = $Entries | Group-Object -Property { $_.Timestamp.Hour }

    Write-Host "Peak Hours:" -ForegroundColor Yellow
    $topHours = $byHour | Sort-Object Count -Descending | Select-Object -First 5

    foreach ($hour in $topHours) {
        Write-Host ("  {0,2}:00  {1} entries" -f $hour.Name, $hour.Count) -ForegroundColor White
    }

    Write-Host ""
}

function Show-TopErrors {
    param([int]$TopCount)

    if ($script:ErrorPatterns.Count -eq 0) {
        Write-Host "No errors found!" -ForegroundColor Green
        return
    }

    Write-Host "=== Top Error Patterns ===" -ForegroundColor Cyan
    Write-Host ""

    $sorted = $script:ErrorPatterns.Values | Sort-Object Count -Descending | Select-Object -First $TopCount

    foreach ($error in $sorted) {
        Write-Host ("Count: {0}" -f $error.Count) -ForegroundColor Red
        Write-Host ("Pattern: {0}" -f $error.Pattern) -ForegroundColor Yellow
        Write-Host ("Example: {0}" -f $error.Example.Substring(0, [Math]::Min(200, $error.Example.Length))) -ForegroundColor DarkGray
        Write-Host ("First Seen: {0}" -f $error.FirstSeen) -ForegroundColor DarkGray
        Write-Host ("Last Seen: {0}" -f $error.LastSeen) -ForegroundColor DarkGray
        Write-Host ""
    }
}

function Generate-HTMLReport {
    param([array]$Entries, [hashtable]$ErrorPatterns)

    $byLevel = $Entries | Group-Object -Property Level

    $levelStats = ""
    foreach ($group in $byLevel | Sort-Object Name) {
        $color = switch ($group.Name) {
            "Error" { "#f93e3e" }
            "Critical" { "#d32f2f" }
            "Warning" { "#fca130" }
            default { "#999" }
        }

        $levelStats += "<div class='stat-card'>`n"
        $levelStats += "  <div class='stat-value' style='color: $color;'>$($group.Count)</div>`n"
        $levelStats += "  <div class='stat-label'>$($group.Name)</div>`n"
        $levelStats += "</div>`n"
    }

    $errorTable = ""
    $sorted = $ErrorPatterns.Values | Sort-Object Count -Descending | Select-Object -First 20

    foreach ($error in $sorted) {
        $errorTable += "<tr>`n"
        $errorTable += "  <td>$($error.Count)</td>`n"
        $errorTable += "  <td>$($error.Pattern)</td>`n"
        $errorTable += "  <td>$($error.FirstSeen.ToString('yyyy-MM-dd HH:mm'))</td>`n"
        $errorTable += "  <td>$($error.LastSeen.ToString('yyyy-MM-dd HH:mm'))</td>`n"
        $errorTable += "</tr>`n"
    }

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Log Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
        h1 { color: #333; border-bottom: 3px solid #61dafb; padding-bottom: 10px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin: 20px 0; }
        .stat-card { background: #f8f9fa; padding: 15px; border-radius: 6px; text-align: center; }
        .stat-value { font-size: 2em; font-weight: bold; }
        .stat-label { color: #666; font-size: 0.9em; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #f8f9fa; padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6; }
        td { padding: 10px 12px; border-bottom: 1px solid #dee2e6; }
        tr:hover { background: #f8f9fa; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Log Analysis Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>Time Range: $TimeRange | Total Entries: $($Entries.Count)</p>

        <h2>Log Levels</h2>
        <div class="stats">
$levelStats
        </div>

        <h2>Top Error Patterns</h2>
        <table>
            <tr>
                <th>Count</th>
                <th>Pattern</th>
                <th>First Seen</th>
                <th>Last Seen</th>
            </tr>
$errorTable
        </table>
    </div>
</body>
</html>
"@

    $reportPath = "log-analysis-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').html"
    $html | Set-Content $reportPath -Encoding UTF8

    Write-Host ""
    Write-Host "HTML report generated: $reportPath" -ForegroundColor Green
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== Log Analyzer ===" -ForegroundColor Cyan
Write-Host ""

# Get log files
$logFiles = Get-LogFiles -Path $LogPath

if ($logFiles.Count -eq 0) {
    Write-Host "No log files found" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($logFiles.Count) log files" -ForegroundColor Green
Write-Host ""

# Parse log files
Write-Host "Parsing logs..." -ForegroundColor Cyan

foreach ($file in $logFiles | Select-Object -First 10) {
    Parse-LogFile -File $file -Format $LogFormat
}

Write-Host ""
Write-Host "Parsed $($script:LogEntries.Count) log entries" -ForegroundColor Green
Write-Host ""

# Filter entries
$filteredEntries = $script:LogEntries
$filteredEntries = Filter-ByTimeRange -Entries $filteredEntries -Range $TimeRange
$filteredEntries = Filter-ByLevel -Entries $filteredEntries -MinLevel $MinLevel

if ($Pattern) {
    $filteredEntries = $filteredEntries | Where-Object { $_.Message -match $Pattern }
}

Write-Host "After filtering: $($filteredEntries.Count) entries" -ForegroundColor White
Write-Host ""

# Analyze
Show-Statistics -Entries $filteredEntries
Group-ErrorPatterns -Entries $filteredEntries
Show-TopErrors -TopCount $Top

# Generate HTML report if requested
if ($OutputFormat -eq "html") {
    Generate-HTMLReport -Entries $filteredEntries -ErrorPatterns $script:ErrorPatterns
}

Write-Host "=== Analysis Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
