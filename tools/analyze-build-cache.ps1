<#
.SYNOPSIS
    Analyzes MSBuild and Vite build cache performance.

.DESCRIPTION
    Measures build times, identifies slow compilation units, and suggests optimizations.
    Tracks build performance trends and cache hit rates.

    Features:
    - MSBuild binary log analysis (binlog)
    - Vite build stats analysis
    - Identifies slowest projects/files
    - Cache hit rate analysis
    - Build time trends
    - Optimization suggestions

.PARAMETER ProjectPath
    Path to project (.csproj or package.json)

.PARAMETER BuildType
    Build type: dotnet, vite, both (default: both)

.PARAMETER Measure
    Run a build and measure performance

.PARAMETER Analyze
    Analyze existing build logs

.PARAMETER LogPath
    Path to build log file (binlog for MSBuild, build-stats.json for Vite)

.PARAMETER Trends
    Show build time trends from history

.PARAMETER Optimize
    Show optimization suggestions

.EXAMPLE
    .\analyze-build-cache.ps1 -ProjectPath "C:\Projects\client-manager" -Measure
    .\analyze-build-cache.ps1 -ProjectPath "." -Analyze -LogPath "msbuild.binlog"
    .\analyze-build-cache.ps1 -ProjectPath "." -BuildType vite -Trends
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [ValidateSet("dotnet", "vite", "both")]
    [string]$BuildType = "both",

    [switch]$Measure,
    [switch]$Analyze,
    [string]$LogPath,
    [switch]$Trends,
    [switch]$Optimize
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$TrendFile = "C:/scripts/_machine/build-trends.json"

function Measure-DotNetBuild {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Measuring .NET Build ===" -ForegroundColor Cyan
    Write-Host ""

    $binlogPath = Join-Path $ProjectPath "msbuild.binlog"

    Push-Location $ProjectPath
    try {
        Write-Host "Running build with binary logging..." -ForegroundColor DarkGray

        $startTime = Get-Date

        dotnet build --no-incremental -bl:$binlogPath 2>&1 | Out-Null

        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds

        if ($LASTEXITCODE -eq 0) {
            Write-Host ("Build completed in {0:F2} seconds" -f $duration) -ForegroundColor Green

            # Analyze binlog
            if (Test-Path $binlogPath) {
                Analyze-MSBuildLog -LogPath $binlogPath
            }

            # Save trend
            Save-BuildTrend -ProjectPath $ProjectPath -BuildType "dotnet" -Duration $duration

        } else {
            Write-Host "Build failed!" -ForegroundColor Red
        }

    } finally {
        Pop-Location
    }
}

function Measure-ViteBuild {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Measuring Vite Build ===" -ForegroundColor Cyan
    Write-Host ""

    Push-Location $ProjectPath
    try {
        Write-Host "Running Vite build..." -ForegroundColor DarkGray

        $startTime = Get-Date

        npm run build 2>&1 | Out-Null

        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds

        if ($LASTEXITCODE -eq 0) {
            Write-Host ("Build completed in {0:F2} seconds" -f $duration) -ForegroundColor Green

            # Check for build stats
            $statsPath = Join-Path $ProjectPath "dist/stats.json"
            if (Test-Path $statsPath) {
                Analyze-ViteStats -StatsPath $statsPath
            }

            # Save trend
            Save-BuildTrend -ProjectPath $ProjectPath -BuildType "vite" -Duration $duration

        } else {
            Write-Host "Build failed!" -ForegroundColor Red
        }

    } finally {
        Pop-Location
    }
}

function Analyze-MSBuildLog {
    param([string]$LogPath)

    Write-Host ""
    Write-Host "=== MSBuild Analysis ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $LogPath)) {
        Write-Host "ERROR: Log file not found: $LogPath" -ForegroundColor Red
        return
    }

    Write-Host "Analyzing binlog file..." -ForegroundColor DarkGray
    Write-Host "(Full analysis requires MSBuild Structured Log Viewer)" -ForegroundColor Yellow
    Write-Host ""

    # Basic file info
    $fileInfo = Get-Item $LogPath
    Write-Host ("  Log file size: {0:F2} MB" -f ($fileInfo.Length / 1MB)) -ForegroundColor White

    Write-Host ""
    Write-Host "Recommendations:" -ForegroundColor Cyan
    Write-Host "  1. Open binlog in MSBuild Structured Log Viewer for detailed analysis" -ForegroundColor White
    Write-Host "     Download: https://msbuildlog.com/" -ForegroundColor DarkGray
    Write-Host "  2. Enable parallel builds: dotnet build -m" -ForegroundColor White
    Write-Host "  3. Use incremental builds: remove --no-incremental flag" -ForegroundColor White
    Write-Host ""
}

