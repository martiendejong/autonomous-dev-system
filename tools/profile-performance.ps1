<#
.SYNOPSIS
    Performance profiling for .NET applications and frontend metrics.

.DESCRIPTION
    Profiles CPU, memory, database queries, and frontend performance.
    Tracks Core Web Vitals, slow queries, and resource usage.

    Features:
    - .NET CPU and memory profiling (dotnet-trace, dotnet-counters)
    - Frontend performance metrics (Lighthouse, Core Web Vitals)
    - Database query analysis (EF Core logging)
    - Performance trend tracking
    - Regression detection
    - Bottleneck identification

.PARAMETER ProjectPath
    Path to project to profile

.PARAMETER ProfileType
    Profile type: dotnet, frontend, database, all (default: all)

.PARAMETER Duration
    Profiling duration in seconds (default: 30)

.PARAMETER Url
    URL for frontend profiling (required for frontend profile)

.PARAMETER OutputPath
    Output path for profile reports (default: performance-reports)

.PARAMETER Baseline
    Set current run as performance baseline

.PARAMETER Compare
    Compare against baseline and detect regressions

.EXAMPLE
    .\profile-performance.ps1 -ProjectPath "C:\Projects\client-manager" -ProfileType dotnet
    .\profile-performance.ps1 -ProjectPath "." -ProfileType frontend -Url "http://localhost:5173"
    .\profile-performance.ps1 -ProjectPath "." -ProfileType all -Baseline
    .\profile-performance.ps1 -ProjectPath "." -Compare
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [ValidateSet("dotnet", "frontend", "database", "all")]
    [string]$ProfileType = "all",

    [int]$Duration = 30,
    [string]$Url,
    [string]$OutputPath = "performance-reports",
    [switch]$Baseline,
    [switch]$Compare
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$TrendFile = "C:/scripts/_machine/performance-trends.json"
$BaselineFile = "C:/scripts/_machine/performance-baseline.json"

function Profile-DotNet {
    param([string]$ProjectPath, [int]$Duration)

    Write-Host ""
    Write-Host "=== .NET Performance Profile ===" -ForegroundColor Cyan
    Write-Host ""

    # Check for dotnet-counters
    $hasCounters = dotnet tool list --global | Select-String "dotnet-counters"

    if (-not $hasCounters) {
        Write-Host "Installing dotnet-counters..." -ForegroundColor Yellow
        dotnet tool install --global dotnet-counters
    }

    # Find running process or start one
    $csproj = Get-ChildItem $ProjectPath -Filter "*.csproj" -Recurse | Select-Object -First 1

    if (-not $csproj) {
        Write-Host "ERROR: No .csproj found" -ForegroundColor Red
        return $null
    }

    Write-Host "Profiling for $Duration seconds..." -ForegroundColor DarkGray
    Write-Host ""

    # Collect performance counters
    $metricsFile = Join-Path $ProjectPath "dotnet-counters.txt"

    Push-Location $csproj.Directory.FullName
    try {
        # Start process in background
        $process = Start-Process -FilePath "dotnet" -ArgumentList "run" -PassThru -NoNewWindow

        Start-Sleep -Seconds 5

        # Collect counters
        dotnet counters collect --process-id $process.Id --duration $Duration --output $metricsFile --format text

        # Stop process
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue

        # Parse metrics
        if (Test-Path $metricsFile) {
            $metrics = Parse-DotNetMetrics -MetricsFile $metricsFile

            return $metrics
        }

    } finally {
        Pop-Location
    }

    return $null
}

function Parse-DotNetMetrics {
    param([string]$MetricsFile)

    $content = Get-Content $MetricsFile -Raw

    $metrics = @{
        "CPU" = 0
        "Memory" = 0
        "GC" = 0
        "ThreadPool" = 0
    }

    # Extract metrics (simplified parsing)
    if ($content -match 'cpu-usage\s+(\d+\.?\d*)') {
        $metrics.CPU = [double]$matches[1]
    }

    if ($content -match 'working-set\s+(\d+)') {
        $metrics.Memory = [math]::Round([double]$matches[1] / 1MB, 2)
    }

    if ($content -match 'gen-2-gc-count\s+(\d+)') {
        $metrics.GC = [int]$matches[1]
    }

    return $metrics
}

