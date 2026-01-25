<#
.SYNOPSIS
    Changelog Automator
    50-Expert Council V2 Improvement #30 | Priority: 2.33

.DESCRIPTION
    Generates changelogs from git commits automatically.

.PARAMETER Generate
    Generate changelog.

.PARAMETER Since
    Start point (tag, commit, or date).

.PARAMETER Output
    Output file path.

.EXAMPLE
    changelog-gen.ps1 -Generate -Since "v1.0.0"
    changelog-gen.ps1 -Generate -Since "2026-01-01"
#>

param(
    [switch]$Generate,
    [string]$Since = "",
    [string]$Output = "CHANGELOG.md",
    [string]$RepoPath = "."
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


if ($Generate) {
    Push-Location $RepoPath

    Write-Host "=== CHANGELOG GENERATOR ===" -ForegroundColor Cyan
    Write-Host ""

    # Get commits
    $logCmd = if ($Since) {
        "git log --pretty=format:'%H|%s|%an|%ai' $Since..HEAD"
    } else {
        "git log --pretty=format:'%H|%s|%an|%ai' -100"
    }

    $commits = Invoke-Expression $logCmd 2>&1

    $categories = @{
        "Features" = @()
        "Bug Fixes" = @()
        "Documentation" = @()
        "Refactoring" = @()
        "Tests" = @()
        "Other" = @()
    }

    foreach ($line in $commits -split "`n") {
        if (-not $line) { continue }

        $parts = $line -split '\|'
        if ($parts.Count -lt 4) { continue }

        $hash = $parts[0].Substring(0, 7)
        $subject = $parts[1]
        $author = $parts[2]
        $date = $parts[3]

        $entry = "- $subject ($hash)"

        if ($subject -match '^feat') {
            $categories["Features"] += $entry
        }
        elseif ($subject -match '^fix') {
            $categories["Bug Fixes"] += $entry
        }
        elseif ($subject -match '^docs') {
            $categories["Documentation"] += $entry
        }
        elseif ($subject -match '^refactor') {
            $categories["Refactoring"] += $entry
        }
        elseif ($subject -match '^test') {
            $categories["Tests"] += $entry
        }
        else {
            $categories["Other"] += $entry
        }
    }

    # Generate markdown
    $changelog = @"
# Changelog

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm")
$(if ($Since) { "Since: $Since" } else { "Last 100 commits" })

"@

    foreach ($cat in @("Features", "Bug Fixes", "Documentation", "Refactoring", "Tests", "Other")) {
        if ($categories[$cat].Count -gt 0) {
            $changelog += "`n## $cat`n`n"
            foreach ($entry in $categories[$cat]) {
                $changelog += "$entry`n"
            }
        }
    }

    # Write to file
    Set-Content -Path $Output -Value $changelog -Encoding UTF8

    Write-Host "✓ Changelog generated: $Output" -ForegroundColor Green
    Write-Host ""

    # Summary
    Write-Host "Summary:" -ForegroundColor Magenta
    foreach ($cat in $categories.Keys) {
        if ($categories[$cat].Count -gt 0) {
            Write-Host "  $cat`: $($categories[$cat].Count)" -ForegroundColor White
        }
    }

    Pop-Location
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Generate              Generate changelog" -ForegroundColor White
    Write-Host "  -Since 'v1.0.0'        Start from tag" -ForegroundColor White
    Write-Host "  -Output 'file.md'      Output file" -ForegroundColor White
}
