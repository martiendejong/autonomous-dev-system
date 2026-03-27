<#
.SYNOPSIS
    Test Gap Analyzer
    50-Expert Council V2 Improvement #8 | Priority: 1.8

.DESCRIPTION
    Identifies untested critical paths.

.PARAMETER Analyze
    Analyze test coverage gaps.

.PARAMETER Path
    Path to analyze.

.EXAMPLE
    test-gaps.ps1 -Analyze -Path "src/"
#>

param(
    [switch]$Analyze,
    [string]$Path = ".",
    [string]$TestPath = ""
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


if ($Analyze) {
    Write-Host "=== TEST GAP ANALYZER ===" -ForegroundColor Cyan
    Write-Host ""

    # Find source files
    $srcFiles = Get-ChildItem -Path $Path -Recurse -Include "*.cs", "*.ts", "*.tsx" -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch 'node_modules|bin|obj|dist|\.test\.|\.spec\.|Tests' }

    # Find test files
    $testPattern = if ($TestPath) { $TestPath } else { $Path }
    $testFiles = Get-ChildItem -Path $testPattern -Recurse -Include "*.test.ts", "*.spec.ts", "*Tests.cs", "*Test.cs" -ErrorAction SilentlyContinue

    $gaps = @()
    $tested = @()

    foreach ($src in $srcFiles) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($src.Name)

        # Check if corresponding test exists
        $hasTest = $testFiles | Where-Object {
            $testBase = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            $testBase -match [regex]::Escape($baseName)
        }

        if ($hasTest) {
            $tested += $src.Name
        }
        else {
            # Analyze file to determine criticality
            $content = Get-Content $src.FullName -Raw -ErrorAction SilentlyContinue
            $criticality = "low"

            if ($content -match 'Controller|Service|Repository|Handler') {
                $criticality = "high"
            }
            elseif ($content -match 'public\s+class|export\s+(default\s+)?class') {
                $criticality = "medium"
            }

            $gaps += @{
                file = $src.Name
                path = $src.FullName
                criticality = $criticality
            }
        }
    }

    # Calculate coverage
    $total = $srcFiles.Count
    $testedCount = $tested.Count
    $coverage = if ($total -gt 0) { [Math]::Round(($testedCount / $total) * 100) } else { 0 }

    Write-Host "TEST COVERAGE ANALYSIS" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Source files: $total" -ForegroundColor White
    Write-Host "  Files with tests: $testedCount" -ForegroundColor Green
    Write-Host "  Files without tests: $($gaps.Count)" -ForegroundColor Yellow
    Write-Host "  Coverage estimate: $coverage%" -ForegroundColor $(if ($coverage -ge 80) { "Green" } elseif ($coverage -ge 50) { "Yellow" } else { "Red" })
    Write-Host ""

    # Critical gaps
    $critical = $gaps | Where-Object { $_.criticality -eq "high" }
    $medium = $gaps | Where-Object { $_.criticality -eq "medium" }

    if ($critical.Count -gt 0) {
        Write-Host "🔴 CRITICAL GAPS (needs tests!):" -ForegroundColor Red
        foreach ($g in $critical | Select-Object -First 10) {
            Write-Host "  • $($g.file)" -ForegroundColor White
        }
        Write-Host ""
    }

    if ($medium.Count -gt 0) {
        Write-Host "🟡 MEDIUM PRIORITY:" -ForegroundColor Yellow
        foreach ($g in $medium | Select-Object -First 10) {
            Write-Host "  • $($g.file)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    Write-Host "RECOMMENDATIONS:" -ForegroundColor Magenta
    if ($critical.Count -gt 0) {
        Write-Host "  1. Add tests for critical files first (Controllers, Services)" -ForegroundColor White
    }
    if ($coverage -lt 50) {
        Write-Host "  2. Consider adding test generation tool" -ForegroundColor White
    }
    Write-Host "  3. Aim for 80%+ coverage on business logic" -ForegroundColor White
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Analyze -Path 'src/'     Analyze test gaps" -ForegroundColor White
    Write-Host "  -TestPath 'tests/'        Specify test directory" -ForegroundColor White
}
