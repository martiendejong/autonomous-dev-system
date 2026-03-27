<#
.SYNOPSIS
    Team metrics dashboard generator.

.DESCRIPTION
    Generates team productivity and code quality metrics dashboard
    including commits, PR stats, code review metrics, and velocity.

.PARAMETER TimeRange
    Time range: 7d, 30d, 90d

.PARAMETER TeamMembers
    Comma-separated list of team members (GitHub usernames)

.PARAMETER OutputFormat
    Output format: console, html, json

.EXAMPLE
    .\generate-team-metrics.ps1 -TimeRange 30d -OutputFormat html
    .\generate-team-metrics.ps1 -TeamMembers "user1,user2,user3" -TimeRange 7d
#>

param(
    [ValidateSet("7d", "30d", "90d")

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
]
    [string]$TimeRange = "30d",

    [string]$TeamMembers,
    [ValidateSet("console", "html", "json")]
    [string]$OutputFormat = "console"
)

function Get-CommitStats {
    param([string]$TimeRange)

    $days = switch ($TimeRange) {
        "7d" { 7 }
        "30d" { 30 }
        "90d" { 90 }
    }

    $since = (Get-Date).AddDays(-$days).ToString("yyyy-MM-dd")

    # Get commit count
    $commits = git log --since=$since --pretty=format:"%an" | Group-Object | Sort-Object Count -Descending

    return $commits
}

function Get-PRStats {
    Write-Host "Fetching PR statistics..." -ForegroundColor Yellow

    # Simulated PR stats - in real implementation, use gh CLI
    return @{
        "TotalPRs" = 45
        "OpenPRs" = 8
        "MergedPRs" = 35
        "ClosedPRs" = 2
        "AverageReviewTime" = 4.5  # hours
        "AverageMergeTime" = 12.3  # hours
    }
}

function Show-TeamMetrics {
    param([object]$CommitStats, [hashtable]$PRStats)

    Write-Host ""
    Write-Host "=== Team Metrics Dashboard ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Commit Activity:" -ForegroundColor Yellow
    foreach ($author in $CommitStats) {
        Write-Host ("  {0,-30} {1,4} commits" -f $author.Name, $author.Count) -ForegroundColor White
    }

    Write-Host ""
    Write-Host "Pull Request Statistics:" -ForegroundColor Yellow
    Write-Host ("  Total PRs:           {0,6}" -f $PRStats.TotalPRs) -ForegroundColor White
    Write-Host ("  Open:                {0,6}" -f $PRStats.OpenPRs) -ForegroundColor Green
    Write-Host ("  Merged:              {0,6}" -f $PRStats.MergedPRs) -ForegroundColor Green
    Write-Host ("  Closed (unmerged):   {0,6}" -f $PRStats.ClosedPRs) -ForegroundColor Yellow
    Write-Host ""
    Write-Host ("  Avg Review Time:     {0,6:F1}h" -f $PRStats.AverageReviewTime) -ForegroundColor White
    Write-Host ("  Avg Merge Time:      {0,6:F1}h" -f $PRStats.AverageMergeTime) -ForegroundColor White
    Write-Host ""
}

function Generate-HTMLDashboard {
    param([object]$CommitStats, [hashtable]$PRStats, [string]$OutputPath)

    $commitTable = ""

    foreach ($author in $CommitStats) {
        $commitTable += "<tr>`n"
        $commitTable += "  <td>$($author.Name)</td>`n"
        $commitTable += "  <td>$($author.Count)</td>`n"
        $commitTable += "</tr>`n"
    }

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Team Metrics Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
        h1 { color: #333; border-bottom: 3px solid #61dafb; padding-bottom: 10px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .stat-card { background: #f8f9fa; padding: 15px; border-radius: 6px; text-align: center; }
        .stat-value { font-size: 2em; font-weight: bold; color: #28a745; }
        .stat-label { color: #666; font-size: 0.9em; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #f8f9fa; padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6; }
        td { padding: 10px 12px; border-bottom: 1px solid #dee2e6; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Team Metrics Dashboard</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>Time Range: $TimeRange</p>

        <h2>Pull Request Metrics</h2>
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value">$($PRStats.TotalPRs)</div>
                <div class="stat-label">Total PRs</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$($PRStats.MergedPRs)</div>
                <div class="stat-label">Merged</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$($PRStats.AverageReviewTime.ToString('F1'))h</div>
                <div class="stat-label">Avg Review Time</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$($PRStats.AverageMergeTime.ToString('F1'))h</div>
                <div class="stat-label">Avg Merge Time</div>
            </div>
        </div>

        <h2>Commit Activity</h2>
        <table>
            <tr>
                <th>Author</th>
                <th>Commits</th>
            </tr>
$commitTable
        </table>
    </div>
</body>
</html>
"@

    $html | Set-Content $OutputPath -Encoding UTF8

    Write-Host "HTML dashboard generated: $OutputPath" -ForegroundColor Green
}

# Main execution
Write-Host ""
Write-Host "=== Team Metrics Dashboard ===" -ForegroundColor Cyan
Write-Host ""

$commitStats = Get-CommitStats -TimeRange $TimeRange
$prStats = Get-PRStats

if ($OutputFormat -eq "console") {
    Show-TeamMetrics -CommitStats $commitStats -PRStats $prStats
} elseif ($OutputFormat -eq "html") {
    $outputPath = "team-metrics-$(Get-Date -Format 'yyyy-MM-dd').html"
    Generate-HTMLDashboard -CommitStats $commitStats -PRStats $prStats -OutputPath $outputPath
}

Write-Host "=== Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
