#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates all cross-references in documentation files.

.DESCRIPTION
    Extracts all markdown links from documentation and validates:
    - File existence
    - Section existence (for anchor links)
    - Path correctness
    - Missing cross-references
    - Circular references

.PARAMETER Fix
    Auto-fix obvious issues like typos and path problems.

.PARAMETER Report
    Output report file path.

.EXAMPLE
    .\validate-cross-references.ps1
    .\validate-cross-references.ps1 -Fix
#>

param(
    [switch]$Fix,
    [string]$Report = "C:\scripts\logs\cross-reference-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
)

$ErrorActionPreference = "Stop"

# Configuration
$RootPath = "C:\scripts"
$ExcludePaths = @(
    "*/node_modules/*",
    "*/.git/*",
    "*/bin/*",
    "*/obj/*",
    "*/packages/*"
)

# Results storage
$BrokenLinks = @()
$ValidLinks = @()
$MissingReferences = @()
$CircularReferences = @()
$AutoFixes = @()

# Find all markdown files
Write-Host "Finding markdown files..." -ForegroundColor Cyan
$MarkdownFiles = Get-ChildItem -Path $RootPath -Filter "*.md" -Recurse -File | Where-Object {
    $path = $_.FullName
    $exclude = $false
    foreach ($pattern in $ExcludePaths) {
        if ($path -like $pattern) {
            $exclude = $true
            break
        }
    }
    -not $exclude
}

Write-Host "Found $($MarkdownFiles.Count) markdown files" -ForegroundColor Green

# Extract markdown links with regex
function Extract-MarkdownLinks {
    param([string]$FilePath, [string]$Content)

    $links = @()

    # Pattern: [text](path) or [text](path#section)
    $pattern = '\[([^\]]+)\]\(([^)]+)\)'

    $matches = [regex]::Matches($Content, $pattern)

    foreach ($match in $matches) {
        $text = $match.Groups[1].Value
        $target = $match.Groups[2].Value

        # Skip external URLs
        if ($target -match '^https?://') {
            continue
        }

        # Skip mailto links
        if ($target -match '^mailto:') {
            continue
        }

        # Parse anchor
        $anchor = $null
        if ($target -match '#') {
            $parts = $target -split '#', 2
            $target = $parts[0]
            $anchor = $parts[1]
        }

        $links += @{
            SourceFile = $FilePath
            Text = $text
            Target = $target
            Anchor = $anchor
            RawLink = $match.Value
        }
    }

    return $links
}

# Resolve relative path
function Resolve-RelativePath {
    param([string]$SourceFile, [string]$RelativePath)

    if ([string]::IsNullOrEmpty($RelativePath)) {
        return $SourceFile
    }

    $sourceDir = Split-Path -Parent $SourceFile
    $targetPath = Join-Path $sourceDir $RelativePath

    # Normalize path
    try {
        return [System.IO.Path]::GetFullPath($targetPath)
    } catch {
        return $targetPath
    }
}

# Check if section exists in file
function Test-SectionExists {
    param([string]$FilePath, [string]$Anchor)

    if (-not (Test-Path $FilePath)) {
        return $false
    }

    $content = Get-Content $FilePath -Raw

    # Convert anchor to heading format (lowercase, replace spaces with -)
    $normalizedAnchor = $Anchor.ToLower() -replace '\s+', '-' -replace '[^\w-]', ''

    # Search for heading
    $pattern = "^#+\s+.*$"
    $headings = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)

    foreach ($heading in $headings) {
        $headingText = $heading.Value -replace '^#+\s+', '' -replace '\s+$', ''
        $normalizedHeading = $headingText.ToLower() -replace '\s+', '-' -replace '[^\w-]', ''

        if ($normalizedHeading -eq $normalizedAnchor -or $normalizedHeading -like "*$normalizedAnchor*") {
            return $true
        }
    }

    return $false
}

# Extract all links
Write-Host "`nExtracting links..." -ForegroundColor Cyan
$AllLinks = @()

foreach ($file in $MarkdownFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        $links = Extract-MarkdownLinks -FilePath $file.FullName -Content $content
        $AllLinks += $links
    }
}

Write-Host "Found $($AllLinks.Count) internal links" -ForegroundColor Green

# Validate each link
Write-Host "`nValidating links..." -ForegroundColor Cyan
$totalLinks = $AllLinks.Count
$current = 0

