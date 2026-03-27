<#
.SYNOPSIS
    Generates release notes from conventional commits.

.DESCRIPTION
    Parses git commit history using conventional commit format and generates
    formatted release notes grouped by type (features, fixes, chores, etc.).

    Supports conventional commit types:
    - feat: New features
    - fix: Bug fixes
    - docs: Documentation changes
    - style: Code style changes
    - refactor: Code refactoring
    - perf: Performance improvements
    - test: Test additions/changes
    - chore: Maintenance tasks
    - ci: CI/CD changes

.PARAMETER Since
    Git ref to start from (tag, commit, or branch). Default: last tag

.PARAMETER Output
    Output file path (default: CHANGELOG.md)

.PARAMETER Append
    Append to existing CHANGELOG instead of overwriting

.PARAMETER Repo
    Repository path (default: current directory)

.PARAMETER Version
    Version number for this release (e.g., v1.3.0)

.EXAMPLE
    .\generate-release-notes.ps1
    .\generate-release-notes.ps1 -Since "v1.2.0" -Version "v1.3.0"
    .\generate-release-notes.ps1 -Since "develop" -Output "RELEASE_NOTES.md"
#>

param(
    [string]$Since,
    [string]$Output = "CHANGELOG.md",
    [switch]$Append,
    [string]$Repo = ".",
    [string]$Version
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ConventionalCommitTypes = @{
    "feat" = @{ "Title" = "Features"; "Icon" = "[+]" }
    "fix" = @{ "Title" = "Bug Fixes"; "Icon" = "[!]" }
    "docs" = @{ "Title" = "Documentation"; "Icon" = "[D]" }
    "style" = @{ "Title" = "Code Style"; "Icon" = "[S]" }
    "refactor" = @{ "Title" = "Refactoring"; "Icon" = "[R]" }
    "perf" = @{ "Title" = "Performance"; "Icon" = "[P]" }
    "test" = @{ "Title" = "Tests"; "Icon" = "[T]" }
    "chore" = @{ "Title" = "Maintenance"; "Icon" = "[M]" }
    "ci" = @{ "Title" = "CI/CD"; "Icon" = "[C]" }
}

function Get-LastTag {
    param([string]$RepoPath)

    Push-Location $RepoPath
    try {
        $tag = git describe --tags --abbrev=0 2>$null
        if ($tag) {
            return $tag
        }
        # No tags, return first commit
        return git rev-list --max-parents=0 HEAD
    } finally {
        Pop-Location
    }
}

function Parse-ConventionalCommit {
    param([string]$Message)

    # Format: type(scope): description
    if ($Message -match '^(\w+)(\([^\)]+\))?: (.+)$') {
        $type = $matches[1].ToLower()
        $scope = if ($matches[2]) { $matches[2].Trim('(', ')') } else { $null }
        $description = $matches[3]

        # Extract PR number if present
        $prNumber = if ($Message -match '#(\d+)') { $matches[1] } else { $null }

        # Extract breaking change indicator
        $isBreaking = $Message -match 'BREAKING CHANGE' -or $Message -match '!:'

        return @{
            "Type" = $type
            "Scope" = $scope
            "Description" = $description
            "PRNumber" = $prNumber
            "IsBreaking" = $isBreaking
            "OriginalMessage" = $Message
        }
    }

    # Non-conventional commit
    return @{
        "Type" = "other"
        "Scope" = $null
        "Description" = $Message
        "PRNumber" = $null
        "IsBreaking" = $false
        "OriginalMessage" = $Message
    }
}

function Get-Commits {
    param([string]$RepoPath, [string]$FromRef)

    Push-Location $RepoPath
    try {
        $range = if ($FromRef) { "$FromRef..HEAD" } else { "HEAD" }

        $commits = git log $range --pretty=format:"%H|%s|%an|%ae" 2>$null

        if (-not $commits) {
            return @()
        }

        $parsedCommits = @()

        foreach ($commit in $commits) {
            $parts = $commit -split '\|', 4
            if ($parts.Count -lt 2) { continue }

            $hash = $parts[0]
            $message = $parts[1]
            $author = if ($parts.Count -ge 3) { $parts[2] } else { "Unknown" }
            $email = if ($parts.Count -ge 4) { $parts[3] } else { "" }

            $parsed = Parse-ConventionalCommit -Message $message

            $parsedCommits += @{
                "Hash" = $hash.Substring(0, 7)
                "Type" = $parsed.Type
                "Scope" = $parsed.Scope
                "Description" = $parsed.Description
                "PRNumber" = $parsed.PRNumber
                "IsBreaking" = $parsed.IsBreaking
                "Author" = $author
                "Email" = $email
                "Message" = $message
            }
        }

        return $parsedCommits

    } finally {
        Pop-Location
    }
}

function Format-ReleaseNotes {
    param(
        [array]$Commits,
        [string]$VersionNumber,
        [string]$FromRef
    )

    $output = ""

    # Header
    $versionHeader = if ($VersionNumber) { "## $VersionNumber" } else { "## Unreleased" }
    $date = Get-Date -Format "yyyy-MM-dd"

    $output += "$versionHeader - $date`n"
    $output += "`n"

    # Group commits by type
    $groupedCommits = $Commits | Group-Object -Property Type

    # Breaking changes first
    $breakingChanges = $Commits | Where-Object { $_.IsBreaking }
    if ($breakingChanges.Count -gt 0) {
        $output += "### ⚠️ BREAKING CHANGES`n"
        $output += "`n"
        foreach ($commit in $breakingChanges) {
            $line = "- **$($commit.Description)**"
            if ($commit.Scope) { $line += " _($($commit.Scope))_" }
            if ($commit.PRNumber) { $line += " (PR #$($commit.PRNumber))" }
            $output += "$line`n"
        }
        $output += "`n"
    }

    # Process each type
    foreach ($type in @("feat", "fix", "perf", "refactor", "docs", "test", "chore", "ci")) {
        $group = $groupedCommits | Where-Object { $_.Name -eq $type }

        if (-not $group) { continue }

        $typeInfo = $ConventionalCommitTypes[$type]
        $output += "### $($typeInfo.Icon) $($typeInfo.Title)`n"
        $output += "`n"

        foreach ($commit in $group.Group | Where-Object { -not $_.IsBreaking }) {
            $line = "- $($commit.Description)"

            if ($commit.Scope) {
                $line += " _($($commit.Scope))_"
            }

            if ($commit.PRNumber) {
                $line += " (PR #$($commit.PRNumber))"
            }

            $line += " ($($commit.Hash))"

            $output += "$line`n"
        }

        $output += "`n"
    }

    # Other commits (non-conventional)
    $otherCommits = $groupedCommits | Where-Object { $_.Name -eq "other" }
    if ($otherCommits) {
        $output += "### Other Changes`n"
        $output += "`n"
        foreach ($commit in $otherCommits.Group) {
            $output += "- $($commit.Message) ($($commit.Hash))`n"
        }
        $output += "`n"
    }

    # Contributors
    $contributors = $Commits | Select-Object -Property Author -Unique | Sort-Object Author
    if ($contributors.Count -gt 0) {
        $output += "### Contributors`n"
        $output += "`n"
        foreach ($contributor in $contributors) {
            $output += "- $($contributor.Author)`n"
        }
        $output += "`n"
    }

    $output += "---`n"
    $output += "`n"

    return $output
}

# Main execution
Write-Host ""
Write-Host "=== Release Notes Generator ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Repo)) {
    Write-Host "ERROR: Repository not found: $Repo" -ForegroundColor Red
    exit 1
}

