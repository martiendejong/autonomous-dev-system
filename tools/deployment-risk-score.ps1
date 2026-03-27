<#
.SYNOPSIS
    Calculate deployment risk score to prevent production incidents

.DESCRIPTION
    Analyzes changes to calculate risk of deployment:
    - Change size (lines changed)
    - Files changed (core vs peripheral)
    - Test coverage delta
    - Breaking changes detected
    - Migration presence
    - Recent bug patterns

    Returns risk score (0-100) + specific warnings.

.PARAMETER Branch
    Branch to analyze (default: current)

.PARAMETER BaseBranch
    Base branch to compare against (default: develop)

.PARAMETER Threshold
    Risk threshold (0-100, default: 70)
    Deployment blocked if risk > threshold

.EXAMPLE
    # Calculate risk for current branch
    .\deployment-risk-score.ps1

.EXAMPLE
    # Check if safe to deploy (exit code 0 = safe, 1 = risky)
    .\deployment-risk-score.ps1 -Threshold 50

.EXAMPLE
    # Analyze specific PR
    .\deployment-risk-score.ps1 -Branch feature/new-auth -BaseBranch main

.NOTES
    Value: 10/10 - Prevents production incidents
    Effort: 1.5/10 - Git diff analysis
    Ratio: 6.7 (TIER S+ - Wave 2 #3)

    Wave 2 insight: Wave 1 focused on dev tools, Wave 2 adds
    production safety = compound ROI (avoid incidents)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Branch = (git branch --show-current),

    [Parameter(Mandatory=$false)]
    [string]$BaseBranch = "develop",

    [Parameter(Mandatory=$false)]
    [int]$Threshold = 70,

    [Parameter(Mandatory=$false)]
    [switch]$Verbose = $false
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "DEPLOYMENT RISK ASSESSMENT" -ForegroundColor Cyan
Write-Host "Branch: $Branch -> $BaseBranch" -ForegroundColor Gray
Write-Host ""

$riskScore = 0
$warnings = @()
$factors = @()

# 1. Change size analysis
Write-Host "[1/7] Analyzing change size..." -ForegroundColor Gray
$diff = git diff --shortstat $BaseBranch...$Branch 2>$null

if ($diff -match '(\d+) files? changed(?:, (\d+) insertions?\(\+\))?(?:, (\d+) deletions?\(-\))?') {
    $filesChanged = [int]$Matches[1]
    $insertions = if ($Matches[2]) { [int]$Matches[2] } else { 0 }
    $deletions = if ($Matches[3]) { [int]$Matches[3] } else { 0 }
    $totalLines = $insertions + $deletions

    # Risk increases with change size
    $sizeRisk = [Math]::Min(30, ($totalLines / 100) * 5)
    $riskScore += $sizeRisk

    $factors += [PSCustomObject]@{
        Factor = "Change Size"
        Value = "$filesChanged files, $totalLines lines"
        Risk = [Math]::Round($sizeRisk, 1)
    }

    if ($totalLines -gt 1000) {
        $warnings += "LARGE CHANGE: $totalLines lines modified (high risk)"
    }
}

# 2. Core file changes
Write-Host "[2/7] Checking core files..." -ForegroundColor Gray
$changedFiles = git diff --name-only $BaseBranch...$Branch 2>$null

$corePatterns = @(
    'DbContext\.cs$',
    'Startup\.cs$',
    'Program\.cs$',
    'appsettings.*\.json$',
    'Migrations/',
    'wwwroot/index\.html$'
)

$coreFilesChanged = $changedFiles | Where-Object {
    foreach ($pattern in $corePatterns) {
        if ($_ -match $pattern) { return $true }
    }
    return $false
}

if ($coreFilesChanged) {
    $coreRisk = [Math]::Min(25, $coreFilesChanged.Count * 10)
    $riskScore += $coreRisk

    $factors += [PSCustomObject]@{
        Factor = "Core Files"
        Value = "$($coreFilesChanged.Count) core files changed"
        Risk = [Math]::Round($coreRisk, 1)
    }

    $warnings += "CORE FILES MODIFIED: $($coreFilesChanged.Count) critical files changed"
}

# 3. Migration presence
Write-Host "[3/7] Checking migrations..." -ForegroundColor Gray
$migrations = $changedFiles | Where-Object { $_ -match 'Migrations/.*\.cs$' }

if ($migrations) {
    $migrationRisk = 15  # Migrations always risky

    $factors += [PSCustomObject]@{
        Factor = "Database Migration"
        Value = "$($migrations.Count) migration(s)"
        Risk = $migrationRisk
    }

    # Check if migration has Down method
    $hasRollback = $false
    foreach ($migration in $migrations) {
        $content = git show "$Branch`:$migration" 2>$null
        if ($content -match 'protected override void Down') {
            $hasRollback = $true
            break
        }
    }

    if (-not $hasRollback) {
        $riskScore += $migrationRisk + 10
        $warnings += "MIGRATION WITHOUT ROLLBACK: No Down() method detected"
    } else {
        $riskScore += $migrationRisk
    }
}

# 4. Test coverage check
Write-Host "[4/7] Checking test coverage..." -ForegroundColor Gray
$testFiles = $changedFiles | Where-Object { $_ -match 'test|spec|\.test\.|\.spec\.' -and $_ -match '\.(cs|ts|tsx)$' }
$codeFiles = $changedFiles | Where-Object { $_ -match '\.(cs|ts|tsx)$' -and $_ -notmatch 'test|spec' }

if ($codeFiles.Count -gt 0) {
    $testRatio = if ($testFiles.Count -gt 0) { $testFiles.Count / $codeFiles.Count } else { 0 }

    if ($testRatio -lt 0.3) {
        $testRisk = 20
        $riskScore += $testRisk

        $factors += [PSCustomObject]@{
            Factor = "Test Coverage"
            Value = "Low test coverage ($([Math]::Round($testRatio * 100))%)"
            Risk = $testRisk
        }

        $warnings += "LOW TEST COVERAGE: Only $($testFiles.Count) test files for $($codeFiles.Count) code files"
    }
}

# 5. Breaking changes detection
Write-Host "[5/7] Detecting breaking changes..." -ForegroundColor Gray
$apiFiles = $changedFiles | Where-Object { $_ -match 'Controllers?/.*\.cs$|/api/|API/' }

if ($apiFiles) {
    # Simple heuristic: check for removed/renamed methods
    foreach ($file in $apiFiles) {
        $diff = git diff $BaseBranch...$Branch -- $file 2>$null
        if ($diff -match '^\-.*public.*\s+(Get|Post|Put|Delete|Patch)') {
            $riskScore += 15
            $warnings += "POTENTIAL BREAKING CHANGE: API method modified in $file"
            break
        }
    }
}

# 6. Recent bug pattern check
Write-Host "[6/7] Checking recent bug patterns..." -ForegroundColor Gray
$recentCommits = git log --oneline -20 $BaseBranch 2>$null

$bugKeywords = @('fix', 'bug', 'hotfix', 'revert', 'rollback')
$recentBugs = $recentCommits | Where-Object {
    foreach ($keyword in $bugKeywords) {
        if ($_ -match $keyword) { return $true }
    }
    return $false
}

if ($recentBugs.Count -gt 3) {
    $riskScore += 10
    $warnings += "HIGH BUG RATE: $($recentBugs.Count) bug fixes in last 20 commits"
}

# 7. Configuration changes
Write-Host "[7/7] Checking configuration..." -ForegroundColor Gray
$configFiles = $changedFiles | Where-Object { $_ -match 'appsettings.*\.json$|web\.config$|\.env' }

if ($configFiles) {
    $riskScore += 10
    $factors += [PSCustomObject]@{
        Factor = "Configuration"
        Value = "$($configFiles.Count) config file(s)"
        Risk = 10
    }
}

# Final risk score (cap at 100)
$riskScore = [Math]::Min(100, $riskScore)

# Determine risk level
$riskLevel = if ($riskScore -lt 30) { "LOW" }
             elseif ($riskScore -lt 60) { "MEDIUM" }
             elseif ($riskScore -lt 80) { "HIGH" }
             else { "CRITICAL" }

# Output
Write-Host ""
Write-Host "===== RISK ASSESSMENT RESULTS =====" -ForegroundColor Cyan
Write-Host ""
Write-Host "RISK SCORE: $riskScore / 100" -ForegroundColor $(
    if ($riskLevel -eq "LOW") { "Green" }
    elseif ($riskLevel -eq "MEDIUM") { "Yellow" }
    else { "Red" }
)
Write-Host "RISK LEVEL: $riskLevel" -ForegroundColor $(
    if ($riskLevel -eq "LOW") { "Green" }
    elseif ($riskLevel -eq "MEDIUM") { "Yellow" }
    else { "Red" }
)
Write-Host ""

if ($factors.Count -gt 0) {
    Write-Host "RISK FACTORS:" -ForegroundColor Yellow
    $factors | Format-Table -AutoSize -Property Factor, Value, Risk
}

if ($warnings.Count -gt 0) {
    Write-Host "WARNINGS:" -ForegroundColor Red
    $warnings | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Recommendations
Write-Host "RECOMMENDATIONS:" -ForegroundColor Cyan
if ($riskScore -lt 30) {
    Write-Host "  - Low risk deployment" -ForegroundColor Green
    Write-Host "  - Standard deployment process" -ForegroundColor Gray
} elseif ($riskScore -lt 60) {
    Write-Host "  - Medium risk - proceed with caution" -ForegroundColor Yellow
    Write-Host "  - Review all warnings above" -ForegroundColor Gray
    Write-Host "  - Ensure rollback plan ready" -ForegroundColor Gray
} elseif ($riskScore -< 80) {
    Write-Host "  - High risk deployment!" -ForegroundColor Red
    Write-Host "  - Consider canary deployment" -ForegroundColor Gray
    Write-Host "  - Have rollback ready" -ForegroundColor Gray
    Write-Host "  - Monitor closely post-deploy" -ForegroundColor Gray
} else {
    Write-Host "  - CRITICAL RISK - DO NOT DEPLOY without review!" -ForegroundColor Red
    Write-Host "  - Break into smaller changes" -ForegroundColor Gray
    Write-Host "  - Add more tests" -ForegroundColor Gray
    Write-Host "  - Staged rollout required" -ForegroundColor Gray
}

Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Exit code based on threshold
if ($riskScore -gt $Threshold) {
    Write-Host "DEPLOYMENT BLOCKED: Risk ($riskScore) exceeds threshold ($Threshold)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Deployment approved (risk within threshold)" -ForegroundColor Green
    exit 0
}
