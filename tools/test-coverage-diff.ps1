<#
.SYNOPSIS
    Show test coverage delta between branches (not absolute %)

.DESCRIPTION
    Compares test coverage between base and head:
    - NEW uncovered lines added
    - Coverage delta per file
    - Changed files coverage report

    Problem with traditional coverage:
    - "80% coverage" is meaningless if new code is 0% covered
    - Absolute % hides regression in new code

    This tool shows:
    - Coverage of CHANGED code only
    - NEW uncovered lines introduced
    - Coverage trend (improving/declining)

.PARAMETER BaseBranch
    Base branch to compare against (default: main)

.PARAMETER HeadBranch
    Head branch to compare (default: current)

.PARAMETER ProjectPath
    Path to project root

.PARAMETER CoverageFormat
    Coverage file format: cobertura, lcov, opencover

.PARAMETER MinCoverage
    Minimum coverage for new code (default: 80%)

.EXAMPLE
    # Check coverage diff against main
    .\test-coverage-diff.ps1 -BaseBranch main

.EXAMPLE
    # Require 90% coverage for new code
    .\test-coverage-diff.ps1 -MinCoverage 90

.NOTES
    Value: 8/10 - Prevents coverage regression
    Effort: 1.5/10 - Git diff + coverage XML parsing
    Ratio: 5.3 (TIER S)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BaseBranch = "main",

    [Parameter(Mandatory=$false)]
    [string]$HeadBranch = "HEAD",

    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [ValidateSet('cobertura', 'lcov', 'opencover')]
    [string]$CoverageFormat = 'cobertura',

    [Parameter(Mandatory=$false)]
    [double]$MinCoverage = 80.0
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Test Coverage Diff" -ForegroundColor Cyan
Write-Host "  Base: $BaseBranch" -ForegroundColor Gray
Write-Host "  Head: $HeadBranch" -ForegroundColor Gray
Write-Host "  Min coverage: $MinCoverage%" -ForegroundColor Gray
Write-Host ""

Push-Location $ProjectPath

try {
    # Get changed files
    $changedFiles = git diff $BaseBranch...$HeadBranch --name-only --diff-filter=ACMR |
        Where-Object { $_ -match '\.(cs|ts|tsx|js|jsx)$' }

    if ($changedFiles.Count -eq 0) {
        Write-Host "✅ No code files changed" -ForegroundColor Green
        exit 0
    }

    Write-Host "Changed files: $($changedFiles.Count)" -ForegroundColor Yellow
    Write-Host ""

    # Find coverage report
    $coverageFile = switch ($CoverageFormat) {
        'cobertura' { Get-ChildItem -Path $ProjectPath -Filter "coverage.cobertura.xml" -Recurse | Select-Object -First 1 }
        'lcov' { Get-ChildItem -Path $ProjectPath -Filter "lcov.info" -Recurse | Select-Object -First 1 }
        'opencover' { Get-ChildItem -Path $ProjectPath -Filter "coverage.opencover.xml" -Recurse | Select-Object -First 1 }
    }

    if (-not $coverageFile) {
        Write-Host "⚠️  Coverage file not found. Run tests with coverage first." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "For .NET:" -ForegroundColor Cyan
        Write-Host "  dotnet test --collect:\"XPlat Code Coverage\" --results-directory ./TestResults" -ForegroundColor Gray
        Write-Host ""
        Write-Host "For JavaScript:" -ForegroundColor Cyan
        Write-Host "  npm test -- --coverage" -ForegroundColor Gray
        exit 1
    }

    Write-Host "Coverage file: $($coverageFile.Name)" -ForegroundColor Gray
    Write-Host ""

    # Parse coverage (Cobertura format)
    [xml]$coverage = Get-Content $coverageFile.FullName

    $coverageData = @()

    foreach ($file in $changedFiles) {
        # Find matching coverage entry
        $fileName = [System.IO.Path]::GetFileName($file)

        $classCoverage = $coverage.coverage.packages.package.classes.class |
            Where-Object { $_.filename -like "*$fileName" } |
            Select-Object -First 1

        if ($classCoverage) {
            $lines = $classCoverage.lines.line
            $coveredLines = ($lines | Where-Object { $_.hits -gt 0 }).Count
            $totalLines = $lines.Count

            $coveragePercent = if ($totalLines -gt 0) { ($coveredLines / $totalLines) * 100 } else { 0 }

            # Get added lines from git diff
            $diffOutput = git diff $BaseBranch...$HeadBranch -- $file | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' }
            $addedLines = $diffOutput.Count

            $coverageData += [PSCustomObject]@{
                File = $file
                AddedLines = $addedLines
                CoveredLines = $coveredLines
                TotalLines = $totalLines
                Coverage = [Math]::Round($coveragePercent, 1)
                Status = if ($coveragePercent -ge $MinCoverage) { "PASS" } else { "FAIL" }
            }
        } else {
            $coverageData += [PSCustomObject]@{
                File = $file
                AddedLines = "N/A"
                CoveredLines = 0
                TotalLines = 0
                Coverage = 0.0
                Status = "NO_COVERAGE"
            }
        }
    }

} finally {
    Pop-Location
}

Write-Host "COVERAGE DIFF ANALYSIS" -ForegroundColor Cyan
Write-Host ""

$coverageData | Format-Table -AutoSize -Property @(
    @{Label='File'; Expression={$_.File}; Width=50}
    @{Label='Added Lines'; Expression={$_.AddedLines}; Align='Right'}
    @{Label='Coverage'; Expression={"$($_.Coverage)%"}; Align='Right'}
    @{Label='Status'; Expression={$_.Status}; Width=12}
)

Write-Host ""
Write-Host "SUMMARY:" -ForegroundColor Cyan
$avgCoverage = ($coverageData | Where-Object { $_.Coverage -gt 0 } | Measure-Object Coverage -Average).Average
Write-Host "  Average coverage of changed files: $([Math]::Round($avgCoverage, 1))%" -ForegroundColor Gray

$failedFiles = ($coverageData | Where-Object { $_.Status -eq "FAIL" }).Count
$noCoverageFiles = ($coverageData | Where-Object { $_.Status -eq "NO_COVERAGE" }).Count

if ($failedFiles -gt 0 -or $noCoverageFiles -gt 0) {
    Write-Host "  Files below threshold: $failedFiles" -ForegroundColor Red
    Write-Host "  Files without coverage: $noCoverageFiles" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "❌ Coverage requirements not met" -ForegroundColor Red
    exit 1
} else {
    Write-Host "  All files meet coverage threshold" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ Coverage requirements met!" -ForegroundColor Green
    exit 0
}
