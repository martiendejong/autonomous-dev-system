<#
.SYNOPSIS
    Enforce bundle size limits in CI and fail build if exceeded

.DESCRIPTION
    Prevents bundle size bloat by:
    - Measuring JavaScript bundle sizes
    - Comparing against budget thresholds
    - Failing CI if budget exceeded
    - Showing size breakdown by chunk

    Bundle size impacts:
    - Page load time
    - Mobile user experience
    - SEO rankings
    - Conversion rates

.PARAMETER BundlePath
    Path to build output directory

.PARAMETER Budget
    Maximum bundle size in KB (default: 250)

.PARAMETER FailOnExceed
    Fail build if budget exceeded (default: true)

.PARAMETER OutputFormat
    Output format: Table (default), JSON, GitHub

.EXAMPLE
    # Check bundle size against 250KB budget
    .\bundle-size-budget-enforcer.ps1

.EXAMPLE
    # Set 200KB budget and fail CI if exceeded
    .\bundle-size-budget-enforcer.ps1 -Budget 200 -FailOnExceed

.NOTES
    Value: 8/10 - Performance is critical for web apps
    Effort: 1.5/10 - File size calculation
    Ratio: 5.3 (TIER S)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BundlePath = "./build",

    [Parameter(Mandatory=$false)]
    [int]$Budget = 250,  # KB

    [Parameter(Mandatory=$false)]
    [bool]$FailOnExceed = $true,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'JSON', 'GitHub')]
    [string]$OutputFormat = 'Table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Bundle Size Budget Enforcer" -ForegroundColor Cyan
Write-Host "  Bundle path: $BundlePath" -ForegroundColor Gray
Write-Host "  Budget: $Budget KB" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $BundlePath)) {
    Write-Host "❌ Bundle path not found: $BundlePath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Build the project first:" -ForegroundColor Yellow
    Write-Host "  npm run build" -ForegroundColor Gray
    exit 1
}

# Find JavaScript bundles
$jsFiles = Get-ChildItem -Path $BundlePath -Filter "*.js" -Recurse |
    Where-Object { $_.Name -notmatch '\.map$' }  # Exclude source maps

if ($jsFiles.Count -eq 0) {
    Write-Host "⚠️  No JavaScript bundles found in $BundlePath" -ForegroundColor Yellow
    exit 1
}

Write-Host "Analyzing bundles..." -ForegroundColor Yellow
Write-Host ""

$bundles = @()
$totalSize = 0