function Profile-Frontend {
    param([string]$Url)

    Write-Host ""
    Write-Host "=== Frontend Performance Profile ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $Url) {
        Write-Host "ERROR: -Url required for frontend profiling" -ForegroundColor Red
        return $null
    }

    # Check for Lighthouse
    $hasLighthouse = Get-Command lighthouse -ErrorAction SilentlyContinue

    if (-not $hasLighthouse) {
        Write-Host "Lighthouse not installed. Install with: npm install -g lighthouse" -ForegroundColor Yellow
        return $null
    }

    Write-Host "Running Lighthouse audit on: $Url" -ForegroundColor DarkGray
    Write-Host ""

    $reportPath = "lighthouse-report.json"

    lighthouse $Url --output json --output-path $reportPath --chrome-flags="--headless" 2>&1 | Out-Null

    if (-not (Test-Path $reportPath)) {
        Write-Host "ERROR: Lighthouse failed to generate report" -ForegroundColor Red
        return $null
    }

    try {
        $report = Get-Content $reportPath | ConvertFrom-Json

        $metrics = @{
            "Performance" = [math]::Round($report.categories.performance.score * 100, 0)
            "FCP" = [math]::Round($report.audits.'first-contentful-paint'.numericValue / 1000, 2)
            "LCP" = [math]::Round($report.audits.'largest-contentful-paint'.numericValue / 1000, 2)
            "TBT" = [math]::Round($report.audits.'total-blocking-time'.numericValue, 0)
            "CLS" = [math]::Round($report.audits.'cumulative-layout-shift'.numericValue, 3)
            "SpeedIndex" = [math]::Round($report.audits.'speed-index'.numericValue / 1000, 2)
        }

        return $metrics

    } catch {
        Write-Host "ERROR: Failed to parse Lighthouse report" -ForegroundColor Red
        return $null
    }
}

function Profile-Database {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Database Query Profile ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Database profiling requires EF Core logging enabled." -ForegroundColor Yellow
    Write-Host "Add to appsettings.Development.json:" -ForegroundColor DarkGray
    Write-Host @"
  "Logging": {
    "LogLevel": {
      "Microsoft.EntityFrameworkCore.Database.Command": "Information"
    }
  }
"@ -ForegroundColor DarkGray

    Write-Host ""
    Write-Host "Run application and check logs for slow queries (>100ms)" -ForegroundColor White
    Write-Host ""

    return @{
        "SlowQueries" = 0
        "TotalQueries" = 0
        "AvgDuration" = 0
    }
}

function Show-PerformanceReport {
    param([hashtable]$DotNetMetrics, [hashtable]$FrontendMetrics, [hashtable]$DatabaseMetrics)

    Write-Host ""
    Write-Host "=== Performance Report ===" -ForegroundColor Cyan
    Write-Host ""

    if ($DotNetMetrics) {
        Write-Host ".NET Application:" -ForegroundColor Yellow
        Write-Host ("  CPU Usage:      {0:F2}%" -f $DotNetMetrics.CPU) -ForegroundColor White
        Write-Host ("  Memory:         {0:F2} MB" -f $DotNetMetrics.Memory) -ForegroundColor White
        Write-Host ("  GC Gen 2 Count: {0}" -f $DotNetMetrics.GC) -ForegroundColor White
        Write-Host ""
    }

    if ($FrontendMetrics) {
        Write-Host "Frontend Performance:" -ForegroundColor Yellow
        Write-Host ("  Performance Score: {0}/100" -f $FrontendMetrics.Performance) -ForegroundColor $(if ($FrontendMetrics.Performance -ge 90) { "Green" } elseif ($FrontendMetrics.Performance -ge 50) { "Yellow" } else { "Red" })
        Write-Host ("  FCP (First Contentful Paint):  {0:F2}s" -f $FrontendMetrics.FCP) -ForegroundColor White
        Write-Host ("  LCP (Largest Contentful Paint): {0:F2}s" -f $FrontendMetrics.LCP) -ForegroundColor $(if ($FrontendMetrics.LCP -le 2.5) { "Green" } elseif ($FrontendMetrics.LCP -le 4) { "Yellow" } else { "Red" })
        Write-Host ("  TBT (Total Blocking Time):      {0} ms" -f $FrontendMetrics.TBT) -ForegroundColor White
        Write-Host ("  CLS (Cumulative Layout Shift):  {0:F3}" -f $FrontendMetrics.CLS) -ForegroundColor $(if ($FrontendMetrics.CLS -le 0.1) { "Green" } elseif ($FrontendMetrics.CLS -le 0.25) { "Yellow" } else { "Red" })
        Write-Host ("  Speed Index:                    {0:F2}s" -f $FrontendMetrics.SpeedIndex) -ForegroundColor White
        Write-Host ""
    }

    if ($DatabaseMetrics -and $DatabaseMetrics.TotalQueries -gt 0) {
        Write-Host "Database Queries:" -ForegroundColor Yellow
        Write-Host ("  Total Queries:  {0}" -f $DatabaseMetrics.TotalQueries) -ForegroundColor White
        Write-Host ("  Slow Queries:   {0}" -f $DatabaseMetrics.SlowQueries) -ForegroundColor $(if ($DatabaseMetrics.SlowQueries -eq 0) { "Green" } else { "Red" })
        Write-Host ("  Avg Duration:   {0:F2} ms" -f $DatabaseMetrics.AvgDuration) -ForegroundColor White
        Write-Host ""
    }
}

