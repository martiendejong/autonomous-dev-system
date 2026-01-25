<#
.SYNOPSIS
    Pre-flight validation before PR creation - catches issues locally.

.DESCRIPTION
    Runs comprehensive validation checks BEFORE creating a PR:
    - Build validation (backend + frontend)
    - EF Core migration validation
    - Unit tests (fast tests only)
    - Static code analysis (auto-code-review.ps1 integration)
    - Security scanning
    - Code quality metrics

    Designed for FREE GitHub (no Actions minutes used - all local).

.PARAMETER Repo
    Repository name (client-manager, hazina)

.PARAMETER Branch
    Branch to validate

.PARAMETER AutoFix
    Attempt to auto-fix issues (formatting, missing migrations)

.PARAMETER SkipTests
    Skip unit tests (faster validation)

.PARAMETER Verbose
    Show detailed output

.EXAMPLE
    .\pr-preflight.ps1 -Repo "client-manager" -Branch "feature/new-thing"

.EXAMPLE
    .\pr-preflight.ps1 -Repo "client-manager" -Branch "feature/x" -AutoFix
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Repo,

    [Parameter(Mandatory=$false)]
    [string]$Branch,

    [switch]$AutoFix,
    [switch]$SkipTests,
    [switch]$Verbose
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ErrorActionPreference = "Continue"

# Configuration
$RepoMappings = @{
    "client-manager" = "C:\Projects\client-manager"
    "hazina" = "C:\Projects\hazina"
}

# Colors
function Write-CheckHeader($text) {
    Write-Host "`n$text" -ForegroundColor Cyan
    Write-Host ("=" * $text.Length) -ForegroundColor DarkCyan
}

function Write-CheckResult($name, $status, $message = "") {
    $statusText = switch ($status) {
        "PASS" { "[✓]" }
        "WARN" { "[!]" }
        "FAIL" { "[✗]" }
        "SKIP" { "[-]" }
    }

    $color = switch ($status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        "SKIP" { "Gray" }
    }

    $line = "$statusText $name"
    if ($message) {
        $line += " - $message"
    }

    Write-Host $line -ForegroundColor $color
}

# Results tracking
$script:Results = @{
    Checks = @()
    Warnings = @()
    Errors = @()
    AutoFixes = @()
    TotalTime = 0
}

function Add-CheckResult($name, $status, $message, $details = $null, $duration = 0) {
    $script:Results.Checks += @{
        Name = $name
        Status = $status
        Message = $message
        Details = $details
        Duration = $duration
    }

    if ($status -eq "WARN") {
        $script:Results.Warnings += "$name - $message"
    }
    elseif ($status -eq "FAIL") {
        $script:Results.Errors += "$name - $message"
    }

    Write-CheckResult -name $name -status $status -message "$message (${duration}s)"
}

# Auto-detect repo and branch if not specified
if (-not $Repo -or -not $Branch) {
    $currentDir = Get-Location

    # Try to detect from current directory
    foreach ($repoName in $RepoMappings.Keys) {
        if ($currentDir.Path -like "*$repoName*") {
            $Repo = $repoName
            break
        }
    }

    if (-not $Branch) {
        $Branch = git branch --show-current 2>$null
    }
}

if (-not $Repo) {
    Write-Host "ERROR: Could not detect repository. Specify -Repo parameter." -ForegroundColor Red
    exit 1
}

if (-not $RepoMappings.ContainsKey($Repo)) {
    Write-Host "ERROR: Unknown repository: $Repo" -ForegroundColor Red
    exit 1
}

$RepoPath = $RepoMappings[$Repo]

if (-not (Test-Path $RepoPath)) {
    Write-Host "ERROR: Repository path not found: $RepoPath" -ForegroundColor Red
    exit 1
}

# Header
Write-CheckHeader "PR Pre-Flight Validation"
Write-Host "Repository: $Repo" -ForegroundColor White
Write-Host "Path: $RepoPath" -ForegroundColor Gray
Write-Host "Branch: $Branch" -ForegroundColor White
Write-Host ""

$startTime = Get-Date

# Change to repo directory
Push-Location $RepoPath

