<#
.SYNOPSIS
    Quick smoke test runner for Claude Agent tools.

.DESCRIPTION
    Runs basic validation on all tools to ensure they:
    - Load without syntax errors
    - Show help without crashing
    - Complete basic operations

.PARAMETER Tool
    Specific tool to test (optional, tests all if not specified)

.PARAMETER Verbose
    Show detailed output

.EXAMPLE
    .\smoke-test.ps1
    .\smoke-test.ps1 -Tool "bootstrap-snapshot"
    .\smoke-test.ps1 -Verbose
#>

param(
    [string]$Tool,
    [switch]$Verbose
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ToolsPath = "C:\scripts\tools"

$TestResults = @{
    passed = @()
    failed = @()
    skipped = @()
}

function Test-ToolSyntax {
    param([string]$Path)

    try {
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $Path,
            [ref]$null,
            [ref]$null
        )
        return $true
    } catch {
        return $false
    }
}

function Test-ToolHelp {
    param([string]$Path)

    try {
        $help = Get-Help $Path -ErrorAction Stop
        return $help.Synopsis -ne $null
    } catch {
        return $false
    }
}

function Test-ToolDryRun {
    param([string]$Path, [string]$Name)

    # Tools that support -DryRun
    $dryRunTools = @(
        "worktree-release-all",
        "worktree-allocate",
        "prune-branches",
        "maintenance",
        "archive-reflections",
        "worktree-cleanup",
        "migrate-pool-to-json"
    )

    if ($Name -in $dryRunTools) {
        try {
            $output = & $Path -DryRun 2>&1
            return $LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE
        } catch {
            return $false
        }
    }

    return $null  # Skip - no dry run support
}

function Write-TestResult {
    param([string]$Name, [string]$Test, [bool]$Passed, [string]$Details = "")

    $status = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Passed) { "Green" } else { "Red" }

    if ($Verbose -or -not $Passed) {
        Write-Host "$status $Name - $Test" -ForegroundColor $color
        if ($Details) {
            Write-Host "       $Details" -ForegroundColor DarkGray
        }
    }
}

# Main execution
Write-Host ""
Write-Host "=== SMOKE TEST RUNNER ===" -ForegroundColor Cyan
Write-Host ""

$tools = if ($Tool) {
    Get-ChildItem $ToolsPath -Filter "$Tool*.ps1" | Where-Object { $_.Name -notlike "*node_modules*" }
} else {
    Get-ChildItem $ToolsPath -Filter "*.ps1" | Where-Object { $_.Name -notlike "*node_modules*" }
}

Write-Host "Testing $($tools.Count) tools..." -ForegroundColor DarkGray
Write-Host ""

foreach ($file in $tools) {
    $name = $file.BaseName

    if ($Verbose) {
        Write-Host "Testing: $name" -ForegroundColor Cyan
    }

    # Test 1: Syntax
    $syntaxOk = Test-ToolSyntax -Path $file.FullName
    Write-TestResult -Name $name -Test "Syntax" -Passed $syntaxOk

    if ($syntaxOk) {
        $TestResults.passed += "$name (syntax)"
    } else {
        $TestResults.failed += "$name (syntax)"
        continue  # Skip other tests if syntax fails
    }

    # Test 2: Help
    $helpOk = Test-ToolHelp -Path $file.FullName
    Write-TestResult -Name $name -Test "Help" -Passed $helpOk

    if ($helpOk) {
        $TestResults.passed += "$name (help)"
    } else {
        $TestResults.failed += "$name (help)"
    }

    # Test 3: Dry Run (if supported)
    $dryRunResult = Test-ToolDryRun -Path $file.FullName -Name $name
    if ($null -ne $dryRunResult) {
        Write-TestResult -Name $name -Test "DryRun" -Passed $dryRunResult

        if ($dryRunResult) {
            $TestResults.passed += "$name (dryrun)"
        } else {
            $TestResults.failed += "$name (dryrun)"
        }
    } else {
        $TestResults.skipped += "$name (dryrun)"
    }

    if ($Verbose) {
        Write-Host ""
    }
}

# Summary
Write-Host ""
Write-Host "=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Passed: $($TestResults.passed.Count)" -ForegroundColor Green
Write-Host "Failed: $($TestResults.failed.Count)" -ForegroundColor $(if ($TestResults.failed.Count -gt 0) { "Red" } else { "Green" })
Write-Host "Skipped: $($TestResults.skipped.Count)" -ForegroundColor DarkGray

if ($TestResults.failed.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILURES:" -ForegroundColor Red
    $TestResults.failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host ""
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