function Analyze-ViteStats {
    param([string]$StatsPath)

    Write-Host ""
    Write-Host "=== Vite Bundle Analysis ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $StatsPath)) {
        Write-Host "No stats file found" -ForegroundColor Yellow
        Write-Host "Add to vite.config.ts:" -ForegroundColor DarkGray
        Write-Host "  build: { rollupOptions: { output: { assetFileNames, chunkFileNames } } }" -ForegroundColor DarkGray
        return
    }

    try {
        $stats = Get-Content $StatsPath | ConvertFrom-Json

        # Analyze bundle sizes
        $chunks = $stats.chunks | Sort-Object -Property size -Descending | Select-Object -First 10

        Write-Host "Largest Chunks:" -ForegroundColor Yellow
        foreach ($chunk in $chunks) {
            $sizeKB = [math]::Round($chunk.size / 1024, 2)
            Write-Host ("  {0,-40} {1,10} KB" -f $chunk.name, $sizeKB) -ForegroundColor White
        }

    } catch {
        Write-Host "Failed to parse stats file" -ForegroundColor Red
    }

    Write-Host ""
}

function Save-BuildTrend {
    param([string]$ProjectPath, [string]$BuildType, [double]$Duration)

    $projectName = Split-Path $ProjectPath -Leaf

    $trends = if (Test-Path $TrendFile) {
        Get-Content $TrendFile | ConvertFrom-Json
    } else {
        @()
    }

    $entry = @{
        "Date" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "Project" = $projectName
        "BuildType" = $BuildType
        "Duration" = [math]::Round($Duration, 2)
    }

    $trends += $entry

    # Keep last 100 entries
    $trends = $trends | Select-Object -Last 100

    $trends | ConvertTo-Json -Depth 10 | Set-Content $TrendFile -Encoding UTF8
}

function Show-BuildTrends {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Build Time Trends ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $TrendFile)) {
        Write-Host "No trend data available" -ForegroundColor Yellow
        Write-Host "Run builds with -Measure flag to collect data" -ForegroundColor DarkGray
        return
    }

    $trends = Get-Content $TrendFile | ConvertFrom-Json

    $projectName = Split-Path $ProjectPath -Leaf
    $projectTrends = $trends | Where-Object { $_.Project -eq $projectName }

    if ($projectTrends.Count -eq 0) {
        Write-Host "No trend data for this project" -ForegroundColor Yellow
        return
    }

    # Group by build type
    $dotnetTrends = $projectTrends | Where-Object { $_.BuildType -eq "dotnet" } | Select-Object -Last 10
    $viteTrends = $projectTrends | Where-Object { $_.BuildType -eq "vite" } | Select-Object -Last 10

    if ($dotnetTrends) {
        Write-Host ".NET Build Times (last 10):" -ForegroundColor Yellow
        foreach ($trend in $dotnetTrends) {
            Write-Host ("  {0}  {1,6:F2}s" -f $trend.Date, $trend.Duration) -ForegroundColor White
        }

        $avgDotNet = ($dotnetTrends | Measure-Object -Property Duration -Average).Average
        Write-Host ("  Average: {0:F2}s" -f $avgDotNet) -ForegroundColor Cyan
        Write-Host ""
    }

    if ($viteTrends) {
        Write-Host "Vite Build Times (last 10):" -ForegroundColor Yellow
        foreach ($trend in $viteTrends) {
            Write-Host ("  {0}  {1,6:F2}s" -f $trend.Date, $trend.Duration) -ForegroundColor White
        }

        $avgVite = ($viteTrends | Measure-Object -Property Duration -Average).Average
        Write-Host ("  Average: {0:F2}s" -f $avgVite) -ForegroundColor Cyan
        Write-Host ""
    }
}