try {
    # ============================================
    # CHECK 1: Verify branch is up-to-date with develop
    # ============================================
    Write-CheckHeader "1. Branch Sync Check"
    $checkStart = Get-Date

    git fetch origin develop 2>&1 | Out-Null
    $mergeBase = git merge-base HEAD origin/develop 2>$null
    $developHead = git rev-parse origin/develop 2>$null

    if ($mergeBase -ne $developHead -and $Branch -ne "develop") {
        Add-CheckResult "Branch sync" "WARN" "Branch not up-to-date with develop (should have been merged)" -duration ((Get-Date) - $checkStart).TotalSeconds
    }
    else {
        Add-CheckResult "Branch sync" "PASS" "Up-to-date with develop" -duration ((Get-Date) - $checkStart).TotalSeconds
    }

    # ============================================
    # CHECK 2: Backend Build
    # ============================================
    Write-CheckHeader "2. Backend Build"
    $checkStart = Get-Date

    $backendProject = Get-ChildItem -Recurse -Filter "*.csproj" | Select-Object -First 1

    if ($backendProject) {
        if ($Verbose) {
            $buildOutput = dotnet build $backendProject.FullName 2>&1
        }
        else {
            $buildOutput = dotnet build $backendProject.FullName --nologo --verbosity quiet 2>&1
        }

        if ($LASTEXITCODE -eq 0) {
            Add-CheckResult "Backend build" "PASS" "Build succeeded" -duration ((Get-Date) - $checkStart).TotalSeconds
        }
        else {
            $errors = $buildOutput | Where-Object { $_ -match "error" } | Select-Object -First 5
            Add-CheckResult "Backend build" "FAIL" "Build failed" -details $errors -duration ((Get-Date) - $checkStart).TotalSeconds
        }
    }
    else {
        Add-CheckResult "Backend build" "SKIP" "No C# project found" -duration ((Get-Date) - $checkStart).TotalSeconds
    }

    # ============================================
    # CHECK 3: Frontend Build
    # ============================================
    Write-CheckHeader "3. Frontend Build"
    $checkStart = Get-Date

    $packageJson = Get-ChildItem -Recurse -Filter "package.json" | Where-Object { $_.Directory.Name -notmatch "node_modules" } | Select-Object -First 1

    if ($packageJson) {
        Push-Location $packageJson.Directory
        try {
            if ($Verbose) {
                $buildOutput = npm run build 2>&1
            }
            else {
                $buildOutput = npm run build --silent 2>&1
            }

            if ($LASTEXITCODE -eq 0) {
                Add-CheckResult "Frontend build" "PASS" "Build succeeded" -duration ((Get-Date) - $checkStart).TotalSeconds
            }
            else {
                $errors = $buildOutput | Where-Object { $_ -match "error" -or $_ -match "failed" } | Select-Object -First 5
                Add-CheckResult "Frontend build" "FAIL" "Build failed" -details $errors -duration ((Get-Date) - $checkStart).TotalSeconds
            }
        }
        finally {
            Pop-Location
        }
    }
    else {
        Add-CheckResult "Frontend build" "SKIP" "No package.json found" -duration ((Get-Date) - $checkStart).TotalSeconds
    }

    # ============================================
    # CHECK 4: EF Core Migration Check
    # ============================================
    Write-CheckHeader "4. EF Core Migrations"
    $checkStart = Get-Date

    if ($backendProject) {
        # Check for pending model changes (CRITICAL!)
        $migrationCheck = dotnet ef migrations has-pending-model-changes --project $backendProject.FullName --no-build 2>&1

        if ($LASTEXITCODE -eq 0) {
            Add-CheckResult "EF migrations" "PASS" "No pending model changes" -duration ((Get-Date) - $checkStart).TotalSeconds
        }
        elseif ($LASTEXITCODE -eq 1) {
            if ($AutoFix) {
                Write-Host "  Attempting to create migration..." -ForegroundColor Yellow
                $migrationName = "AutoGenerated_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                $createOutput = dotnet ef migrations add $migrationName --project $backendProject.FullName 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $script:Results.AutoFixes += "Created migration: $migrationName"
                    Add-CheckResult "EF migrations" "WARN" "Created migration: $migrationName (review required)" -duration ((Get-Date) - $checkStart).TotalSeconds
                }
                else {
                    Add-CheckResult "EF migrations" "FAIL" "Pending changes detected, auto-fix failed" -details $createOutput -duration ((Get-Date) - $checkStart).TotalSeconds
                }
            }
            else {
                Add-CheckResult "EF migrations" "FAIL" "Pending model changes detected - migration required" -duration ((Get-Date) - $checkStart).TotalSeconds
            }
        }
        else {
            Add-CheckResult "EF migrations" "WARN" "Could not check migrations" -details $migrationCheck -duration ((Get-Date) - $checkStart).TotalSeconds
        }
    }
    else {
        Add-CheckResult "EF migrations" "SKIP" "No backend project" -duration ((Get-Date) - $checkStart).TotalSeconds
    }

    # ============================================
    # CHECK 5: Unit Tests
    # ============================================
    Write-CheckHeader "5. Unit Tests"
    $checkStart = Get-Date

    if (-not $SkipTests -and $backendProject) {
        $testProjects = Get-ChildItem -Recurse -Filter "*Test*.csproj"

        if ($testProjects) {
            if ($Verbose) {
                $testOutput = dotnet test --filter "Category=Unit|FullyQualifiedName~UnitTest" --no-build --verbosity normal 2>&1
            }
            else {
                $testOutput = dotnet test --filter "Category=Unit|FullyQualifiedName~UnitTest" --no-build --verbosity quiet 2>&1
            }

            if ($LASTEXITCODE -eq 0) {
                $passedTests = ($testOutput | Select-String "Passed!" | Out-String).Trim()
                Add-CheckResult "Unit tests" "PASS" $passedTests -duration ((Get-Date) - $checkStart).TotalSeconds
            }
            else {
                $failures = $testOutput | Select-String "Failed|Error" | Select-Object -First 5
                Add-CheckResult "Unit tests" "FAIL" "Tests failed" -details $failures -duration ((Get-Date) - $checkStart).TotalSeconds
            }
        }
        else {
            Add-CheckResult "Unit tests" "SKIP" "No test projects found" -duration ((Get-Date) - $checkStart).TotalSeconds
        }
    }
    else {
        Add-CheckResult "Unit tests" "SKIP" "Skipped (use -SkipTests flag)" -duration ((Get-Date) - $checkStart).TotalSeconds
    }

    # ============================================
    # CHECK 6: Static Analysis & Security
    # ============================================
    Write-CheckHeader "6. Static Analysis & Security"
    $checkStart = Get-Date

    $autoCodeReviewScript = "C:\scripts\tools\auto-code-review.ps1"

    if (Test-Path $autoCodeReviewScript) {
        if ($Verbose) {
            & $autoCodeReviewScript -Path $RepoPath -Severity "error" -OutputFormat "console"
        }
        else {
            $reviewOutput = & $autoCodeReviewScript -Path $RepoPath -Severity "error" -OutputFormat "json" 2>&1
        }

        if ($LASTEXITCODE -eq 0) {
            Add-CheckResult "Static analysis" "PASS" "No critical issues" -duration ((Get-Date) - $checkStart).TotalSeconds
        }
        else {
            Add-CheckResult "Static analysis" "WARN" "Issues detected (review output)" -duration ((Get-Date) - $checkStart).TotalSeconds
        }
    }
    else {
        Add-CheckResult "Static analysis" "SKIP" "auto-code-review.ps1 not found" -duration ((Get-Date) - $checkStart).TotalSeconds
    }

    # ============================================
    # CHECK 7: Code Quality (basic)
    # ============================================
    Write-CheckHeader "7. Code Quality"
    $checkStart = Get-Date

    # Check for common issues
    $todoCount = (Get-ChildItem -Recurse -Include "*.cs","*.ts","*.tsx" | Select-String "TODO:|FIXME:" -CaseSensitive | Measure-Object).Count
    $debugCount = (Get-ChildItem -Recurse -Include "*.cs" | Select-String "Console.WriteLine|System.Diagnostics.Debug" | Measure-Object).Count

    $qualityIssues = @()
    if ($todoCount -gt 0) { $qualityIssues += "$todoCount TODO/FIXME comments" }
    if ($debugCount -gt 0) { $qualityIssues += "$debugCount debug statements" }

    if ($qualityIssues.Count -eq 0) {
        Add-CheckResult "Code quality" "PASS" "No obvious issues" -duration ((Get-Date) - $checkStart).TotalSeconds
    }
    else {
        Add-CheckResult "Code quality" "WARN" ($qualityIssues -join ", ") -duration ((Get-Date) - $checkStart).TotalSeconds
    }

}
finally {
    Pop-Location
}

