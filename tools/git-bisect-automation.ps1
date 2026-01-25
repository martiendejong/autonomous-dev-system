<#
.SYNOPSIS
    Automated git bisect for finding regression commits

.DESCRIPTION
    Automates binary search through git history to find:
    - When a bug was introduced
    - Which commit broke tests
    - Performance regression point
    - Build failure origin

    Traditional git bisect requires manual testing at each step.
    This tool automates the entire process.

.PARAMETER GoodCommit
    Known good commit (no bug)

.PARAMETER BadCommit
    Known bad commit (has bug) - default: HEAD

.PARAMETER TestCommand
    Command to run at each commit (exit 0 = good, non-zero = bad)

.PARAMETER ProjectPath
    Path to git repository

.PARAMETER Timeout
    Test timeout in seconds (default: 300)

.EXAMPLE
    # Find when tests started failing
    .\git-bisect-automation.ps1 -GoodCommit v1.0.0 -TestCommand "dotnet test"

.EXAMPLE
    # Find performance regression
    .\git-bisect-automation.ps1 -GoodCommit abc123 -TestCommand ".\run-perf-test.ps1"

.NOTES
    Value: 8/10 - Saves hours of manual bisecting
    Effort: 1.5/10 - Git automation wrapper
    Ratio: 5.3 (TIER S)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$GoodCommit,

    [Parameter(Mandatory=$false)]
    [string]$BadCommit = "HEAD",

    [Parameter(Mandatory=$true)]
    [string]$TestCommand,

    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [int]$Timeout = 300
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Git Bisect Automation" -ForegroundColor Cyan
Write-Host "  Repository: $ProjectPath" -ForegroundColor Gray
Write-Host "  Good commit: $GoodCommit" -ForegroundColor Green
Write-Host "  Bad commit: $BadCommit" -ForegroundColor Red
Write-Host "  Test command: $TestCommand" -ForegroundColor Gray
Write-Host ""

Push-Location $ProjectPath

try {
    # Verify git repo
    $isGitRepo = git rev-parse --is-inside-work-tree 2>$null
    if (-not $isGitRepo) {
        Write-Host "❌ Not a git repository" -ForegroundColor Red
        exit 1
    }

    # Verify commits exist
    $goodExists = git rev-parse --verify $GoodCommit 2>$null
    $badExists = git rev-parse --verify $BadCommit 2>$null

    if (-not $goodExists -or -not $badExists) {
        Write-Host "❌ Commits not found" -ForegroundColor Red
        exit 1
    }

    Write-Host "Starting automated git bisect..." -ForegroundColor Yellow
    Write-Host ""

    # Start bisect
    git bisect start | Out-Null
    git bisect bad $BadCommit | Out-Null
    git bisect good $GoodCommit | Out-Null

    $iteration = 1
    $maxIterations = 50  # Safety limit

    while ($iteration -le $maxIterations) {
        $currentCommit = git rev-parse --short HEAD
        $commitMessage = git log -1 --pretty=%B HEAD

        Write-Host "[$iteration] Testing commit: $currentCommit" -ForegroundColor Cyan
        Write-Host "    Message: $($commitMessage.Split("`n")[0])" -ForegroundColor Gray

        # Run test command with timeout
        $testPassed = $false

        try {
            $process = Start-Process -FilePath "powershell.exe" `
                -ArgumentList "-NoProfile", "-Command", $TestCommand `
                -NoNewWindow `
                -PassThru `
                -RedirectStandardOutput "bisect-test-output.txt" `
                -RedirectStandardError "bisect-test-error.txt"

            $completed = $process.WaitForExit($Timeout * 1000)

            if (-not $completed) {
                Write-Host "    ⏱️  TIMEOUT" -ForegroundColor Yellow
                $process.Kill()
                $testPassed = $false
            } else {
                $testPassed = ($process.ExitCode -eq 0)
            }
        } catch {
            Write-Host "    ❌ ERROR: $_" -ForegroundColor Red
            $testPassed = $false
        }

        if ($testPassed) {
            Write-Host "    ✅ GOOD" -ForegroundColor Green
            $bisectOutput = git bisect good 2>&1
        } else {
            Write-Host "    ❌ BAD" -ForegroundColor Red
            $bisectOutput = git bisect bad 2>&1
        }

        # Check if bisect is done
        if ($bisectOutput -match "is the first bad commit") {
            Write-Host ""
            Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "  FOUND FIRST BAD COMMIT!" -ForegroundColor Red
            Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
            Write-Host ""

            $firstBadCommit = git rev-parse --short HEAD
            $firstBadMessage = git log -1 --pretty=%B HEAD
            $firstBadAuthor = git log -1 --pretty=%an HEAD
            $firstBadDate = git log -1 --pretty=%ad HEAD

            Write-Host "Commit: $firstBadCommit" -ForegroundColor Yellow
            Write-Host "Author: $firstBadAuthor" -ForegroundColor Gray
            Write-Host "Date:   $firstBadDate" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Message:" -ForegroundColor Yellow
            Write-Host $firstBadMessage -ForegroundColor White
            Write-Host ""

            # Show diff
            Write-Host "Changed files:" -ForegroundColor Yellow
            git diff-tree --no-commit-id --name-only -r HEAD | ForEach-Object {
                Write-Host "  $_" -ForegroundColor Gray
            }

            Write-Host ""
            Write-Host "Full diff: git show $firstBadCommit" -ForegroundColor Cyan

            break
        }

        $iteration++
    }

    if ($iteration -gt $maxIterations) {
        Write-Host "⚠️  Reached max iterations limit" -ForegroundColor Yellow
    }

} finally {
    # Clean up
    git bisect reset 2>$null | Out-Null
    if (Test-Path "bisect-test-output.txt") { Remove-Item "bisect-test-output.txt" }
    if (Test-Path "bisect-test-error.txt") { Remove-Item "bisect-test-error.txt" }
    Pop-Location
}

Write-Host ""
Write-Host "Bisect session complete" -ForegroundColor Green
