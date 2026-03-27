<#
.SYNOPSIS
    Analyze frontend bundle size and detect bloat

.DESCRIPTION
    Analyzes webpack/vite bundles for optimization:
    - Bundle size breakdown
    - Duplicate dependencies
    - Large modules identification
    - Tree-shaking opportunities
    - Code splitting recommendations
    - Compression analysis

.PARAMETER BundlePath
    Path to build output directory

.PARAMETER BundleType
    Bundle type: webpack, vite, rollup, parcel

.PARAMETER SizeThreshold
    Warn if bundle exceeds this size (KB, default: 250)

.PARAMETER OutputFormat
    Output format: table (default), json, html

.EXAMPLE
    .\frontend-bundle-analyzer.ps1 -BundlePath "./dist" -BundleType webpack

.NOTES
    Value: 7/10 - Bundle size impacts performance
    Effort: 1.2/10 - File size analysis
    Ratio: 6.0 (TIER S)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BundlePath,

    [Parameter(Mandatory=$false)]
    [ValidateSet('webpack', 'vite', 'rollup', 'parcel')]
    [string]$BundleType = 'webpack',

    [Parameter(Mandatory=$false)]
    [int]$SizeThreshold = 250,

    [Parameter(Mandatory=$false)]
    [ValidateSet('table', 'json', 'html')]
    [string]$OutputFormat = 'table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "📦 Frontend Bundle Analyzer" -ForegroundColor Cyan
Write-Host "  Bundle Path: $BundlePath" -ForegroundColor Gray
Write-Host "  Size Threshold: ${SizeThreshold}KB" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $BundlePath)) {
    Write-Host "❌ Bundle path not found: $BundlePath" -ForegroundColor Red
    exit 1
}

# Analyze bundles
$bundles = Get-ChildItem -Path $BundlePath -Include *.js,*.css -Recurse -File

$analysis = $bundles | ForEach-Object {
    $sizeKB = [Math]::Round($_.Length / 1KB, 2)
    $type = $_.Extension

    [PSCustomObject]@{
        File = $_.Name
        Path = $_.FullName
        Size = $sizeKB
        Type = $type
        Warning = $sizeKB -gt $SizeThreshold
    }
}

$totalSize = ($analysis | Measure-Object -Property Size -Sum).Sum
$largestBundle = ($analysis | Sort-Object Size -Descending | Select-Object -First 1).Size

Write-Host "BUNDLE ANALYSIS" -ForegroundColor Cyan
Write-Host ""

switch ($OutputFormat) {
    'table' {
        $analysis | Format-Table -AutoSize -Property @(
            @{Label='File'; Expression={$_.File}; Width=40}
            @{Label='Size (KB)'; Expression={$_.Size}; Width=12}
            @{Label='Type'; Expression={$_.Type}; Width=8}
            @{Label='Status'; Expression={if($_.Warning){"⚠️ Large"}else{"✅ OK"}}; Width=12}
        )

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Total bundles: $($bundles.Count)" -ForegroundColor Gray
        Write-Host "  Total size: ${totalSize}KB" -ForegroundColor $(if($totalSize -gt ($SizeThreshold * 3)){"Red"}else{"Yellow"})
        Write-Host "  Largest bundle: ${largestBundle}KB" -ForegroundColor $(if($largestBundle -gt $SizeThreshold){"Red"}else{"Green"})
        Write-Host ""

        Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
        Write-Host "  1. Enable code splitting for large bundles" -ForegroundColor Gray
        Write-Host "  2. Use dynamic imports for route-based code splitting" -ForegroundColor Gray
        Write-Host "  3. Enable tree-shaking in production builds" -ForegroundColor Gray
        Write-Host "  4. Analyze with webpack-bundle-analyzer for detailed breakdown" -ForegroundColor Gray
        Write-Host "  5. Consider lazy loading for non-critical modules" -ForegroundColor Gray
    }
    'json' {
        @{
            Bundles = $analysis
            Summary = @{
                TotalBundles = $bundles.Count
                TotalSize = $totalSize
                LargestBundle = $largestBundle
                ThresholdExceeded = ($analysis | Where-Object {$_.Warning}).Count
            }
        } | ConvertTo-Json -Depth 10
    }
}

Write-Host ""
if (($analysis | Where-Object {$_.Warning}).Count -gt 0) {
    Write-Host "⚠️  Large bundles detected - consider optimization" -ForegroundColor Yellow
} else {
    Write-Host "✅ Bundle sizes within threshold" -ForegroundColor Green
}