foreach ($file in $jsFiles) {
    $sizeKB = [Math]::Round($file.Length / 1KB, 2)
    $totalSize += $sizeKB

    # Determine bundle type
    $type = if ($file.Name -match 'vendor|node_modules') { "Vendor" }
           elseif ($file.Name -match 'main|app|index') { "Main" }
           elseif ($file.Name -match 'chunk|lazy') { "Chunk" }
           else { "Other" }

    $bundles += [PSCustomObject]@{
        Name = $file.Name
        Size = $sizeKB
        Type = $type
        Path = $file.FullName.Replace($BundlePath, "").TrimStart('\', '/')
        Percentage = 0  # Calculate later
    }
}

# Calculate percentages
foreach ($bundle in $bundles) {
    $bundle.Percentage = [Math]::Round(($bundle.Size / $totalSize) * 100, 1)
}

# Sort by size (largest first)
$bundles = $bundles | Sort-Object Size -Descending

$budgetExceeded = $totalSize -gt $Budget
$percentOverBudget = [Math]::Round((($totalSize - $Budget) / $Budget) * 100, 1)

Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  BUNDLE SIZE ANALYSIS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

switch ($OutputFormat) {
    'Table' {
        $bundles | Format-Table -AutoSize -Property @(
            @{Label='Bundle'; Expression={$_.Name}; Width=40}
            @{Label='Type'; Expression={$_.Type}; Width=10}
            @{Label='Size (KB)'; Expression={$_.Size}; Align='Right'}
            @{Label='% of Total'; Expression={"$($_.Percentage)%"}; Align='Right'}
        )

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Total size: $totalSize KB" -ForegroundColor $(if ($budgetExceeded) { "Red" } else { "Green" })
        Write-Host "  Budget: $Budget KB" -ForegroundColor Gray
        Write-Host "  Bundles: $($bundles.Count)" -ForegroundColor Gray
        Write-Host ""

        if ($budgetExceeded) {
            Write-Host "❌ BUDGET EXCEEDED by $([Math]::Round($totalSize - $Budget, 2)) KB ($percentOverBudget%)" -ForegroundColor Red
            Write-Host ""
            Write-Host "OPTIMIZATION SUGGESTIONS:" -ForegroundColor Yellow
            Write-Host "  1. Code splitting - lazy load routes/components" -ForegroundColor Gray
            Write-Host "  2. Tree shaking - remove unused exports" -ForegroundColor Gray
            Write-Host "  3. Analyze with webpack-bundle-analyzer" -ForegroundColor Gray
            Write-Host "  4. Consider smaller alternatives for large dependencies" -ForegroundColor Gray
            Write-Host "  5. Enable compression (Gzip/Brotli)" -ForegroundColor Gray
            Write-Host ""

            # Show largest bundles
            Write-Host "LARGEST BUNDLES:" -ForegroundColor Red
            $bundles | Select-Object -First 5 | ForEach-Object {
                Write-Host "  $($_.Name) - $($_.Size) KB" -ForegroundColor Yellow
            }

            if ($FailOnExceed) {
                Write-Host ""
                Write-Host "⛔ BUILD FAILED - Bundle size exceeds budget" -ForegroundColor Red
                exit 1
            }
        } else {
            $remaining = $Budget - $totalSize
            Write-Host "✅ WITHIN BUDGET" -ForegroundColor Green
            Write-Host "  Remaining: $([Math]::Round($remaining, 2)) KB ($([Math]::Round(($remaining / $Budget) * 100, 1))%)" -ForegroundColor Gray
        }
    }
    'GitHub' {
        # GitHub Actions output format
        $status = if ($budgetExceeded) { "❌ EXCEEDED" } else { "✅ PASS" }

        Write-Host "::notice::Bundle Size: $totalSize KB / $Budget KB ($status)"

        if ($budgetExceeded) {
            Write-Host "::error::Bundle size exceeds budget by $([Math]::Round($totalSize - $Budget, 2)) KB"

            # Set output for PR comment
            $comment = @"
## 📦 Bundle Size Report

**Status:** ❌ Budget exceeded

| Metric | Value |
|--------|-------|
| Total Size | $totalSize KB |
| Budget | $Budget KB |
| Over Budget | $([Math]::Round($totalSize - $Budget, 2)) KB ($percentOverBudget%) |

### Largest Bundles

| Bundle | Size | % of Total |
|--------|------|------------|
$(($bundles | Select-Object -First 5 | ForEach-Object { "| $($_.Name) | $($_.Size) KB | $($_.Percentage)% |" }) -join "`n")

### Recommendations
- Enable code splitting for routes
- Lazy load heavy components
- Analyze with \`npm run analyze\`
- Consider smaller library alternatives
"@
            Write-Host "bundle-size-comment<<EOF" >> $env:GITHUB_OUTPUT
            Write-Host $comment >> $env:GITHUB_OUTPUT
            Write-Host "EOF" >> $env:GITHUB_OUTPUT

            if ($FailOnExceed) {
                exit 1
            }
        } else {
            Write-Host "::notice::Bundle size check passed ($totalSize KB / $Budget KB)"
        }
    }
    'JSON' {
        @{
            TotalSize = $totalSize
            Budget = $Budget
            BudgetExceeded = $budgetExceeded
            PercentOverBudget = $percentOverBudget
            Bundles = $bundles
        } | ConvertTo-Json -Depth 10
    }
}