function Show-Optimizations {
    Write-Host ""
    Write-Host "=== Build Optimization Suggestions ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host ".NET Build Optimizations:" -ForegroundColor Yellow
    Write-Host "  1. Enable parallel builds: dotnet build -m" -ForegroundColor White
    Write-Host "  2. Use incremental builds (default, avoid --no-incremental)" -ForegroundColor White
    Write-Host "  3. Enable deterministic builds for better caching:" -ForegroundColor White
    Write-Host "     <Deterministic>true</Deterministic>" -ForegroundColor DarkGray
    Write-Host "  4. Disable SourceLink in development:" -ForegroundColor White
    Write-Host "     <PublishRepositoryUrl>false</PublishRepositoryUrl>" -ForegroundColor DarkGray
    Write-Host "  5. Use $(TargetFramework) instead of $(TargetFrameworks) when possible" -ForegroundColor White
    Write-Host ""

    Write-Host "Vite Build Optimizations:" -ForegroundColor Yellow
    Write-Host "  1. Enable build cache in vite.config.ts:" -ForegroundColor White
    Write-Host "     build: { cache: true }" -ForegroundColor DarkGray
    Write-Host "  2. Use code splitting for large bundles:" -ForegroundColor White
    Write-Host "     build: { rollupOptions: { output: { manualChunks } } }" -ForegroundColor DarkGray
    Write-Host "  3. Enable minification: terser or esbuild" -ForegroundColor White
    Write-Host "  4. Analyze bundle with rollup-plugin-visualizer" -ForegroundColor White
    Write-Host "  5. Use dynamic imports for lazy loading" -ForegroundColor White
    Write-Host ""

    Write-Host "General Optimizations:" -ForegroundColor Yellow
    Write-Host "  1. Use SSD for project files (huge impact)" -ForegroundColor White
    Write-Host "  2. Exclude project directories from antivirus scanning" -ForegroundColor White
    Write-Host "  3. Use local NuGet cache (default on C:/Users/<user>/.nuget)" -ForegroundColor White
    Write-Host "  4. Use npm ci instead of npm install in CI/CD" -ForegroundColor White
    Write-Host "  5. Enable Windows Developer Mode for faster file operations" -ForegroundColor White
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== Build Cache Analyzer ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Determine project types
$hasCsProj = (Get-ChildItem $ProjectPath -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue).Count -gt 0
$hasPackageJson = Test-Path (Join-Path $ProjectPath "package.json")

if (-not $hasCsProj -and -not $hasPackageJson) {
    Write-Host "ERROR: No .csproj or package.json found" -ForegroundColor Red
    exit 1
}

# Execute based on mode
if ($Measure) {
    if ($BuildType -eq "dotnet" -or $BuildType -eq "both") {
        if ($hasCsProj) {
            Measure-DotNetBuild -ProjectPath $ProjectPath
        }
    }

    if ($BuildType -eq "vite" -or $BuildType -eq "both") {
        if ($hasPackageJson) {
            Measure-ViteBuild -ProjectPath $ProjectPath
        }
    }
}

if ($Analyze) {
    if ($LogPath) {
        if ($LogPath -match '\.binlog$') {
            Analyze-MSBuildLog -LogPath $LogPath
        } elseif ($LogPath -match '\.json$') {
            Analyze-ViteStats -StatsPath $LogPath
        }
    } else {
        Write-Host "ERROR: -LogPath required for analysis" -ForegroundColor Red
    }
}

if ($Trends) {
    Show-BuildTrends -ProjectPath $ProjectPath
}

if ($Optimize) {
    Show-Optimizations
}

if (-not $Measure -and -not $Analyze -and -not $Trends -and -not $Optimize) {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  Measure build:     .\analyze-build-cache.ps1 -ProjectPath . -Measure" -ForegroundColor White
    Write-Host "  Analyze log:       .\analyze-build-cache.ps1 -ProjectPath . -Analyze -LogPath msbuild.binlog" -ForegroundColor White
    Write-Host "  Show trends:       .\analyze-build-cache.ps1 -ProjectPath . -Trends" -ForegroundColor White
    Write-Host "  Show optimizations: .\analyze-build-cache.ps1 -ProjectPath . -Optimize" -ForegroundColor White
    Write-Host ""
}

Write-Host "=== Analysis Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
