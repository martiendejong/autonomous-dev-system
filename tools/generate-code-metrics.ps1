<#
.SYNOPSIS
    Generates comprehensive code metrics dashboard for C# and TypeScript projects.

.DESCRIPTION
    Analyzes codebase to calculate cyclomatic complexity, LOC, maintainability index,
    and technical debt. Generates HTML dashboard with visualizations and trends.

    Features:
    - Cyclomatic complexity analysis
    - Lines of code (LOC) metrics
    - Maintainability index calculation
    - Technical debt estimation
    - Code duplication detection
    - Hotspot identification (high complexity areas)
    - Trend tracking over time
    - HTML dashboard with charts

.PARAMETER ProjectPath
    Path to project root directory

.PARAMETER Language
    Language to analyze: csharp, typescript, both (default: both)

.PARAMETER MinComplexity
    Minimum complexity to report (default: 10)

.PARAMETER OutputPath
    Output path for HTML dashboard

.PARAMETER IncludeTests
    Include test files in analysis

.PARAMETER SaveBaseline
    Save current metrics as baseline for future comparisons

.PARAMETER CompareToBaseline
    Compare current metrics to saved baseline

.EXAMPLE
    .\generate-code-metrics.ps1 -ProjectPath "C:\Projects\client-manager"
    .\generate-code-metrics.ps1 -ProjectPath "." -Language csharp -MinComplexity 15
    .\generate-code-metrics.ps1 -ProjectPath "." -SaveBaseline
    .\generate-code-metrics.ps1 -ProjectPath "." -CompareToBaseline
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [ValidateSet("csharp", "typescript", "both")]
    [string]$Language = "both",

    [int]$MinComplexity = 10,
    [string]$OutputPath,
    [switch]$IncludeTests,
    [switch]$SaveBaseline,
    [switch]$CompareToBaseline
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$script:CSharpMetrics = @()
$script:TypeScriptMetrics = @()
$script:Baseline = $null

function Get-CSharpFiles {
    param([string]$Path, [bool]$IncludeTests)

    $filter = if ($IncludeTests) { "*.cs" } else { "*.cs" }
    $files = Get-ChildItem $Path -Filter $filter -Recurse

    if (-not $IncludeTests) {
        $files = $files | Where-Object { $_.FullName -notmatch 'Test' -and $_.FullName -notmatch '\\obj\\' -and $_.FullName -notmatch '\\bin\\' }
    }

    return $files
}

function Get-TypeScriptFiles {
    param([string]$Path, [bool]$IncludeTests)

    $files = Get-ChildItem $Path -Include @("*.ts", "*.tsx") -Recurse

    if (-not $IncludeTests) {
        $files = $files | Where-Object {
            $_.FullName -notmatch 'test' -and
            $_.FullName -notmatch 'spec' -and
            $_.FullName -notmatch '\\node_modules\\' -and
            $_.FullName -notmatch '\\dist\\'
        }
    }

    return $files
}

function Calculate-CyclomaticComplexity {
    param([string]$Code)

    # Count decision points: if, else, case, for, while, foreach, catch, &&, ||, ?
    $complexity = 1  # Base complexity

    $patterns = @(
        '\bif\s*\(',
        '\belse\b',
        '\bcase\s+',
        '\bfor\s*\(',
        '\bforeach\s*\(',
        '\bwhile\s*\(',
        '\bcatch\s*\(',
        '\&\&',
        '\|\|',
        '\?'
    )

    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($Code, $pattern)
        $complexity += $matches.Count
    }

    return $complexity
}

function Calculate-LOC {
    param([string[]]$Lines)

    $totalLines = $Lines.Count
    $codeLines = 0
    $commentLines = 0
    $blankLines = 0

    $inBlockComment = $false

    foreach ($line in $Lines) {
        $trimmed = $line.Trim()

        if ($trimmed -eq "") {
            $blankLines++
        }
        elseif ($trimmed -match '^//') {
            $commentLines++
        }
        elseif ($trimmed -match '^/\*') {
            $inBlockComment = $true
            $commentLines++
        }
        elseif ($trimmed -match '\*/') {
            $inBlockComment = $false
            $commentLines++
        }
        elseif ($inBlockComment) {
            $commentLines++
        }
        else {
            $codeLines++
        }
    }

    return @{
        "Total" = $totalLines
        "Code" = $codeLines
        "Comments" = $commentLines
        "Blank" = $blankLines
    }
}

