#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Analyzes cross-reference validation results and categorizes issues.
#>

param(
    [string]$InputReport = "C:\scripts\logs\cross-reference-validation.md",
    [string]$OutputReport = "C:\scripts\logs\cross-reference-analysis.md"
)

$ErrorActionPreference = "Stop"

# Read validation report
$content = Get-Content $InputReport -Raw

# Extract broken links
$brokenSections = ($content -split '### Source:') | Select-Object -Skip 1

$issues = @{
    PlaceholderLinks = @()  # [link](url), [text](link)
    MissingFiles = @()       # Actual missing .md files
    WrongPaths = @()         # Wrong relative paths
    ExternalRepos = @()      # Links to ../client-manager, ../hazina
    TemplateArtifacts = @()  # Template placeholders like [params]
}

foreach ($section in $brokenSections) {
    $lines = $section -split "`n"
    $source = ($lines[0] -replace '`', '').Trim()
    $target = ""
    $text = ""

    foreach ($line in $lines) {
        if ($line -match '\*\*Text:\*\*\s+(.+)') {
            $text = $matches[1]
        }
        if ($line -match '\*\*Target:\*\*\s+`([^`]+)`') {
            $target = $matches[1]
        }
    }

    $issue = @{
        Source = $source
        Target = $target
        Text = $text
    }

    # Categorize
    $target = $target.Trim()
    if ($target -eq 'url' -or $target -eq 'link') {
        $issues.PlaceholderLinks += $issue
    }
    elseif ($target -match '^\[.*\]$') {
        $issues.TemplateArtifacts += $issue
    }
    elseif ($target -match '\.\./client-manager' -or $target -match '\.\./hazina') {
        $issues.ExternalRepos += $issue
    }
    elseif ($target -match '\.\./|^\./') {
        $issues.WrongPaths += $issue
    }
    else {
        $issues.MissingFiles += $issue
    }
}

# Generate analysis report
$report = @"
# Cross-Reference Analysis Report
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Source:** ``$InputReport``

## Executive Summary

| Category | Count | Priority | Action Required |
|----------|-------|----------|-----------------|
| Placeholder Links | $($issues.PlaceholderLinks.Count) | LOW | Clean up or replace with real links |
| Template Artifacts | $($issues.TemplateArtifacts.Count) | LOW | Normal for templates |
| External Repo Links | $($issues.ExternalRepos.Count) | **HIGH** | Update paths or document |
| Wrong Relative Paths | $($issues.WrongPaths.Count) | **CRITICAL** | Fix immediately |
| Missing Files | $($issues.MissingFiles.Count) | **HIGH** | Create files or remove links |

**Total Issues:** $(($issues.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum)

---

## 1. Placeholder Links (LOW PRIORITY)

These are links using placeholder text like ``[text](url)`` or ``[text](link)``.
**Action:** Review and either add real URLs or remove.

"@

if ($issues.PlaceholderLinks.Count -gt 0) {
    $grouped = $issues.PlaceholderLinks | Group-Object Source
    foreach ($group in $grouped) {
        $report += "`n### ``$($group.Name)`` ($($group.Count) links)`n"
        foreach ($item in $group.Group) {
            $report += "- [x] Link text: **$($item.Text)**`n"
        }
    }
}

$report += @"

---

## 2. Template Artifacts (LOW PRIORITY)

These are placeholders in templates like ``[MethodName]([params])``.
**Action:** None required - these are normal template syntax.

"@

if ($issues.TemplateArtifacts.Count -gt 0) {
    foreach ($item in $issues.TemplateArtifacts) {
        $report += "- ``$($item.Source)`` → ``$($item.Target)```n"
    }
}

$report += @"

---

## 3. External Repository Links (HIGH PRIORITY)

These link to ``../client-manager`` or ``../hazina`` which don't exist relative to C:\scripts.
**Action:** Update to absolute paths or add note that repos must be cloned.

"@

if ($issues.ExternalRepos.Count -gt 0) {
    $grouped = $issues.ExternalRepos | Group-Object Target
    foreach ($group in $grouped) {
        $report += "`n### Target: ``$($group.Name)`` ($($group.Count) references)`n"
        $report += "**Referenced in:**`n"
        foreach ($item in $group.Group) {
            $report += "- ``$($item.Source)```n"
        }
        $report += "`n**Fix:**`n"
        if ($group.Name -match 'client-manager') {
            $report += "- Update to: ``C:\Projects\client-manager\...``  OR`n"
            $report += "- Add note: *Requires client-manager repository cloned at C:\Projects\client-manager*`n"
        }
        elseif ($group.Name -match 'hazina') {
            $report += "- Update to: ``C:\Projects\hazina\...``  OR`n"
            $report += "- Add note: *Requires hazina repository cloned at C:\Projects\hazina*`n"
        }
    }
}

$report += @"

---

## 4. Wrong Relative Paths (CRITICAL)

These use relative paths that resolve incorrectly.
**Action:** Fix immediately.

"@

if ($issues.WrongPaths.Count -gt 0) {
    foreach ($item in $issues.WrongPaths) {
        $report += "`n### Source: ``$($item.Source)```n"
        $report += "- **Current:** ``$($item.Target)```n"

        # Try to suggest fixes
        $fileName = Split-Path -Leaf $item.Target
        if ($fileName -match '\.md$') {
            $report += "- **File:** ``$fileName```n"
            $report += "- **Action:** Search for this file and update path`n"
        }
    }
}

$report += @"

---

## 5. Missing Files (HIGH PRIORITY)

These files are referenced but don't exist.
**Action:** Either create the files or remove the references.

"@

if ($issues.MissingFiles.Count -gt 0) {
    foreach ($item in $issues.MissingFiles) {
        $report += "`n### ``$($item.Target)```n"
        $report += "- **Referenced in:** ``$($item.Source)```n"
        $report += "- **Link text:** $($item.Text)`n"
    }
}

$report += @"

---

## Recommended Actions

### Immediate (CRITICAL)
1. Fix all wrong relative paths in section 4
2. Review external repo links and update documentation

### High Priority
1. Create missing files or remove references (section 5)
2. Document external repository dependencies

### Low Priority
1. Clean up placeholder links (section 1)
2. Template artifacts are OK to ignore

---

## Tool Commands

``````powershell
# Re-run validation
.\tools\validate-xrefs-simple.ps1

# Re-run analysis
.\tools\analyze-xrefs.ps1
``````

"@

# Save report
$reportDir = Split-Path -Parent $OutputReport
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$report | Out-File -FilePath $OutputReport -Encoding UTF8

Write-Host "`nAnalysis complete!" -ForegroundColor Green
Write-Host "Report: $OutputReport" -ForegroundColor Cyan
Write-Host "`nSummary:" -ForegroundColor Yellow
Write-Host "  Placeholder Links: $($issues.PlaceholderLinks.Count) (LOW)" -ForegroundColor Gray
Write-Host "  Template Artifacts: $($issues.TemplateArtifacts.Count) (LOW)" -ForegroundColor Gray
Write-Host "  External Repos: $($issues.ExternalRepos.Count) (HIGH)" -ForegroundColor Yellow
Write-Host "  Wrong Paths: $($issues.WrongPaths.Count) (CRITICAL)" -ForegroundColor Red
Write-Host "  Missing Files: $($issues.MissingFiles.Count) (HIGH)" -ForegroundColor Yellow