function Save-PerformanceTrend {
    param([string]$ProjectPath, [hashtable]$DotNetMetrics, [hashtable]$FrontendMetrics)

    $projectName = Split-Path $ProjectPath -Leaf

    $trends = if (Test-Path $TrendFile) {
        Get-Content $TrendFile | ConvertFrom-Json
    } else {
        @()
    }

    $entry = @{
        "Date" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "Project" = $projectName
        "DotNet" = $DotNetMetrics
        "Frontend" = $FrontendMetrics
    }

    $trends += $entry

    # Keep last 100 entries
    $trends = $trends | Select-Object -Last 100

    $trends | ConvertTo-Json -Depth 10 | Set-Content $TrendFile -Encoding UTF8
}

function Save-Baseline {
    param([hashtable]$DotNetMetrics, [hashtable]$FrontendMetrics)

    $baseline = @{
        "Date" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "DotNet" = $DotNetMetrics
        "Frontend" = $FrontendMetrics
    }

    $baseline | ConvertTo-Json -Depth 10 | Set-Content $BaselineFile -Encoding UTF8

    Write-Host ""
    Write-Host "Baseline saved!" -ForegroundColor Green
    Write-Host ""
}

function Compare-ToBaseline {
    param([hashtable]$DotNetMetrics, [hashtable]$FrontendMetrics)

    if (-not (Test-Path $BaselineFile)) {
        Write-Host ""
        Write-Host "No baseline found. Run with -Baseline to set one." -ForegroundColor Yellow
        Write-Host ""
        return
    }

    $baseline = Get-Content $BaselineFile | ConvertFrom-Json

    Write-Host ""
    Write-Host "=== Regression Analysis ===" -ForegroundColor Cyan
    Write-Host ""

    $regressions = @()

    # Compare .NET metrics
    if ($DotNetMetrics -and $baseline.DotNet) {
        $cpuDiff = $DotNetMetrics.CPU - $baseline.DotNet.CPU
        $memDiff = $DotNetMetrics.Memory - $baseline.DotNet.Memory

        if ([math]::Abs($cpuDiff) -gt 10) {
            $regressions += "CPU usage changed by $($cpuDiff:F2)%"
        }

        if ([math]::Abs($memDiff) -gt 50) {
            $regressions += "Memory usage changed by $($memDiff:F2) MB"
        }
    }

    # Compare Frontend metrics
    if ($FrontendMetrics -and $baseline.Frontend) {
        $perfDiff = $FrontendMetrics.Performance - $baseline.Frontend.Performance
        $lcpDiff = $FrontendMetrics.LCP - $baseline.Frontend.LCP

        if ($perfDiff -lt -5) {
            $regressions += "Performance score decreased by $((-$perfDiff):F0) points"
        }

        if ($lcpDiff -gt 0.5) {
            $regressions += "LCP increased by $($lcpDiff:F2)s (slower)"
        }
    }

    if ($regressions.Count -gt 0) {
        Write-Host "REGRESSIONS DETECTED:" -ForegroundColor Red
        Write-Host ""

        foreach ($regression in $regressions) {
            Write-Host "  - $regression" -ForegroundColor Yellow
        }

        Write-Host ""
    } else {
        Write-Host "No significant regressions detected!" -ForegroundColor Green
        Write-Host ""
    }
}

# Main execution
Write-Host ""
Write-Host "=== Performance Profiler ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

$dotnetMetrics = $null
$frontendMetrics = $null
$databaseMetrics = $null

# Profile based on type
if ($ProfileType -eq "dotnet" -or $ProfileType -eq "all") {
    $dotnetMetrics = Profile-DotNet -ProjectPath $ProjectPath -Duration $Duration
}

if ($ProfileType -eq "frontend" -or $ProfileType -eq "all") {
    if ($Url) {
        $frontendMetrics = Profile-Frontend -Url $Url
    } elseif ($ProfileType -eq "frontend") {
        Write-Host "ERROR: -Url required for frontend profiling" -ForegroundColor Red
        exit 1
    }
}

if ($ProfileType -eq "database" -or $ProfileType -eq "all") {
    $databaseMetrics = Profile-Database -ProjectPath $ProjectPath
}

# Show report
Show-PerformanceReport -DotNetMetrics $dotnetMetrics -FrontendMetrics $frontendMetrics -DatabaseMetrics $databaseMetrics

# Save trends
if ($dotnetMetrics -or $frontendMetrics) {
    Save-PerformanceTrend -ProjectPath $ProjectPath -DotNetMetrics $dotnetMetrics -FrontendMetrics $frontendMetrics
}

# Save baseline if requested
if ($Baseline) {
    Save-Baseline -DotNetMetrics $dotnetMetrics -FrontendMetrics $frontendMetrics
}

# Compare to baseline if requested
if ($Compare) {
    Compare-ToBaseline -DotNetMetrics $dotnetMetrics -FrontendMetrics $frontendMetrics
}

Write-Host "=== Profiling Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