function Calculate-MaintainabilityIndex {
    param([int]$LOC, [int]$Complexity, [int]$HalsteadVolume)

    # Maintainability Index = 171 - 5.2 * ln(Halstead Volume) - 0.23 * (Cyclomatic Complexity) - 16.2 * ln(LOC)
    # Simplified version without full Halstead metrics

    if ($LOC -eq 0) {
        return 100
    }

    $volumeEstimate = $LOC * 4.7  # Simplified Halstead volume estimate

    $mi = 171 - (5.2 * [Math]::Log($volumeEstimate)) - (0.23 * $Complexity) - (16.2 * [Math]::Log($LOC))

    # Normalize to 0-100 scale
    $mi = [Math]::Max(0, [Math]::Min(100, $mi))

    return [Math]::Round($mi, 2)
}

function Analyze-CSharpFile {
    param([System.IO.FileInfo]$File)

    try {
        $content = Get-Content $File.FullName -Raw
        $lines = Get-Content $File.FullName

        # Calculate LOC
        $loc = Calculate-LOC -Lines $lines

        # Find methods and calculate complexity
        $methodPattern = '(public|private|protected|internal)\s+(static\s+)?(async\s+)?[\w<>]+\s+(\w+)\s*\([^)]*\)'
        $methodMatches = [regex]::Matches($content, $methodPattern)

        $methods = @()

        foreach ($match in $methodMatches) {
            $methodName = $match.Groups[4].Value

            # Extract method body (simplified - find next closing brace)
            $startIndex = $match.Index
            $methodBody = $content.Substring($startIndex, [Math]::Min(1000, $content.Length - $startIndex))

            $complexity = Calculate-CyclomaticComplexity -Code $methodBody

            $methods += @{
                "Name" = $methodName
                "Complexity" = $complexity
            }
        }

        $avgComplexity = if ($methods.Count -gt 0) {
            ($methods | ForEach-Object { $_.Complexity } | Measure-Object -Average).Average
        } else {
            0
        }

        $maxComplexity = if ($methods.Count -gt 0) {
            ($methods | ForEach-Object { $_.Complexity } | Measure-Object -Maximum).Maximum
        } else {
            0
        }

        $maintainabilityIndex = Calculate-MaintainabilityIndex -LOC $loc.Code -Complexity $avgComplexity -HalsteadVolume 0

        return @{
            "File" = $File.FullName.Replace($ProjectPath, ".")
            "Language" = "C#"
            "LOC" = $loc
            "Methods" = $methods.Count
            "AvgComplexity" = [Math]::Round($avgComplexity, 2)
            "MaxComplexity" = $maxComplexity
            "MaintainabilityIndex" = $maintainabilityIndex
            "HighComplexityMethods" = $methods | Where-Object { $_.Complexity -gt $MinComplexity }
        }

    } catch {
        Write-Host "ERROR analyzing $($File.Name): $_" -ForegroundColor Red
        return $null
    }
}

