<#
.SYNOPSIS
    Generate changelog from git commits using conventional commits

.DESCRIPTION
    Automatically generates CHANGELOG.md from git history:
    - Parses conventional commits (feat:, fix:, docs:, etc.)
    - Groups by type and scope
    - Links to PRs and issues
    - Detects breaking changes
    - Generates version sections

    Conventional Commit Format:
    <type>(<scope>): <description>

    [optional body]

    [optional footer(s)]

    Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore

.PARAMETER SinceTag
    Generate changelog since this tag (default: last tag)

.PARAMETER ToTag
    Generate changelog up to this tag (default: HEAD)

.PARAMETER OutputFile
    Output file path (default: CHANGELOG.md)

.PARAMETER Format
    Format: markdown (default), json, github-release

.PARAMETER GroupBy
    Group commits by: type (default), scope, author

.EXAMPLE
    # Generate changelog since last release
    .\auto-changelog-generator.ps1

.EXAMPLE
    # Generate for specific version range
    .\auto-changelog-generator.ps1 -SinceTag v1.0.0 -ToTag v2.0.0

.EXAMPLE
    # Generate GitHub release notes
    .\auto-changelog-generator.ps1 -Format github-release

.NOTES
    Value: 9/10 - Eliminates manual changelog writing
    Effort: 1/10 - Git log parsing
    Ratio: 9.0 (TIER S+)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SinceTag = "",

    [Parameter(Mandatory=$false)]
    [string]$ToTag = "HEAD",

    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "CHANGELOG.md",

    [Parameter(Mandatory=$false)]
    [ValidateSet('markdown', 'json', 'github-release')]
    [string]$Format = 'markdown',

    [Parameter(Mandatory=$false)]
    [ValidateSet('type', 'scope', 'author')]
    [string]$GroupBy = 'type'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "📝 Auto Changelog Generator" -ForegroundColor Cyan
Write-Host ""

# Get last tag if SinceTag not specified
if (-not $SinceTag) {
    $SinceTag = git describe --tags --abbrev=0 2>$null
    if (-not $SinceTag) {
        Write-Host "⚠️  No tags found - using all commits" -ForegroundColor Yellow
        $SinceTag = ""
    } else {
        Write-Host "📌 Last tag: $SinceTag" -ForegroundColor Gray
    }
}

# Get commit range
$commitRange = if ($SinceTag) { "$SinceTag..$ToTag" } else { $ToTag }
Write-Host "🔍 Analyzing commits: $commitRange" -ForegroundColor Yellow
Write-Host ""

# Get commits
$commits = git log $commitRange --pretty=format:"%H|%s|%b|%an|%ae|%ad" --date=short

if (-not $commits) {
    Write-Host "✅ No commits found in range" -ForegroundColor Green
    exit 0
}

# Parse commits
$parsedCommits = @()

foreach ($commit in $commits) {
    $parts = $commit -split '\|', 6
    $hash = $parts[0]
    $subject = $parts[1]
    $body = $parts[2]
    $author = $parts[3]
    $email = $parts[4]
    $date = $parts[5]

    # Parse conventional commit
    $conventionalMatch = $subject -match '^(\w+)(?:\(([^)]+)\))?: (.+)$'

    if ($conventionalMatch) {
        $type = $Matches[1]
        $scope = $Matches[2]
        $description = $Matches[3]
    } else {
        $type = "other"
        $scope = ""
        $description = $subject
    }

    # Check for breaking change
    $isBreaking = $body -match 'BREAKING CHANGE:' -or $subject -match '!'

    # Extract PR number
    $prNumber = if ($subject -match '#(\d+)') { $Matches[1] } else { $null }

    # Extract issue numbers
    $issues = [regex]::Matches($body, '#(\d+)') | ForEach-Object { $_.Groups[1].Value }

    $parsedCommits += [PSCustomObject]@{
        Hash = $hash.Substring(0, 7)
        FullHash = $hash
        Type = $type
        Scope = $scope
        Description = $description
        Body = $body
        Author = $author
        Email = $email
        Date = $date
        IsBreaking = $isBreaking
        PRNumber = $prNumber
        Issues = $issues
    }
}

Write-Host "📊 Commits parsed: $($parsedCommits.Count)" -ForegroundColor Gray
Write-Host ""

# Group commits
$grouped = switch ($GroupBy) {
    'type' {
        $parsedCommits | Group-Object Type
    }
    'scope' {
        $parsedCommits | Group-Object Scope
    }
    'author' {
        $parsedCommits | Group-Object Author
    }
}

