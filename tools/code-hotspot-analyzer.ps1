<#
.SYNOPSIS
    Find code hotspots: files with high change frequency + high complexity = refactoring candidates

.DESCRIPTION
    Analyzes git history and code metrics to identify files that are:
    - Changed frequently (high churn)
    - Complex (high cyclomatic complexity, long files)
    - Likely to benefit from refactoring

    Uses git log to count commits per file and combines with code complexity metrics.

.PARAMETER ProjectPath
    Path to git repository (default: current directory)

.PARAMETER Since
    Analyze commits since this date (default: 3 months ago)

.PARAMETER MinCommits
    Minimum number of commits to be considered a hotspot (default: 10)

.PARAMETER TopN
    Number of top hotspots to display (default: 20)

.PARAMETER OutputFormat
    Output format: Table (default), JSON, CSV

.PARAMETER IncludeTests
    Include test files in analysis (default: false)

.PARAMETER FilePattern
    File pattern to analyze (default: *.cs for C#)

.EXAMPLE
    # Find top 20 C# hotspots in last 3 months
    .\code-hotspot-analyzer.ps1

.EXAMPLE
    # Find top 10 hotspots in last 6 months, include tests
    .\code-hotspot-analyzer.ps1 -Since "6 months ago" -TopN 10 -IncludeTests

.EXAMPLE
    # Analyze TypeScript files
    .\code-hotspot-analyzer.ps1 -FilePattern "*.ts,*.tsx"

.EXAMPLE
    # Export to CSV for further analysis
    .\code-hotspot-analyzer.ps1 -OutputFormat CSV > hotspots.csv

.NOTES
    Value: 9/10 - Identifies refactoring priorities
    Effort: 1/10 - Git log analysis + file metrics
    Ratio: 9.0 (TIER S)

    Based on: "Your Code as a Crime Scene" by Adam Tornhill
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [string]$Since = "3 months ago",

    [Parameter(Mandatory=$false)]
    [int]$MinCommits = 10,

    [Parameter(Mandatory=$false)]
    [int]$TopN = 20,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Table',

    [Parameter(Mandatory=$false)]
    [switch]$IncludeTests = $false,

    [Parameter(Mandatory=$false)]
    [string]$FilePattern = "*.cs"
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Push-Location $ProjectPath

try {
    # Verify git repository
    if (-not (Test-Path ".git")) {
        Write-Host "❌ Not a git repository: $ProjectPath" -ForegroundColor Red
        exit 1
    }

    Write-Host "🔍 Analyzing code hotspots in: $ProjectPath" -ForegroundColor Cyan
    Write-Host "   Since: $Since" -ForegroundColor Gray
    Write-Host "   File pattern: $FilePattern" -ForegroundColor Gray
    Write-Host ""

    # Get file change frequency from git log
    Write-Host "📊 Analyzing git history..." -ForegroundColor Yellow

    $patterns = $FilePattern -split ','
    $allChanges = @()

    foreach ($pattern in $patterns) {
        $pattern = $pattern.Trim()
        $gitLog = git log --since="$Since" --name-only --pretty=format: -- $pattern 2>$null
        if ($gitLog) {
            $allChanges += $gitLog -split "`n" | Where-Object { $_ -ne "" }
        }
    }

    if ($allChanges.Count -eq 0) {
        Write-Host "⚠️  No commits found matching pattern '$FilePattern' since $Since" -ForegroundColor Yellow
        exit 0
    }

    # Count commits per file
    $fileCommits = $allChanges | Group-Object | Select-Object @{Name='File';Expression={$_.Name}}, @{Name='Commits';Expression={$_.Count}} | Where-Object { $_.Commits -ge $MinCommits }

    # Filter out test files if requested
    if (-not $IncludeTests) {
        $fileCommits = $fileCommits | Where-Object { $_.File -notmatch 'test|spec|\.test\.|\.spec\.' -and $_.File -notmatch '\\tests\\|\\test\\' }
    }

    # Get file complexity metrics
    Write-Host "📏 Analyzing file complexity..." -ForegroundColor Yellow

    $hotspots = $fileCommits | ForEach-Object {
        $filePath = $_.File

        if (-not (Test-Path $filePath)) {
            # File may have been deleted/renamed
            return $null
        }

        $fileInfo = Get-Item $filePath
        $content = Get-Content $filePath -ErrorAction SilentlyContinue

        if (-not $content) {
            return $null
        }

        $lines = $content.Count
        $codeLines = ($content | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*//|^\s*/\*|\*/\s*$' }).Count

        # Simple complexity heuristic: count of if/for/while/switch/catch
        $complexityKeywords = $content | Select-String -Pattern '\b(if|for|while|switch|catch|foreach)\b' -AllMatches
        $cyclomaticComplexity = $complexityKeywords.Matches.Count

        # Calculate hotspot score (commits * complexity * size)
        $complexityScore = [Math]::Log($codeLines + 1) * $cyclomaticComplexity
        $hotspotScore = $_.Commits * $complexityScore

        [PSCustomObject]@{
            File = $filePath
            Commits = $_.Commits
            Lines = $lines
            CodeLines = $codeLines
            Complexity = $cyclomaticComplexity
            ComplexityScore = [Math]::Round($complexityScore, 2)
            HotspotScore = [Math]::Round($hotspotScore, 2)
            Category = Get-HotspotCategory -Commits $_.Commits -Complexity $cyclomaticComplexity -Lines $codeLines
        }
    } | Where-Object { $_ -ne $null } | Sort-Object HotspotScore -Descending | Select-Object -First $TopN

    # Output results
    Write-Host ""
    Write-Host "🔥 TOP $TopN CODE HOTSPOTS" -ForegroundColor Red
    Write-Host "   (High change frequency + High complexity = Refactoring priority)" -ForegroundColor Gray
    Write-Host ""

    switch ($OutputFormat) {
        'Table' {
            $hotspots | Format-Table -AutoSize -Property @(
                @{Label='File'; Expression={$_.File}; Width=50}
                @{Label='Commits'; Expression={$_.Commits}; Align='Right'}
                @{Label='Lines'; Expression={$_.Lines}; Align='Right'}
                @{Label='Complexity'; Expression={$_.Complexity}; Align='Right'}
                @{Label='Score'; Expression={$_.HotspotScore}; Align='Right'}
                @{Label='Category'; Expression={$_.Category}}
            )

            # Summary statistics
            Write-Host ""
            Write-Host "📈 Summary:" -ForegroundColor Cyan
            Write-Host "   Total hotspots: $($hotspots.Count)" -ForegroundColor Gray
            Write-Host "   Avg commits: $([Math]::Round(($hotspots | Measure-Object Commits -Average).Average, 1))" -ForegroundColor Gray
            Write-Host "   Avg complexity: $([Math]::Round(($hotspots | Measure-Object Complexity -Average).Average, 1))" -ForegroundColor Gray
            Write-Host ""
            Write-Host "💡 Recommendation:" -ForegroundColor Yellow
            Write-Host "   Focus refactoring on files with category 'CRITICAL' or 'HIGH'" -ForegroundColor Gray
        }
        'JSON' {
            $hotspots | ConvertTo-Json -Depth 10
        }
        'CSV' {
            $hotspots | ConvertTo-Csv -NoTypeInformation
        }
    }

} finally {
    Pop-Location
}

function Get-HotspotCategory {
    param(
        [int]$Commits,
        [int]$Complexity,
        [int]$Lines
    )

    # Categorize based on commits and complexity
    if ($Commits -gt 50 -and $Complexity -gt 100) {
        return "CRITICAL"
    } elseif ($Commits -gt 30 -and $Complexity -gt 50) {
        return "HIGH"
    } elseif ($Commits -gt 20 -or $Complexity -gt 30) {
        return "MEDIUM"
    } else {
        return "LOW"
    }
}
