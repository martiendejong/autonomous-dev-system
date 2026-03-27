<#
.SYNOPSIS
    Generates test coverage reports for C# and TypeScript projects.

.DESCRIPTION
    Runs test coverage analysis for .NET and frontend projects.
    Generates HTML reports, tracks trends, and enforces coverage thresholds.

    Supports:
    - C# projects (dotnet test with coverlet)
    - TypeScript/React (vitest or jest with coverage)
    - Trend tracking over time
    - CI/CD integration

.PARAMETER ProjectPath
    Path to project to test (should contain .csproj or package.json)

.PARAMETER Threshold
    Minimum coverage percentage required (default: 80)

.PARAMETER FailOnLowCoverage
    Exit with error code if coverage below threshold

.PARAMETER OutputPath
    Path for coverage report output (default: coverage-report.html)

.PARAMETER TrackTrend
    Save coverage data for trend analysis

.EXAMPLE
    .\test-coverage-report.ps1 -ProjectPath "C:\Projects\hazina"
    .\test-coverage-report.ps1 -ProjectPath "C:\Projects\client-manager\ClientManagerFrontend" -Threshold 85
    .\test-coverage-report.ps1 -ProjectPath "." -FailOnLowCoverage -TrackTrend
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [int]$Threshold = 80,
    [switch]$FailOnLowCoverage,
    [string]$OutputPath = "coverage-report.html",
    [switch]$TrackTrend
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Test-IsDotNetProject {
    param([string]$Path)
    return (Get-ChildItem $Path -Filter "*.csproj" -ErrorAction SilentlyContinue).Count -gt 0
}

function Test-IsFrontendProject {
    param([string]$Path)
    return Test-Path (Join-Path $Path "package.json")
}

function Run-DotNetCoverage {
    param([string]$Path, [int]$MinCoverage)

    Write-Host "Running .NET test coverage..." -ForegroundColor Cyan

    Push-Location $Path
    try {
        # Check if coverlet is installed
        $hasCoverlet = dotnet tool list | Select-String "coverlet"

        if (-not $hasCoverlet) {
            Write-Host "Installing coverlet.console..." -ForegroundColor Yellow
            dotnet tool install --global coverlet.console
        }

        # Run tests with coverage
        $output = dotnet test --collect:"XPlat Code Coverage" --results-directory:./TestResults 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "Tests failed!" -ForegroundColor Red
            return $null
        }

        # Find coverage file
        $coverageFile = Get-ChildItem ./TestResults -Filter "coverage.cobertura.xml" -Recurse | Select-Object -First 1

        if (-not $coverageFile) {
            Write-Host "WARNING: No coverage file found" -ForegroundColor Yellow
            return $null
        }

        # Parse coverage XML
        [xml]$coverageXml = Get-Content $coverageFile.FullName

        $lineCoverage = [math]::Round([double]$coverageXml.coverage."line-rate" * 100, 2)
        $branchCoverage = [math]::Round([double]$coverageXml.coverage."branch-rate" * 100, 2)

        return @{
            "LineCoverage" = $lineCoverage
            "BranchCoverage" = $branchCoverage
            "ReportPath" = $coverageFile.FullName
        }

    } finally {
        Pop-Location
    }
}

function Run-FrontendCoverage {
    param([string]$Path, [int]$MinCoverage)

    Write-Host "Running frontend test coverage..." -ForegroundColor Cyan

    Push-Location $Path
    try {
        $packageJson = Get-Content "package.json" | ConvertFrom-Json

        # Check if coverage script exists
        $hasCoverageScript = $packageJson.scripts.PSObject.Properties.Name -contains "test:coverage"

        if (-not $hasCoverageScript) {
            Write-Host "WARNING: No test:coverage script in package.json" -ForegroundColor Yellow
            Write-Host "Add: `"test:coverage`": `"vitest run --coverage`"" -ForegroundColor Yellow
            return $null
        }

        # Run coverage
        $output = npm run test:coverage 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "Tests failed!" -ForegroundColor Red
            return $null
        }

        # Parse coverage summary (from vitest or jest)
        $coverageSummary = Join-Path $Path "coverage/coverage-summary.json"

        if (-not (Test-Path $coverageSummary)) {
            Write-Host "WARNING: No coverage summary found" -ForegroundColor Yellow
            return $null
        }

        $summary = Get-Content $coverageSummary | ConvertFrom-Json
        $total = $summary.total

        return @{
            "LineCoverage" = $total.lines.pct
            "BranchCoverage" = $total.branches.pct
            "FunctionCoverage" = $total.functions.pct
            "StatementCoverage" = $total.statements.pct
            "ReportPath" = (Join-Path $Path "coverage/index.html")
        }

    } finally {
        Pop-Location
    }
}