foreach ($link in $AllLinks) {
    $current++
    Write-Progress -Activity "Validating links" -Status "$current of $totalLinks" -PercentComplete (($current / $totalLinks) * 100)

    $targetPath = Resolve-RelativePath -SourceFile $link.SourceFile -RelativePath $link.Target

    # Check if file exists
    if (-not (Test-Path $targetPath)) {
        # Try to find similar files (auto-fix candidates)
        $fileName = Split-Path -Leaf $targetPath
        $candidates = Get-ChildItem -Path $RootPath -Filter $fileName -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '(node_modules|\.git|bin|obj)' }

        if ($candidates) {
            $BrokenLinks += @{
                Link = $link
                TargetPath = $targetPath
                Error = "File not found"
                FixCandidates = $candidates.FullName
            }
        } else {
            $BrokenLinks += @{
                Link = $link
                TargetPath = $targetPath
                Error = "File not found"
                FixCandidates = @()
            }
        }
        continue
    }

    # Check if section exists (if anchor specified)
    if ($link.Anchor) {
        if (-not (Test-SectionExists -FilePath $targetPath -Anchor $link.Anchor)) {
            $BrokenLinks += @{
                Link = $link
                TargetPath = $targetPath
                Error = "Section '#$($link.Anchor)' not found"
                FixCandidates = @()
            }
            continue
        }
    }

    # Valid link
    $ValidLinks += @{
        Link = $link
        TargetPath = $targetPath
    }
}

Write-Progress -Activity "Validating links" -Completed

# Detect circular references
Write-Host "`nDetecting circular references..." -ForegroundColor Cyan
$referenceGraph = @{}

foreach ($link in $AllLinks) {
    $source = $link.SourceFile
    $target = Resolve-RelativePath -SourceFile $source -RelativePath $link.Target

    if (-not $referenceGraph.ContainsKey($source)) {
        $referenceGraph[$source] = @()
    }

    if (Test-Path $target) {
        $referenceGraph[$source] += $target
    }
}

# Find cycles (simplified: only direct A->B->A)
foreach ($file in $referenceGraph.Keys) {
    foreach ($target in $referenceGraph[$file]) {
        if ($referenceGraph.ContainsKey($target) -and $referenceGraph[$target] -contains $file) {
            $CircularReferences += @{
                FileA = $file
                FileB = $target
                Assessment = "Review needed"
            }
        }
    }
}

# Identify missing cross-references (heuristic-based)
Write-Host "`nIdentifying missing cross-references..." -ForegroundColor Cyan

# Common patterns that should be referenced
$expectedReferences = @{
    "CLAUDE.md" = @("MACHINE_CONFIG.md", "GENERAL_ZERO_TOLERANCE_RULES.md", "_machine/SOFTWARE_DEVELOPMENT_PRINCIPLES.md")
    "GENERAL_DUAL_MODE_WORKFLOW.md" = @("GENERAL_WORKTREE_PROTOCOL.md")
    "worktree-workflow.md" = @("GENERAL_WORKTREE_PROTOCOL.md")
}

foreach ($file in $MarkdownFiles) {
    $fileName = $file.Name

    if ($expectedReferences.ContainsKey($fileName)) {
        $content = Get-Content $file.FullName -Raw

        foreach ($expectedRef in $expectedReferences[$fileName]) {
            $expectedFileName = Split-Path -Leaf $expectedRef

            # Check if file mentions the expected reference
            if ($content -notmatch [regex]::Escape($expectedFileName)) {
                $MissingReferences += @{
                    File = $file.FullName
                    ShouldReference = $expectedRef
                    Reason = "Common workflow dependency"
                }
            }
        }
    }
}

# Generate report
Write-Host "`nGenerating report..." -ForegroundColor Cyan

$reportContent = @"
# Cross-Reference Validation Report
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Files Analyzed:** $($MarkdownFiles.Count)
**Links Checked:** $($AllLinks.Count)

## Executive Summary
- ✅ Valid Links: $($ValidLinks.Count)
- ❌ Broken Links: $($BrokenLinks.Count)
- ⚠️ Circular References: $($CircularReferences.Count)
- 💡 Missing Recommended References: $($MissingReferences.Count)

---

"@