# Determine starting ref
$fromRef = if ($Since) {
    $Since
} else {
    $lastTag = Get-LastTag -RepoPath $Repo
    Write-Host "No -Since specified, using last tag: $lastTag" -ForegroundColor DarkGray
    $lastTag
}

Write-Host "Generating release notes..." -ForegroundColor White
Write-Host "  Repository: $Repo" -ForegroundColor DarkGray
Write-Host "  From: $fromRef" -ForegroundColor DarkGray
Write-Host "  To: HEAD" -ForegroundColor DarkGray
Write-Host ""

# Get commits
$commits = Get-Commits -RepoPath $Repo -FromRef $fromRef

if ($commits.Count -eq 0) {
    Write-Host "No commits found in range $fromRef..HEAD" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($commits.Count) commits" -ForegroundColor Green
Write-Host ""

# Group by type for summary
$typeGroups = $commits | Group-Object -Property Type
foreach ($group in $typeGroups | Sort-Object Name) {
    $typeInfo = $ConventionalCommitTypes[$group.Name]
    $typeName = if ($typeInfo) { $typeInfo.Title } else { $group.Name }
    Write-Host ("  {0}: {1}" -f $typeName, $group.Count) -ForegroundColor DarkGray
}
Write-Host ""

# Generate release notes
$releaseNotes = Format-ReleaseNotes -Commits $commits -VersionNumber $Version -FromRef $fromRef

# Write to file
$outputPath = Join-Path $Repo $Output

if ($Append -and (Test-Path $outputPath)) {
    # Read existing content
    $existingContent = Get-Content $outputPath -Raw

    # Prepend new release notes
    $fullContent = $releaseNotes + $existingContent

    $fullContent | Set-Content $outputPath -Encoding UTF8
    Write-Host "Appended to: $outputPath" -ForegroundColor Green
} else {
    # Write header for new changelog
    $header = "# Changelog`n`n"
    $header += "All notable changes to this project will be documented in this file.`n`n"
    $header += "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),`n"
    $header += "and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).`n`n"
    $header += "---`n`n"

    $fullContent = $header + $releaseNotes

    $fullContent | Set-Content $outputPath -Encoding UTF8
    Write-Host "Created: $outputPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Release Notes Generated ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Preview:" -ForegroundColor White
Write-Host ""
Write-Host $releaseNotes
Write-Host ""

exit 0
