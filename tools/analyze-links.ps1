<#
.SYNOPSIS
    Analyze and categorize broken documentation links.

.DESCRIPTION
    Scans markdown files for broken links and categorizes them as:
    - Template placeholders (intentional, ignore)
    - Archive references (low priority)
    - Actual broken links (should fix)

.PARAMETER Path
    Directory to scan (default: C:\scripts)

.PARAMETER ShowAll
    Show all link categories, not just actionable ones

.EXAMPLE
    .\analyze-links.ps1
    .\analyze-links.ps1 -ShowAll
    .\analyze-links.ps1 -Path "C:\scripts\_machine"
#>

param(
    [string]$Path = "C:\scripts",
    [switch]$ShowAll
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


Write-Host ""
Write-Host "=== LINK ANALYZER ===" -ForegroundColor Cyan
Write-Host ""

# Exclude node_modules directories
$files = Get-ChildItem $Path -Filter "*.md" -Recurse |
    Where-Object { $_.FullName -notmatch 'node_modules' }

$categories = @{
    TemplatePlaceholder = @()
    ArchiveReference = @()
    ExternalProject = @()
    ActualBroken = @()
}

# Template/placeholder patterns to ignore
$placeholderPatterns = @(
    '^\[.+\]\(url\)$',
    '^\[.+\]\(link\)$',
    '^\[.+\]\(link-to-.+\)$',
    '^\[.+\]\(\[.+\]\)$',  # [Method]([params])
    '^\[alt\]\(url\)$',
    '^\[anything\]\(url\)$',
    '^\[Any text here\]\(url\)$',
    '^\[Generated Image\]\(url\)$',
    '^\[Eenvoudig huis\]\(url\)$'
)

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    $relativePath = $file.FullName.Replace($Path, "").TrimStart("\")
    $isArchive = $relativePath -match "archive|_archive"

    # Remove code blocks before analyzing (they contain example links)
    $contentWithoutCodeBlocks = $content -replace '```[\s\S]*?```', ''

    # Find all markdown links
    $linkMatches = [regex]::Matches($contentWithoutCodeBlocks, '\[([^\]]+)\]\(([^\)]+)\)')

    foreach ($match in $linkMatches) {
        $linkText = $match.Groups[1].Value
        $linkTarget = $match.Groups[2].Value
        $fullLink = $match.Value

        # Skip external URLs
        if ($linkTarget -match '^https?://') { continue }

        # Skip anchor links
        if ($linkTarget -match '^#') { continue }

        # Check if it's a placeholder
        $isPlaceholder = $false
        foreach ($pattern in $placeholderPatterns) {
            if ($fullLink -match $pattern) {
                $isPlaceholder = $true
                break
            }
        }

        if ($isPlaceholder) {
            $categories.TemplatePlaceholder += @{
                File = $relativePath
                Link = $fullLink
            }
            continue
        }

        # Resolve the target path
        $basePath = Split-Path $file.FullName -Parent
        try {
            # Skip malformed URLs or special characters
            if ($linkTarget -match '[<>]|mailto:') { continue }

            $targetPath = if ($linkTarget -match '^\.\.?/') {
                [System.IO.Path]::GetFullPath((Join-Path $basePath $linkTarget))
            } else {
                Join-Path $basePath $linkTarget
            }

            # Remove anchor from path
            $targetPath = $targetPath -replace '#.*$', ''

            # Check if target exists
            if ($targetPath -and (Test-Path $targetPath -ErrorAction SilentlyContinue)) { continue }
        } catch {
            # Skip problematic paths
            continue
        }

        # Categorize broken link
        if ($isArchive) {
            $categories.ArchiveReference += @{
                File = $relativePath
                Link = $fullLink
                Target = $linkTarget
            }
        } elseif ($linkTarget -match '^\.\./client-manager|^\.\./hazina') {
            $categories.ExternalProject += @{
                File = $relativePath
                Link = $fullLink
                Target = $linkTarget
            }
        } else {
            $categories.ActualBroken += @{
                File = $relativePath
                Link = $fullLink
                Target = $linkTarget
            }
        }
    }
}

# Report
Write-Host "LINK CATEGORIES:" -ForegroundColor Yellow
Write-Host ""

if ($ShowAll -and $categories.TemplatePlaceholder.Count -gt 0) {
    Write-Host "TEMPLATE PLACEHOLDERS (ignore): $($categories.TemplatePlaceholder.Count)" -ForegroundColor DarkGray
    $categories.TemplatePlaceholder | Select-Object -First 5 | ForEach-Object {
        Write-Host "  $($_.File): $($_.Link)" -ForegroundColor DarkGray
    }
    if ($categories.TemplatePlaceholder.Count -gt 5) {
        Write-Host "  ... and $($categories.TemplatePlaceholder.Count - 5) more" -ForegroundColor DarkGray
    }
    Write-Host ""
}

if ($ShowAll -and $categories.ArchiveReference.Count -gt 0) {
    Write-Host "ARCHIVE REFERENCES (low priority): $($categories.ArchiveReference.Count)" -ForegroundColor DarkGray
    $categories.ArchiveReference | Select-Object -First 5 | ForEach-Object {
        Write-Host "  $($_.File): $($_.Target)" -ForegroundColor DarkGray
    }
    if ($categories.ArchiveReference.Count -gt 5) {
        Write-Host "  ... and $($categories.ArchiveReference.Count - 5) more" -ForegroundColor DarkGray
    }
    Write-Host ""
}

if ($categories.ExternalProject.Count -gt 0) {
    Write-Host "EXTERNAL PROJECT REFERENCES: $($categories.ExternalProject.Count)" -ForegroundColor Yellow
    $categories.ExternalProject | ForEach-Object {
        Write-Host "  $($_.File): $($_.Target)" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($categories.ActualBroken.Count -gt 0) {
    Write-Host "ACTUAL BROKEN LINKS (should fix): $($categories.ActualBroken.Count)" -ForegroundColor Red
    $categories.ActualBroken | ForEach-Object {
        Write-Host "  $($_.File): $($_.Target)" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SUMMARY:" -ForegroundColor Cyan
Write-Host "  Template placeholders: $($categories.TemplatePlaceholder.Count) (ignore)" -ForegroundColor DarkGray
Write-Host "  Archive references: $($categories.ArchiveReference.Count) (low priority)" -ForegroundColor DarkGray
Write-Host "  External project refs: $($categories.ExternalProject.Count) (external)" -ForegroundColor Yellow
Write-Host "  Actual broken links: $($categories.ActualBroken.Count) (fix these)" -ForegroundColor $(if ($categories.ActualBroken.Count -gt 0) { "Red" } else { "Green" })
Write-Host ""
