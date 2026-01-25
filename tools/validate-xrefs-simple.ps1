#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates cross-references in documentation files.
#>

param(
    [string]$Report = "C:\scripts\logs\cross-reference-validation.md"
)

$ErrorActionPreference = "Stop"

# Configuration
$RootPath = "C:\scripts"
$BrokenLinks = [System.Collections.ArrayList]::new()
$ValidLinks = [System.Collections.ArrayList]::new()

# Find markdown files
Write-Host "Finding markdown files..." -ForegroundColor Cyan
$files = Get-ChildItem -Path $RootPath -Filter "*.md" -Recurse -File |
    Where-Object { $_.FullName -notmatch '(node_modules|\.git|bin|obj|packages)' }

Write-Host "Found $($files.Count) files" -ForegroundColor Green

# Extract and validate links
Write-Host "Extracting links..." -ForegroundColor Cyan
$linkCount = 0

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    # Find markdown links: [text](path)
    $pattern = '\[([^\]]+)\]\(([^)]+)\)'
    $matches = [regex]::Matches($content, $pattern)

    foreach ($match in $matches) {
        $text = $match.Groups[1].Value
        $target = $match.Groups[2].Value

        # Skip external URLs and mailto
        if ($target -match '^(https?://|mailto:)') { continue }

        $linkCount++

        # Parse anchor
        $anchor = $null
        if ($target -match '#') {
            $parts = $target -split '#', 2
            $target = $parts[0]
            $anchor = $parts[1]
        }

        # Resolve path
        if ([string]::IsNullOrEmpty($target)) {
            $targetPath = $file.FullName
        } else {
            $sourceDir = Split-Path -Parent $file.FullName
            $targetPath = Join-Path $sourceDir $target
            try {
                $targetPath = [System.IO.Path]::GetFullPath($targetPath)
            } catch {
                # Keep original if normalization fails
            }
        }

        # Check if file exists
        if (-not (Test-Path $targetPath)) {
            [void]$BrokenLinks.Add(@{
                SourceFile = $file.FullName.Replace('C:\scripts\', '')
                Text = $text
                Target = $target
                ResolvedPath = $targetPath.Replace('C:\scripts\', '')
                Error = "File not found"
            })
        } else {
            [void]$ValidLinks.Add($true)
        }
    }
}

Write-Host "Checked $linkCount links" -ForegroundColor Green

# Generate report
$reportContent = "# Cross-Reference Validation Report`n"
$reportContent += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
$reportContent += "**Files:** $($files.Count) | **Links:** $linkCount`n`n"
$reportContent += "## Summary`n"
$reportContent += "- Valid Links: $($ValidLinks.Count)`n"
$reportContent += "- Broken Links: $($BrokenLinks.Count)`n`n"

if ($BrokenLinks.Count -gt 0) {
    $reportContent += "## Broken Links`n`n"
    foreach ($broken in $BrokenLinks) {
        $reportContent += "### Source: ``$($broken.SourceFile)```n"
        $reportContent += "- **Text:** $($broken.Text)`n"
        $reportContent += "- **Target:** ``$($broken.Target)```n"
        $reportContent += "- **Resolved:** ``$($broken.ResolvedPath)```n"
        $reportContent += "- **Error:** $($broken.Error)`n`n"
    }
}

# Save report
$reportDir = Split-Path -Parent $Report
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$reportContent | Out-File -FilePath $Report -Encoding UTF8

Write-Host "`nReport saved: $Report" -ForegroundColor Green
Write-Host "Valid: $($ValidLinks.Count) | Broken: $($BrokenLinks.Count)" -ForegroundColor $(if ($BrokenLinks.Count -gt 0) { "Red" } else { "Green" })
