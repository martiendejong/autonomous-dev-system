<#
.SYNOPSIS
    Commit Message AI Generator
    50-Expert Council V2 Improvement #18 | Priority: 2.67

.DESCRIPTION
    Generates perfect commit messages from git diff.
    Follows conventional commit format.

.PARAMETER Generate
    Generate commit message from staged changes.

.PARAMETER Type
    Commit type (feat, fix, docs, refactor, test, chore).

.PARAMETER Scope
    Commit scope (optional).

.PARAMETER Apply
    Apply the generated message (commit).

.EXAMPLE
    commit-ai.ps1 -Generate
    commit-ai.ps1 -Generate -Apply
#>

param(
    [switch]$Generate,
    [string]$Type = "",
    [string]$Scope = "",
    [switch]$Apply,
    [string]$RepoPath = "."
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


function Analyze-Diff {
    param([string]$Diff)

    $analysis = @{
        type = "chore"
        scope = ""
        files = @()
        additions = 0
        deletions = 0
        keywords = @()
    }

    # Count changes
    $analysis.additions = ($Diff | Select-String "^\+" | Measure-Object).Count
    $analysis.deletions = ($Diff | Select-String "^-" | Measure-Object).Count

    # Extract file names
    $files = $Diff | Select-String "^\+\+\+ b/(.+)" | ForEach-Object { $_.Matches.Groups[1].Value }
    $analysis.files = $files

    # Detect type from changes
    $lower = $Diff.ToLower()

    if ($lower -match 'fix|bug|error|issue|crash') {
        $analysis.type = "fix"
        $analysis.keywords += "fix"
    }
    elseif ($lower -match 'add|new|feature|implement') {
        $analysis.type = "feat"
        $analysis.keywords += "feature"
    }
    elseif ($lower -match 'refactor|clean|rename|move') {
        $analysis.type = "refactor"
        $analysis.keywords += "refactor"
    }
    elseif ($lower -match 'test|spec|jest|xunit') {
        $analysis.type = "test"
        $analysis.keywords += "test"
    }
    elseif ($lower -match 'doc|readme|comment|\.md') {
        $analysis.type = "docs"
        $analysis.keywords += "docs"
    }
    elseif ($lower -match 'style|format|lint|prettier') {
        $analysis.type = "style"
        $analysis.keywords += "style"
    }
    elseif ($lower -match 'ci|workflow|pipeline|github') {
        $analysis.type = "ci"
        $analysis.keywords += "ci"
    }
    elseif ($lower -match 'perf|optim|speed|fast') {
        $analysis.type = "perf"
        $analysis.keywords += "performance"
    }

    # Detect scope from files
    if ($files.Count -gt 0) {
        $firstFile = $files[0]
        if ($firstFile -match '^([^/]+)/') {
            $analysis.scope = $matches[1]
        }
        if ($firstFile -match '\.ps1$') { $analysis.scope = "tools" }
        if ($firstFile -match 'test') { $analysis.scope = "tests" }
        if ($firstFile -match 'api|controller') { $analysis.scope = "api" }
        if ($firstFile -match 'component|page') { $analysis.scope = "ui" }
    }

    return $analysis
}

function Generate-Message {
    param($Analysis, [string]$Diff)

    $type = if ($Type) { $Type } else { $Analysis.type }
    $scope = if ($Scope) { $Scope } elseif ($Analysis.scope) { "($($Analysis.scope))" } else { "" }

    # Generate subject line
    $subject = ""

    $fileCount = $Analysis.files.Count
    if ($fileCount -eq 1) {
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Analysis.files[0])
        $subject = "$($Analysis.type) $fileName"
    }
    elseif ($fileCount -le 3) {
        $names = $Analysis.files | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) }
        $subject = "$($Analysis.type) $($names -join ', ')"
    }
    else {
        $subject = "$($Analysis.type) $fileCount files"
    }

    # Add context from keywords
    if ($Analysis.keywords -contains "fix") {
        $subject = "Fix issue in $($Analysis.files[0] | Split-Path -Leaf)"
    }
    elseif ($Analysis.keywords -contains "feature") {
        $subject = "Add new functionality"
    }

    # Build full message
    $header = "$type$scope`: $subject"

    # Ensure max 72 chars
    if ($header.Length -gt 72) {
        $header = $header.Substring(0, 69) + "..."
    }

    $body = @"

Changes:
- Modified $fileCount file(s)
- +$($Analysis.additions) -$($Analysis.deletions) lines

Files:
$($Analysis.files | ForEach-Object { "- $_" } | Select-Object -First 10 | Out-String)
"@

    return @{
        header = $header
        body = $body
        full = "$header`n$body"
    }
}

if ($Generate) {
    Push-Location $RepoPath

    # Get staged diff
    $diff = git diff --cached 2>&1

    if (-not $diff -or $diff -match "fatal:") {
        # Try unstaged
        $diff = git diff 2>&1
    }

    if (-not $diff) {
        Write-Host "No changes to commit." -ForegroundColor Yellow
        Pop-Location
        return
    }

    Write-Host "=== COMMIT MESSAGE AI ===" -ForegroundColor Cyan
    Write-Host ""

    $analysis = Analyze-Diff $diff
    $message = Generate-Message $analysis $diff

    Write-Host "Generated commit message:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  $($message.header)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Analysis:" -ForegroundColor Magenta
    Write-Host "  Type: $($analysis.type)" -ForegroundColor White
    Write-Host "  Scope: $($analysis.scope)" -ForegroundColor White
    Write-Host "  Files: $($analysis.files.Count)" -ForegroundColor White
    Write-Host "  Changes: +$($analysis.additions) -$($analysis.deletions)" -ForegroundColor White
    Write-Host ""

    if ($Apply) {
        git add -A
        git commit -m $message.header
        Write-Host "✓ Committed!" -ForegroundColor Green
    }
    else {
        Write-Host "To apply: commit-ai.ps1 -Generate -Apply" -ForegroundColor Gray
        Write-Host "Or copy: $($message.header)" -ForegroundColor Gray
    }

    Pop-Location
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Generate            Generate commit message" -ForegroundColor White
    Write-Host "  -Generate -Apply     Generate and commit" -ForegroundColor White
    Write-Host "  -Type feat           Override type" -ForegroundColor White
    Write-Host "  -Scope api           Override scope" -ForegroundColor White
}
