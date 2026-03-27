<#
.SYNOPSIS
    Validates documentation files for common issues.

.DESCRIPTION
    Checks markdown documentation for:
    - Broken internal links
    - Missing required sections
    - Outdated dates
    - Inconsistent formatting
    - Empty files

.PARAMETER Path
    Path to scan (default: C:\scripts)

.PARAMETER Fix
    Attempt to auto-fix simple issues

.EXAMPLE
    .\doc-lint.ps1
    .\doc-lint.ps1 -Path "C:\scripts\tools"
    .\doc-lint.ps1 -Fix
#>

param(
    [string]$Path = "C:\scripts",
    [switch]$Fix
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$Issues = @{
    errors = @()
    warnings = @()
    fixed = @()
}

function Test-BrokenLinks {
    param([string]$FilePath, [string]$Content)

    $links = [regex]::Matches($Content, '\[([^\]]+)\]\(([^)]+)\)')

    foreach ($link in $links) {
        $linkText = $link.Groups[1].Value
        $linkPath = $link.Groups[2].Value

        # Skip external links
        if ($linkPath -match '^https?://') { continue }
        # Skip anchors
        if ($linkPath -match '^#') { continue }
        # Skip mailto
        if ($linkPath -match '^mailto:') { continue }

        # Resolve relative path
        $baseDir = Split-Path $FilePath
        $resolvedPath = Join-Path $baseDir $linkPath

        if (-not (Test-Path $resolvedPath)) {
            $Issues.errors += "Broken link in $($FilePath): [$linkText]($linkPath)"
        }
    }
}

function Test-RequiredSections {
    param([string]$FilePath, [string]$Content)

    $fileName = Split-Path $FilePath -Leaf

    # CLAUDE.md should have specific sections
    if ($fileName -eq "CLAUDE.md") {
        $required = @("Core Principle", "Documentation Structure", "Quick Start")
        foreach ($section in $required) {
            if ($Content -notmatch "(?i)##.*$section") {
                $Issues.warnings += "Missing section in CLAUDE.md: $section"
            }
        }
    }

    # README files should have description
    if ($fileName -match "README\.md$") {
        if ($Content.Length -lt 100) {
            $Issues.warnings += "README too short: $FilePath"
        }
    }
}

function Test-OutdatedDates {
    param([string]$FilePath, [string]$Content)

    # Check for "Last Updated" dates older than 30 days
    if ($Content -match 'Last Updated[:\s]+(\d{4}-\d{2}-\d{2})') {
        $date = [DateTime]::ParseExact($matches[1], "yyyy-MM-dd", $null)
        $age = (Get-Date) - $date
        if ($age.Days -gt 30) {
            $Issues.warnings += "Outdated 'Last Updated' in $FilePath ($($matches[1]))"
        }
    }
}

function Test-EmptyFiles {
    param([string]$FilePath, [string]$Content)

    if ($Content.Trim().Length -lt 10) {
        $Issues.errors += "Empty or near-empty file: $FilePath"
    }
}

function Test-Formatting {
    param([string]$FilePath, [string]$Content)

    # Check for consistent heading style
    if ($Content -match '^#[^#\s]') {
        $Issues.warnings += "Missing space after # in heading: $FilePath"
    }

    # Check for trailing whitespace
    if ($Content -match '\s+$') {
        $Issues.warnings += "Trailing whitespace: $FilePath"
    }
}

# Main execution
Write-Host ""
Write-Host "=== DOCUMENTATION LINTER ===" -ForegroundColor Cyan
Write-Host "Path: $Path" -ForegroundColor DarkGray
Write-Host ""

$files = Get-ChildItem -Path $Path -Filter "*.md" -Recurse |
    Where-Object { $_.FullName -notmatch "node_modules|\.git" }

Write-Host "Scanning $($files.Count) markdown files..." -ForegroundColor DarkGray
Write-Host ""

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    Test-BrokenLinks -FilePath $file.FullName -Content $content
    Test-RequiredSections -FilePath $file.FullName -Content $content
    Test-OutdatedDates -FilePath $file.FullName -Content $content
    Test-EmptyFiles -FilePath $file.FullName -Content $content
    Test-Formatting -FilePath $file.FullName -Content $content
}

# Report
if ($Issues.errors.Count -gt 0) {
    Write-Host "ERRORS ($($Issues.errors.Count)):" -ForegroundColor Red
    $Issues.errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host ""
}

if ($Issues.warnings.Count -gt 0) {
    Write-Host "WARNINGS ($($Issues.warnings.Count)):" -ForegroundColor Yellow
    $Issues.warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host ""
}

if ($Issues.errors.Count -eq 0 -and $Issues.warnings.Count -eq 0) {
    Write-Host "ALL CHECKS PASSED" -ForegroundColor Green
} else {
    Write-Host "Summary: $($Issues.errors.Count) errors, $($Issues.warnings.Count) warnings" -ForegroundColor White
}

Write-Host ""