# Type display names
$typeNames = @{
    feat = "✨ Features"
    fix = "🐛 Bug Fixes"
    docs = "📚 Documentation"
    style = "💄 Styles"
    refactor = "♻️ Code Refactoring"
    perf = "⚡ Performance Improvements"
    test = "✅ Tests"
    build = "🏗️ Build System"
    ci = "👷 CI/CD"
    chore = "🔧 Chores"
    other = "📦 Other Changes"
}

# Generate changelog
$changelog = @()

# Header
$versionNumber = if ($ToTag -eq "HEAD") { "Unreleased" } else { $ToTag }
$releaseDate = Get-Date -Format "yyyy-MM-dd"

$changelog += "# Changelog"
$changelog += ""
$changelog += "## [$versionNumber] - $releaseDate"
$changelog += ""

# Breaking changes section (if any)
$breakingChanges = $parsedCommits | Where-Object { $_.IsBreaking }
if ($breakingChanges.Count -gt 0) {
    $changelog += "### ⚠️ BREAKING CHANGES"
    $changelog += ""
    foreach ($commit in $breakingChanges) {
        $line = "- **$($commit.Description)**"
        if ($commit.PRNumber) {
            $line += " ([#$($commit.PRNumber)])"
        }
        $changelog += $line
    }
    $changelog += ""
}

# Commits by type
foreach ($group in ($grouped | Sort-Object { $typeNames[$_.Name] })) {
    $typeName = $typeNames[$group.Name]
    if (-not $typeName) { $typeName = $group.Name }

    $changelog += "### $typeName"
    $changelog += ""

    foreach ($commit in ($group.Group | Sort-Object Scope, Description)) {
        $line = "- "

        if ($commit.Scope) {
            $line += "**$($commit.Scope):** "
        }

        $line += $commit.Description

        # Add PR link
        if ($commit.PRNumber) {
            $line += " ([#$($commit.PRNumber)])"
        }

        # Add commit hash link
        $line += " ([$($commit.Hash)])"

        $changelog += $line
    }

    $changelog += ""
}

# Contributors
$contributors = $parsedCommits | Select-Object -Unique Author | Measure-Object
$changelog += "### 👥 Contributors"
$changelog += ""
$changelog += "Thank you to all $($contributors.Count) contributors!"
$changelog += ""

$uniqueAuthors = $parsedCommits | Select-Object -Property Author -Unique
foreach ($author in $uniqueAuthors) {
    $changelog += "- @$($author.Author)"
}

$changelogText = $changelog -join "`n"

# Output
switch ($Format) {
    'markdown' {
        # Prepend to existing CHANGELOG.md or create new
        if (Test-Path $OutputFile) {
            $existing = Get-Content $OutputFile -Raw
            # Remove the first "# Changelog" line from new content
            $changelogText = $changelogText -replace '^# Changelog\n', ''
            $changelogText + "`n`n" + $existing | Set-Content $OutputFile -Encoding UTF8
        } else {
            $changelogText | Set-Content $OutputFile -Encoding UTF8
        }

        Write-Host "✅ Changelog generated: $OutputFile" -ForegroundColor Green
        Write-Host ""
        Write-Host "Preview:" -ForegroundColor Cyan
        Write-Host "────────────────────────────────────────" -ForegroundColor Gray
        Write-Host $changelogText
    }
    'json' {
        $parsedCommits | ConvertTo-Json -Depth 10
    }
    'github-release' {
        # Format for GitHub release notes
        $releaseNotes = $changelogText -replace '# Changelog\n', '' -replace "## \[$versionNumber\] - $releaseDate", "## What's Changed"

        Write-Host "GitHub Release Notes:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host $releaseNotes
        Write-Host ""
        Write-Host "To create release:" -ForegroundColor Yellow
        Write-Host "  gh release create $ToTag --notes-file <(echo '$releaseNotes')" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "📈 Statistics:" -ForegroundColor Cyan
Write-Host "  Total commits: $($parsedCommits.Count)" -ForegroundColor Gray
Write-Host "  Features: $(($parsedCommits | Where-Object {$_.Type -eq 'feat'}).Count)" -ForegroundColor Gray
Write-Host "  Bug fixes: $(($parsedCommits | Where-Object {$_.Type -eq 'fix'}).Count)" -ForegroundColor Gray
Write-Host "  Breaking changes: $($breakingChanges.Count)" -ForegroundColor Gray
Write-Host "  Contributors: $($contributors.Count)" -ForegroundColor Gray