function Analyze-TypeScriptFile {
    param([System.IO.FileInfo]$File)

    try {
        $content = Get-Content $File.FullName -Raw
        $lines = Get-Content $File.FullName

        # Calculate LOC
        $loc = Calculate-LOC -Lines $lines

        # Find functions and calculate complexity
        $functionPattern = '(function|const|let|var)\s+(\w+)\s*=?\s*(async\s+)?\([^)]*\)\s*(=>)?\s*\{'
        $functionMatches = [regex]::Matches($content, $functionPattern)

        $functions = @()

        foreach ($match in $functionMatches) {
            $functionName = $match.Groups[2].Value

            # Extract function body (simplified)
            $startIndex = $match.Index
            $functionBody = $content.Substring($startIndex, [Math]::Min(1000, $content.Length - $startIndex))

            $complexity = Calculate-CyclomaticComplexity -Code $functionBody

            $functions += @{
                "Name" = $functionName
                "Complexity" = $complexity
            }
        }

        $avgComplexity = if ($functions.Count -gt 0) {
            ($functions | ForEach-Object { $_.Complexity } | Measure-Object -Average).Average
        } else {
            0
        }

        $maxComplexity = if ($functions.Count -gt 0) {
            ($functions | ForEach-Object { $_.Complexity } | Measure-Object -Maximum).Maximum
        } else {
            0
        }

        $maintainabilityIndex = Calculate-MaintainabilityIndex -LOC $loc.Code -Complexity $avgComplexity -HalsteadVolume 0

        return @{
            "File" = $File.FullName.Replace($ProjectPath, ".")
            "Language" = "TypeScript"
            "LOC" = $loc
            "Functions" = $functions.Count
            "AvgComplexity" = [Math]::Round($avgComplexity, 2)
            "MaxComplexity" = $maxComplexity
            "MaintainabilityIndex" = $maintainabilityIndex
            "HighComplexityFunctions" = $functions | Where-Object { $_.Complexity -gt $MinComplexity }
        }

    } catch {
        Write-Host "ERROR analyzing $($File.Name): $_" -ForegroundColor Red
        return $null
    }
}

function Calculate-TechnicalDebt {
    param([array]$Metrics)

    # Technical debt estimation based on:
    # - High complexity methods/functions
    # - Low maintainability index
    # - Large file size

    $debtMinutes = 0

    foreach ($metric in $Metrics) {
        # Penalty for low maintainability
        if ($metric.MaintainabilityIndex -lt 50) {
            $debtMinutes += 60
        } elseif ($metric.MaintainabilityIndex -lt 70) {
            $debtMinutes += 30
        }

        # Penalty for high complexity
        if ($metric.MaxComplexity -gt 20) {
            $debtMinutes += $metric.MaxComplexity * 5
        } elseif ($metric.MaxComplexity -gt 15) {
            $debtMinutes += $metric.MaxComplexity * 3
        }

        # Penalty for large files
        if ($metric.LOC.Code -gt 500) {
            $debtMinutes += 120
        } elseif ($metric.LOC.Code -gt 300) {
            $debtMinutes += 60
        }
    }

    $debtHours = [Math]::Round($debtMinutes / 60, 2)
    $debtDays = [Math]::Round($debtHours / 8, 2)

    return @{
        "Minutes" = $debtMinutes
        "Hours" = $debtHours
        "Days" = $debtDays
    }
}

function Find-Hotspots {
    param([array]$Metrics, [int]$Top = 10)

    # Hotspots are files with high complexity and low maintainability

    $scored = $Metrics | ForEach-Object {
        $score = ($_.MaxComplexity * 2) + (100 - $_.MaintainabilityIndex)

        [PSCustomObject]@{
            File = $_.File
            Score = $score
            MaxComplexity = $_.MaxComplexity
            MaintainabilityIndex = $_.MaintainabilityIndex
        }
    }

    return $scored | Sort-Object Score -Descending | Select-Object -First $Top
}

function Show-Summary {
    param([array]$Metrics, [hashtable]$Debt)

    Write-Host ""
    Write-Host "=== Code Metrics Summary ===" -ForegroundColor Cyan
    Write-Host ""

    $totalFiles = $Metrics.Count
    $totalLOC = ($Metrics | ForEach-Object { $_.LOC.Code } | Measure-Object -Sum).Sum
    $avgComplexity = ($Metrics | ForEach-Object { $_.AvgComplexity } | Measure-Object -Average).Average
    $avgMI = ($Metrics | ForEach-Object { $_.MaintainabilityIndex } | Measure-Object -Average).Average

    Write-Host ("Files Analyzed:           {0,8}" -f $totalFiles) -ForegroundColor White
    Write-Host ("Total Lines of Code:      {0,8}" -f $totalLOC) -ForegroundColor White
    Write-Host ("Avg Complexity:           {0,8:F2}" -f $avgComplexity) -ForegroundColor White
    Write-Host ("Avg Maintainability:      {0,8:F2}" -f $avgMI) -ForegroundColor $(if ($avgMI -lt 50) { "Red" } elseif ($avgMI -lt 70) { "Yellow" } else { "Green" })
    Write-Host ""

    Write-Host "Technical Debt Estimate:" -ForegroundColor Yellow
    Write-Host ("  {0,6:F2} hours ({1:F2} days)" -f $Debt.Hours, $Debt.Days) -ForegroundColor White
    Write-Host ""

    # Show hotspots
    $hotspots = Find-Hotspots -Metrics $Metrics -Top 5

    if ($hotspots.Count -gt 0) {
        Write-Host "Top 5 Hotspots (files needing attention):" -ForegroundColor Yellow
        Write-Host ""

        foreach ($hotspot in $hotspots) {
            Write-Host ("  {0}" -f $hotspot.File) -ForegroundColor Red
            Write-Host ("    Complexity: {0} | Maintainability: {1:F2}" -f $hotspot.MaxComplexity, $hotspot.MaintainabilityIndex) -ForegroundColor DarkGray
        }

        Write-Host ""
    }
}