function Save-CoverageTrend {
    param([hashtable]$Coverage, [string]$Project)

    $trendFile = "C:\scripts\_machine\coverage-trends.json"

    $trends = if (Test-Path $trendFile) {
        Get-Content $trendFile | ConvertFrom-Json
    } else {
        @()
    }

    $entry = @{
        "Date" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "Project" = $Project
        "LineCoverage" = $Coverage.LineCoverage
        "BranchCoverage" = $Coverage.BranchCoverage
    }

    $trends += $entry

    # Keep last 100 entries
    $trends = $trends | Select-Object -Last 100

    $trends | ConvertTo-Json -Depth 10 | Set-Content $trendFile -Encoding UTF8
}

function Show-CoverageReport {
    param([hashtable]$Coverage, [int]$MinThreshold)

    Write-Host ""
    Write-Host "=== Coverage Report ===" -ForegroundColor Cyan
    Write-Host ""

    $lineColor = if ($Coverage.LineCoverage -ge $MinThreshold) { "Green" } else { "Red" }
    $branchColor = if ($Coverage.BranchCoverage -ge $MinThreshold) { "Green" } else { "Red" }

    Write-Host ("  Line Coverage:   {0,6:F2}%" -f $Coverage.LineCoverage) -ForegroundColor $lineColor
    Write-Host ("  Branch Coverage: {0,6:F2}%" -f $Coverage.BranchCoverage) -ForegroundColor $branchColor

    if ($Coverage.ContainsKey("FunctionCoverage")) {
        Write-Host ("  Function Coverage: {0,6:F2}%" -f $Coverage.FunctionCoverage) -ForegroundColor White
    }

    if ($Coverage.ContainsKey("StatementCoverage")) {
        Write-Host ("  Statement Coverage: {0,6:F2}%" -f $Coverage.StatementCoverage) -ForegroundColor White
    }

    Write-Host ""
    Write-Host ("  Threshold: {0}%" -f $MinThreshold) -ForegroundColor DarkGray

    if ($Coverage.LineCoverage -lt $MinThreshold) {
        $diff = $MinThreshold - $Coverage.LineCoverage
        Write-Host ("  Below threshold by: {0:F2}%" -f $diff) -ForegroundColor Red
    } else {
        $diff = $Coverage.LineCoverage - $MinThreshold
        Write-Host ("  Above threshold by: {0:F2}%" -f $diff) -ForegroundColor Green
    }

    Write-Host ""

    if ($Coverage.ReportPath) {
        Write-Host "  Report: $($Coverage.ReportPath)" -ForegroundColor Cyan
    }

    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== Test Coverage Reporter ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

Write-Host "Project: $ProjectPath" -ForegroundColor White
Write-Host "Threshold: $Threshold%" -ForegroundColor White
Write-Host ""

# Determine project type and run coverage
$coverage = $null

if (Test-IsDotNetProject -Path $ProjectPath) {
    Write-Host "Detected: .NET project" -ForegroundColor DarkGray
    $coverage = Run-DotNetCoverage -Path $ProjectPath -MinCoverage $Threshold
}
elseif (Test-IsFrontendProject -Path $ProjectPath) {
    Write-Host "Detected: Frontend project" -ForegroundColor DarkGray
    $coverage = Run-FrontendCoverage -Path $ProjectPath -MinCoverage $Threshold
}
else {
    Write-Host "ERROR: Unknown project type (no .csproj or package.json found)" -ForegroundColor Red
    exit 1
}

if (-not $coverage) {
    Write-Host "ERROR: Failed to generate coverage report" -ForegroundColor Red
    exit 1
}

# Show report
Show-CoverageReport -Coverage $coverage -MinThreshold $Threshold

# Track trend if requested
if ($TrackTrend) {
    $projectName = Split-Path $ProjectPath -Leaf
    Save-CoverageTrend -Coverage $coverage -Project $projectName
    Write-Host "Coverage trend saved" -ForegroundColor Green
    Write-Host ""
}

# Fail if below threshold
if ($FailOnLowCoverage -and $coverage.LineCoverage -lt $Threshold) {
    Write-Host "FAILED: Coverage below threshold!" -ForegroundColor Red
    exit 1
}

Write-Host "=== Coverage Check Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
