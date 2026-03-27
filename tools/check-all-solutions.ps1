<#
.SYNOPSIS
    Checks all solutions across multiple repositories for missing projects.

.DESCRIPTION
    Scans all configured repositories and their solution files to detect
    projects that are not included in their respective solutions.

.PARAMETER AutoFix
    Automatically fix all detected issues

.PARAMETER RepoPath
    Specific repository path to check (defaults to all in C:\Projects)

.EXAMPLE
    .\check-all-solutions.ps1

.EXAMPLE
    .\check-all-solutions.ps1 -AutoFix

.EXAMPLE
    .\check-all-solutions.ps1 -RepoPath "C:\Projects\hazina"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$AutoFix,

    [Parameter(Mandatory = $false)]
    [string]$RepoPath
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$scriptPath = Join-Path $PSScriptRoot "detect-missing-projects.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "Error: detect-missing-projects.ps1 not found at $scriptPath" -ForegroundColor Red
    exit 1
}

# Determine which repositories to check
if ([string]::IsNullOrEmpty($RepoPath)) {
    $repositories = @(
        "C:\Projects\hazina",
        "C:\Projects\client-manager"
    ) | Where-Object { Test-Path $_ }
} else {
    if (-not (Test-Path $RepoPath)) {
        Write-Host "Error: Repository path not found: $RepoPath" -ForegroundColor Red
        exit 1
    }
    $repositories = @($RepoPath)
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Checking All Solutions for Missing Projects" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$totalIssues = 0
$results = @()

foreach ($repo in $repositories) {
    $repoName = Split-Path $repo -Leaf

    Write-Host "Checking repository: $repoName" -ForegroundColor White
    Write-Host "Path: $repo" -ForegroundColor DarkGray
    Write-Host ""

    # Find all solution files in this repo
    $solutions = Get-ChildItem -Path $repo -Filter "*.sln" -File

    if ($solutions.Count -eq 0) {
        Write-Host "  No solution files found" -ForegroundColor Yellow
        Write-Host ""
        continue
    }

    foreach ($sln in $solutions) {
        Write-Host "  Solution: $($sln.Name)" -ForegroundColor Cyan

        $params = @{
            SolutionPath = $sln.FullName
            RepositoryPath = $repo
        }

        if ($AutoFix) {
            $params['AutoFix'] = $true
        }

        # Run detection script
        $output = & $scriptPath @params 2>&1
        $hadIssues = $LASTEXITCODE -ne 0

        # Parse output to get issue count
        $issueCount = 0
        if ($output -match 'Found (\d+) missing project') {
            $issueCount = [int]$matches[1]
            $totalIssues += $issueCount
        }

        $results += [PSCustomObject]@{
            Repository = $repoName
            Solution = $sln.Name
            IssuesFound = $issueCount
            Fixed = $AutoFix -and $hadIssues
        }

        if ($hadIssues) {
            Write-Host "    [!] Issues detected" -ForegroundColor Red
            if ($AutoFix) {
                Write-Host "    [+] Auto-fixed" -ForegroundColor Green
            }
        } else {
            Write-Host "    [+] OK" -ForegroundColor Green
        }

        Write-Host ""
    }
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -AutoSize

if ($totalIssues -eq 0) {
    Write-Host "[+] No issues found across all repositories!" -ForegroundColor Green
    exit 0
} else {
    if ($AutoFix) {
        Write-Host "[+] Fixed $totalIssues issue(s) across all repositories" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "[!] Found $totalIssues total issue(s)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Run with -AutoFix to automatically fix all issues" -ForegroundColor Cyan
        exit 1
    }
}