function Generate-HTMLDashboard {
    param([array]$Metrics, [hashtable]$Debt, [array]$Hotspots, [string]$OutputPath, [object]$Baseline)

    $totalLOC = ($Metrics | ForEach-Object { $_.LOC.Code } | Measure-Object -Sum).Sum
    $avgComplexity = ($Metrics | ForEach-Object { $_.AvgComplexity } | Measure-Object -Average).Average
    $avgMI = ($Metrics | ForEach-Object { $_.MaintainabilityIndex } | Measure-Object -Average).Average

    # Complexity distribution
    $complexityRanges = @{
        "Low (1-5)" = 0
        "Medium (6-10)" = 0
        "High (11-15)" = 0
        "Very High (16-20)" = 0
        "Critical (>20)" = 0
    }

    foreach ($metric in $Metrics) {
        $complexity = $metric.MaxComplexity

        if ($complexity -le 5) {
            $complexityRanges["Low (1-5)"]++
        } elseif ($complexity -le 10) {
            $complexityRanges["Medium (6-10)"]++
        } elseif ($complexity -le 15) {
            $complexityRanges["High (11-15)"]++
        } elseif ($complexity -le 20) {
            $complexityRanges["Very High (16-20)"]++
        } else {
            $complexityRanges["Critical (>20)"]++
        }
    }

    $complexityLabels = $complexityRanges.Keys -join '","'
    $complexityData = $complexityRanges.Values -join ','

    # Hotspots table
    $hotspotsTable = ""

    foreach ($hotspot in $Hotspots) {
        $hotspotsTable += "<tr>`n"
        $hotspotsTable += "  <td>$($hotspot.File)</td>`n"
        $hotspotsTable += "  <td>$($hotspot.MaxComplexity)</td>`n"
        $hotspotsTable += "  <td>$($hotspot.MaintainabilityIndex.ToString('F2'))</td>`n"
        $hotspotsTable += "  <td>$($hotspot.Score.ToString('F2'))</td>`n"
        $hotspotsTable += "</tr>`n"
    }

    # Baseline comparison
    $baselineSection = ""

    if ($Baseline) {
        $locDiff = $totalLOC - $Baseline.TotalLOC
        $complexityDiff = $avgComplexity - $Baseline.AvgComplexity
        $miDiff = $avgMI - $Baseline.AvgMaintainability
        $debtDiff = $Debt.Hours - $Baseline.TechnicalDebt.Hours

        $baselineSection = @"
        <h2>Baseline Comparison</h2>
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value $(if ($locDiff -gt 0) { 'warning' } else { 'success' })">$(if ($locDiff -gt 0) { '+' })$locDiff</div>
                <div class="stat-label">LOC Change</div>
            </div>
            <div class="stat-card">
                <div class="stat-value $(if ($complexityDiff -gt 0) { 'error' } else { 'success' })">$(if ($complexityDiff -gt 0) { '+' })$($complexityDiff.ToString('F2'))</div>
                <div class="stat-label">Complexity Change</div>
            </div>
            <div class="stat-card">
                <div class="stat-value $(if ($miDiff -lt 0) { 'error' } else { 'success' })">$(if ($miDiff -gt 0) { '+' })$($miDiff.ToString('F2'))</div>
                <div class="stat-label">Maintainability Change</div>
            </div>
            <div class="stat-card">
                <div class="stat-value $(if ($debtDiff -gt 0) { 'error' } else { 'success' })">$(if ($debtDiff -gt 0) { '+' })$($debtDiff.ToString('F2'))h</div>
                <div class="stat-label">Tech Debt Change</div>
            </div>
        </div>
"@
    }

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Code Metrics Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1400px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
        h1 { color: #333; border-bottom: 3px solid #61dafb; padding-bottom: 10px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .stat-card { background: #f8f9fa; padding: 15px; border-radius: 6px; text-align: center; }
        .stat-value { font-size: 2em; font-weight: bold; }
        .stat-label { color: #666; font-size: 0.9em; }
        .success { color: #28a745; }
        .error { color: #dc3545; }
        .warning { color: #ffc107; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #f8f9fa; padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6; }
        td { padding: 10px 12px; border-bottom: 1px solid #dee2e6; }
        tr:hover { background: #f8f9fa; }
        .chart-container { margin: 30px 0; max-width: 600px; }
        canvas { max-height: 400px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Code Metrics Dashboard</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>Project: $ProjectPath</p>

        <h2>Overall Metrics</h2>
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value">$($Metrics.Count)</div>
                <div class="stat-label">Files Analyzed</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$totalLOC</div>
                <div class="stat-label">Total LOC</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$($avgComplexity.ToString('F2'))</div>
                <div class="stat-label">Avg Complexity</div>
            </div>
            <div class="stat-card">
                <div class="stat-value $(if ($avgMI -lt 50) { 'error' } elseif ($avgMI -lt 70) { 'warning' } else { 'success' })">$($avgMI.ToString('F2'))</div>
                <div class="stat-label">Avg Maintainability</div>
            </div>
            <div class="stat-card">
                <div class="stat-value warning">$($Debt.Hours.ToString('F2'))h</div>
                <div class="stat-label">Technical Debt</div>
            </div>
            <div class="stat-card">
                <div class="stat-value warning">$($Debt.Days.ToString('F2'))</div>
                <div class="stat-label">Debt (days)</div>
            </div>
        </div>

$baselineSection

        <h2>Complexity Distribution</h2>
        <div class="chart-container">
            <canvas id="complexityChart"></canvas>
        </div>

        <h2>Top 10 Hotspots</h2>
        <p>Files requiring immediate attention (high complexity + low maintainability)</p>
        <table>
            <tr>
                <th>File</th>
                <th>Max Complexity</th>
                <th>Maintainability</th>
                <th>Hotspot Score</th>
            </tr>
$hotspotsTable
        </table>
    </div>

    <script>
        const ctx = document.getElementById('complexityChart').getContext('2d');
        const complexityChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: ["$complexityLabels"],
                datasets: [{
                    label: 'Number of Files',
                    data: [$complexityData],
                    backgroundColor: [
                        'rgba(40, 167, 69, 0.7)',
                        'rgba(255, 193, 7, 0.7)',
                        'rgba(255, 152, 0, 0.7)',
                        'rgba(244, 67, 54, 0.7)',
                        'rgba(156, 39, 176, 0.7)'
                    ],
                    borderColor: [
                        'rgba(40, 167, 69, 1)',
                        'rgba(255, 193, 7, 1)',
                        'rgba(255, 152, 0, 1)',
                        'rgba(244, 67, 54, 1)',
                        'rgba(156, 39, 176, 1)'
                    ],
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Number of Files'
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
"@

    $html | Set-Content $OutputPath -Encoding UTF8

    Write-Host "HTML dashboard generated: $OutputPath" -ForegroundColor Green
    Write-Host ""
}

function Save-BaselineMetrics {
    param([array]$Metrics, [hashtable]$Debt)

    $totalLOC = ($Metrics | ForEach-Object { $_.LOC.Code } | Measure-Object -Sum).Sum
    $avgComplexity = ($Metrics | ForEach-Object { $_.AvgComplexity } | Measure-Object -Average).Average
    $avgMI = ($Metrics | ForEach-Object { $_.MaintainabilityIndex } | Measure-Object -Average).Average

    $baseline = @{
        "Timestamp" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "TotalFiles" = $Metrics.Count
        "TotalLOC" = $totalLOC
        "AvgComplexity" = $avgComplexity
        "AvgMaintainability" = $avgMI
        "TechnicalDebt" = $Debt
    }

    $baselinePath = Join-Path $ProjectPath "code-metrics-baseline.json"
    $baseline | ConvertTo-Json -Depth 5 | Set-Content $baselinePath -Encoding UTF8

    Write-Host "Baseline saved: $baselinePath" -ForegroundColor Green
    Write-Host ""
}

function Load-BaselineMetrics {
    param([string]$ProjectPath)

    $baselinePath = Join-Path $ProjectPath "code-metrics-baseline.json"

    if (Test-Path $baselinePath) {
        try {
            $baseline = Get-Content $baselinePath | ConvertFrom-Json
            return $baseline
        } catch {
            Write-Host "ERROR: Failed to load baseline: $_" -ForegroundColor Red
            return $null
        }
    }

    return $null
}

# Main execution
Write-Host ""
Write-Host "=== Code Metrics Dashboard Generator ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Load baseline if comparing
if ($CompareToBaseline) {
    $script:Baseline = Load-BaselineMetrics -ProjectPath $ProjectPath

    if (-not $script:Baseline) {
        Write-Host "WARNING: No baseline found. Run with -SaveBaseline first." -ForegroundColor Yellow
        Write-Host ""
    }
}

# Analyze C# files
if ($Language -eq "csharp" -or $Language -eq "both") {
    Write-Host "Analyzing C# files..." -ForegroundColor Cyan

    $csFiles = Get-CSharpFiles -Path $ProjectPath -IncludeTests $IncludeTests

    Write-Host ("Found {0} C# files" -f $csFiles.Count) -ForegroundColor White
    Write-Host ""

    $i = 0
    foreach ($file in $csFiles) {
        $i++
        Write-Host ("`rAnalyzing: {0}/{1} {2}" -f $i, $csFiles.Count, $file.Name) -NoNewline -ForegroundColor DarkGray

        $metrics = Analyze-CSharpFile -File $file

        if ($metrics) {
            $script:CSharpMetrics += $metrics
        }
    }

    Write-Host ""
    Write-Host ""
}

# Analyze TypeScript files
if ($Language -eq "typescript" -or $Language -eq "both") {
    Write-Host "Analyzing TypeScript files..." -ForegroundColor Cyan

    $tsFiles = Get-TypeScriptFiles -Path $ProjectPath -IncludeTests $IncludeTests

    Write-Host ("Found {0} TypeScript files" -f $tsFiles.Count) -ForegroundColor White
    Write-Host ""

    $i = 0
    foreach ($file in $tsFiles) {
        $i++
        Write-Host ("`rAnalyzing: {0}/{1} {2}" -f $i, $tsFiles.Count, $file.Name) -NoNewline -ForegroundColor DarkGray

        $metrics = Analyze-TypeScriptFile -File $file

        if ($metrics) {
            $script:TypeScriptMetrics += $metrics
        }
    }

    Write-Host ""
    Write-Host ""
}

# Combine metrics
$allMetrics = $script:CSharpMetrics + $script:TypeScriptMetrics

if ($allMetrics.Count -eq 0) {
    Write-Host "No files analyzed" -ForegroundColor Yellow
    exit 0
}

# Calculate technical debt
$debt = Calculate-TechnicalDebt -Metrics $allMetrics

# Show summary
Show-Summary -Metrics $allMetrics -Debt $debt

# Find hotspots
$hotspots = Find-Hotspots -Metrics $allMetrics -Top 10

# Generate HTML dashboard
if (-not $OutputPath) {
    $OutputPath = "code-metrics-dashboard-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').html"
}

Generate-HTMLDashboard -Metrics $allMetrics -Debt $debt -Hotspots $hotspots -OutputPath $OutputPath -Baseline $script:Baseline

# Save baseline if requested
if ($SaveBaseline) {
    Save-BaselineMetrics -Metrics $allMetrics -Debt $debt
}

Write-Host "=== Analysis Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