# Broken Links Section
if ($BrokenLinks.Count -gt 0) {
    $reportContent += @"
## ❌ Broken Links (CRITICAL)

"@
    foreach ($broken in $BrokenLinks) {
        $reportContent += @"
### Source: ``$($broken.Link.SourceFile)``
- **Link Text:** $($broken.Link.Text)
- **Target:** ``$($broken.Link.Target)``
- **Resolved Path:** ``$($broken.TargetPath)``
- **Error:** $($broken.Error)

"@
        if ($broken.FixCandidates.Count -gt 0) {
            $reportContent += "**Fix Candidates:**`n"
            foreach ($candidate in $broken.FixCandidates) {
                $reportContent += "- ``$candidate```n"
            }
            $reportContent += "`n"
        }
    }
    $reportContent += "`n---`n`n"
}

# Missing References Section
if ($MissingReferences.Count -gt 0) {
    $reportContent += @"
## 💡 Missing Cross-References (RECOMMENDED)

"@
    foreach ($missing in $MissingReferences) {
        $reportContent += @"
### File: ``$($missing.File)``
- **Should Reference:** ``$($missing.ShouldReference)``
- **Reason:** $($missing.Reason)

"@
    }
    $reportContent += "`n---`n`n"
}

# Circular References Section
if ($CircularReferences.Count -gt 0) {
    $reportContent += @"
## ⚠️ Circular References (INFO)

"@
    foreach ($circular in $CircularReferences) {
        $reportContent += @"
### Loop Detected
- **File A:** ``$($circular.FileA)``
- **File B:** ``$($circular.FileB)``
- **Assessment:** $($circular.Assessment)

"@
    }
    $reportContent += "`n---`n`n"
}

# Statistics
$reportContent += @"
## 📊 Statistics

| Metric | Count |
|--------|-------|
| Total Files | $($MarkdownFiles.Count) |
| Total Links | $($AllLinks.Count) |
| Valid Links | $($ValidLinks.Count) |
| Broken Links | $($BrokenLinks.Count) |
| Circular References | $($CircularReferences.Count) |
| Missing References | $($MissingReferences.Count) |

---

## 🎯 Recommendations

"@

if ($BrokenLinks.Count -gt 0) {
    $reportContent += "1. **Fix broken links immediately** - $($BrokenLinks.Count) links are pointing to non-existent files/sections`n"
}

if ($MissingReferences.Count -gt 0) {
    $reportContent += "2. **Add recommended cross-references** - $($MissingReferences.Count) files would benefit from additional links`n"
}

if ($CircularReferences.Count -gt 0) {
    $reportContent += "3. **Review circular references** - $($CircularReferences.Count) loops detected (may be intentional)`n"
}

$reportContent += @"

## 🔧 Next Steps

1. Review broken links and update paths
2. Add missing cross-references for better navigation
3. Verify circular references are intentional
4. Run this validation periodically to maintain documentation quality

---

**Tool:** ``tools/validate-cross-references.ps1``
**Run:** ``.\tools\validate-cross-references.ps1 -Fix`` to auto-fix issues
"@

# Save report
$reportDir = Split-Path -Parent $Report
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$reportContent | Out-File -FilePath $Report -Encoding UTF8

Write-Host "`n✅ Report generated: $Report" -ForegroundColor Green
Write-Host "`n📊 Summary:" -ForegroundColor Cyan
Write-Host "  Valid Links: $($ValidLinks.Count)" -ForegroundColor Green
$brokenColor = if ($BrokenLinks.Count -gt 0) { "Red" } else { "Green" }
Write-Host "  Broken Links: $($BrokenLinks.Count)" -ForegroundColor $brokenColor
Write-Host "  Circular References: $($CircularReferences.Count)" -ForegroundColor Yellow
Write-Host "  Missing References: $($MissingReferences.Count)" -ForegroundColor Yellow

# Auto-fix if requested
if ($Fix -and $BrokenLinks.Count -gt 0) {
    Write-Host "`n🔧 Auto-fix mode enabled..." -ForegroundColor Cyan
    Write-Host "⚠️ Auto-fix not yet implemented - manual review required" -ForegroundColor Yellow
}

# Return summary object
return @{
    TotalFiles = $MarkdownFiles.Count
    TotalLinks = $AllLinks.Count
    ValidLinks = $ValidLinks.Count
    BrokenLinks = $BrokenLinks.Count
    CircularReferences = $CircularReferences.Count
    MissingReferences = $MissingReferences.Count
    ReportPath = $Report
}