# ============================================
# FINAL REPORT
# ============================================
$endTime = Get-Date
$totalDuration = ($endTime - $startTime).TotalSeconds

Write-CheckHeader "Pre-Flight Summary"

$passCount = ($script:Results.Checks | Where-Object { $_.Status -eq "PASS" }).Count
$warnCount = ($script:Results.Checks | Where-Object { $_.Status -eq "WARN" }).Count
$failCount = ($script:Results.Checks | Where-Object { $_.Status -eq "FAIL" }).Count
$skipCount = ($script:Results.Checks | Where-Object { $_.Status -eq "SKIP" }).Count

Write-Host "Passed:  $passCount" -ForegroundColor Green
Write-Host "Warnings: $warnCount" -ForegroundColor Yellow
Write-Host "Failed:   $failCount" -ForegroundColor Red
Write-Host "Skipped:  $skipCount" -ForegroundColor Gray
Write-Host "Duration: $([math]::Round($totalDuration, 1))s" -ForegroundColor Gray

if ($script:Results.AutoFixes.Count -gt 0) {
    Write-Host "`nAuto-fixes applied:" -ForegroundColor Cyan
    foreach ($fix in $script:Results.AutoFixes) {
        Write-Host "  - $fix" -ForegroundColor Yellow
    }
}

if ($script:Results.Errors.Count -gt 0) {
    Write-Host "`nErrors:" -ForegroundColor Red
    foreach ($err in $script:Results.Errors) {
        Write-Host "  - $err" -ForegroundColor Red
    }
    Write-Host "`nFix errors before creating PR!" -ForegroundColor Red
    exit 1
}

if ($script:Results.Warnings.Count -gt 0) {
    Write-Host "`nWarnings:" -ForegroundColor Yellow
    foreach ($warn in $script:Results.Warnings) {
        Write-Host "  - $warn" -ForegroundColor Yellow
    }
    Write-Host "`nWarnings detected - review recommended" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n✅ All checks passed - safe to create PR!" -ForegroundColor Green
exit 0
