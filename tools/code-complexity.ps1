<#
.SYNOPSIS
    Code Complexity Scorer
    50-Expert Council V2 Improvement #1 | Priority: 2.25

.DESCRIPTION
    Calculates cyclomatic and cognitive complexity before editing.
    Helps decide if code needs refactoring first.

.PARAMETER Analyze
    Analyze file or directory.

.PARAMETER Path
    Path to analyze.

.PARAMETER Threshold
    Complexity threshold for warnings (default: 10).

.PARAMETER Report
    Generate detailed report.

.EXAMPLE
    code-complexity.ps1 -Analyze -Path "src/services"
    code-complexity.ps1 -Analyze -Path "file.cs" -Threshold 15
#>

param(
    [switch]$Analyze,
    [string]$Path = ".",
    [int]$Threshold = 10,
    [switch]$Report,
    [switch]$Summary
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


function Analyze-CSharpFile {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return $null }

    $result = @{
        file = $FilePath
        lines = ($content -split "`n").Count
        methods = 0
        complexity = 0
        cognitiveComplexity = 0
        issues = @()
    }

    # Count decision points (simplified cyclomatic complexity)
    $decisions = @(
        'if\s*\(',
        'else\s*if',
        'switch\s*\(',
        'case\s+',
        'while\s*\(',
        'for\s*\(',
        'foreach\s*\(',
        '\?\?',
        '\?[^?]',
        '&&',
        '\|\|',
        'catch\s*\('
    )

    foreach ($pattern in $decisions) {
        $matches = [regex]::Matches($content, $pattern)
        $result.complexity += $matches.Count
    }

    # Count methods
    $methodPattern = '(public|private|protected|internal)\s+(static\s+)?(async\s+)?\w+\s+\w+\s*\('
    $result.methods = ([regex]::Matches($content, $methodPattern)).Count

    # Cognitive complexity (nesting depth matters)
    $nestingLevel = 0
    foreach ($line in $content -split "`n") {
        if ($line -match '\{') { $nestingLevel++ }
        if ($line -match '\}') { $nestingLevel-- }

        # Add to cognitive complexity based on nesting
        if ($line -match 'if|for|while|switch') {
            $result.cognitiveComplexity += (1 + $nestingLevel)
        }
    }

    # Check for issues
    if ($result.complexity -gt $Threshold) {
        $result.issues += "High cyclomatic complexity ($($result.complexity) > $Threshold)"
    }
    if ($result.cognitiveComplexity -gt ($Threshold * 2)) {
        $result.issues += "High cognitive complexity ($($result.cognitiveComplexity) > $($Threshold * 2))"
    }
    if ($result.lines -gt 500) {
        $result.issues += "Large file ($($result.lines) lines)"
    }
    if ($result.methods -gt 20) {
        $result.issues += "Too many methods ($($result.methods))"
    }

    return $result
}

function Analyze-TypeScriptFile {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return $null }

    $result = @{
        file = $FilePath
        lines = ($content -split "`n").Count
        functions = 0
        complexity = 0
        cognitiveComplexity = 0
        issues = @()
    }

    # Count decision points
    $decisions = @(
        'if\s*\(',
        'else\s*if',
        'switch\s*\(',
        'case\s+',
        'while\s*\(',
        'for\s*\(',
        '\?\?',
        '\?[^?:]',
        '&&',
        '\|\|',
        'catch\s*\(',
        '\.filter\(',
        '\.map\(',
        '\.reduce\('
    )

    foreach ($pattern in $decisions) {
        $matches = [regex]::Matches($content, $pattern)
        $result.complexity += $matches.Count
    }

    # Count functions
    $funcPattern = '(function\s+\w+|const\s+\w+\s*=\s*(async\s+)?\(|=>\s*\{)'
    $result.functions = ([regex]::Matches($content, $funcPattern)).Count

    # Cognitive complexity
    $nestingLevel = 0
    foreach ($line in $content -split "`n") {
        if ($line -match '\{') { $nestingLevel++ }
        if ($line -match '\}') { $nestingLevel-- }

        if ($line -match 'if|for|while|switch') {
            $result.cognitiveComplexity += (1 + $nestingLevel)
        }
    }

    # Issues
    if ($result.complexity -gt $Threshold) {
        $result.issues += "High cyclomatic complexity ($($result.complexity))"
    }
    if ($result.lines -gt 400) {
        $result.issues += "Large file ($($result.lines) lines)"
    }

    return $result
}

if ($Analyze) {
    Write-Host "=== CODE COMPLEXITY ANALYSIS ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Path: $Path" -ForegroundColor Yellow
    Write-Host "Threshold: $Threshold" -ForegroundColor Gray
    Write-Host ""

    $files = @()

    if (Test-Path $Path -PathType Leaf) {
        $files = @(Get-Item $Path)
    }
    else {
        $files = Get-ChildItem -Path $Path -Recurse -Include "*.cs", "*.ts", "*.tsx", "*.js" -ErrorAction SilentlyContinue |
                 Where-Object { $_.FullName -notmatch 'node_modules|bin|obj|dist' }
    }

    $results = @()
    $totalComplexity = 0
    $highComplexity = 0

    foreach ($file in $files) {
        $ext = $file.Extension

        $analysis = if ($ext -eq ".cs") {
            Analyze-CSharpFile $file.FullName
        }
        elseif ($ext -in ".ts", ".tsx", ".js") {
            Analyze-TypeScriptFile $file.FullName
        }

        if ($analysis) {
            $results += $analysis
            $totalComplexity += $analysis.complexity

            if ($analysis.complexity -gt $Threshold) {
                $highComplexity++
            }
        }
    }

    Write-Host "SUMMARY:" -ForegroundColor Magenta
    Write-Host "  Files analyzed: $($results.Count)" -ForegroundColor White
    Write-Host "  Total complexity: $totalComplexity" -ForegroundColor White
    Write-Host "  High complexity files: $highComplexity" -ForegroundColor $(if ($highComplexity -gt 0) { "Yellow" } else { "Green" })
    Write-Host ""

    if ($Report -or $highComplexity -gt 0) {
        Write-Host "FILES WITH ISSUES:" -ForegroundColor Yellow
        Write-Host ""

        $sorted = $results | Where-Object { $_.issues.Count -gt 0 } | Sort-Object { $_.complexity } -Descending

        foreach ($r in $sorted | Select-Object -First 20) {
            $color = if ($r.complexity -gt ($Threshold * 2)) { "Red" } elseif ($r.complexity -gt $Threshold) { "Yellow" } else { "White" }
            Write-Host "  $($r.file | Split-Path -Leaf)" -ForegroundColor $color
            Write-Host "    Complexity: $($r.complexity) | Cognitive: $($r.cognitiveComplexity) | Lines: $($r.lines)" -ForegroundColor Gray

            foreach ($issue in $r.issues) {
                Write-Host "    ⚠ $issue" -ForegroundColor Yellow
            }
            Write-Host ""
        }
    }

    if ($Summary) {
        # Top 10 most complex
        Write-Host "TOP 10 MOST COMPLEX:" -ForegroundColor Magenta
        $results | Sort-Object { $_.complexity } -Descending | Select-Object -First 10 | ForEach-Object {
            Write-Host "  [$($_.complexity)] $($_.file | Split-Path -Leaf)" -ForegroundColor White
        }
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Analyze -Path 'x'      Analyze path" -ForegroundColor White
    Write-Host "  -Threshold n            Set threshold (default: 10)" -ForegroundColor White
    Write-Host "  -Report                 Show detailed report" -ForegroundColor White
    Write-Host "  -Summary                Show top complex files" -ForegroundColor White
}
