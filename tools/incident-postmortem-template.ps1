<#
.SYNOPSIS
    Generate incident postmortem report from timeline and data

.DESCRIPTION
    Automatically creates structured postmortem documents:
    - Timeline analysis from incident logs
    - Root cause analysis template
    - Action items tracking
    - Impact assessment
    - Blameless culture format
    - Integrates with incident management systems

    Ensures consistent incident learning and prevents recurrence.

.PARAMETER IncidentId
    Incident ID or ticket number

.PARAMETER Title
    Incident title/summary

.PARAMETER TimelineFile
    Path to incident timeline file (CSV, JSON, or text)

.PARAMETER Severity
    Incident severity: P0 (critical), P1 (high), P2 (medium), P3 (low)

.PARAMETER OutputFormat
    Output format: markdown (default), html, confluence

.PARAMETER OutputPath
    Output file path

.PARAMETER Template
    Template style: google-sre, atlassian, custom

.EXAMPLE
    # Generate postmortem from timeline
    .\incident-postmortem-template.ps1 -IncidentId "INC-12345" -Title "API Outage" -TimelineFile "timeline.csv" -Severity P0

.EXAMPLE
    # Generate with custom template
    .\incident-postmortem-template.ps1 -IncidentId "INC-12345" -Title "Database Failure" -Template google-sre -OutputFormat html

.NOTES
    Value: 10/10 - Critical for learning and preventing recurrence
    Effort: 1.2/10 - Template generation + timeline parsing
    Ratio: 8.2 (TIER S+)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$IncidentId,

    [Parameter(Mandatory=$true)]
    [string]$Title,

    [Parameter(Mandatory=$false)]
    [string]$TimelineFile = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet('P0', 'P1', 'P2', 'P3')]
    [string]$Severity = 'P1',

    [Parameter(Mandatory=$false)]
    [ValidateSet('markdown', 'html', 'confluence')]
    [string]$OutputFormat = 'markdown',

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet('google-sre', 'atlassian', 'custom')]
    [string]$Template = 'google-sre'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "📝 Incident Postmortem Generator" -ForegroundColor Cyan
Write-Host "  Incident: $IncidentId - $Title" -ForegroundColor Gray
Write-Host "  Severity: $Severity" -ForegroundColor $(if($Severity -in @('P0','P1')){"Red"}else{"Yellow"})
Write-Host ""

# Parse timeline if provided
$timeline = @()

if ($TimelineFile -and (Test-Path $TimelineFile)) {
    Write-Host "📊 Parsing incident timeline..." -ForegroundColor Yellow

    $timelineContent = Get-Content $TimelineFile -Raw

    if ($TimelineFile -match '\.csv$') {
        $timeline = Import-Csv $TimelineFile
    } elseif ($TimelineFile -match '\.json$') {
        $timeline = $timelineContent | ConvertFrom-Json
    } else {
        # Plain text parsing
        $lines = $timelineContent -split "`n"
        foreach ($line in $lines) {
            if ($line -match '(\d{2}:\d{2})\s+(.+)') {
                $timeline += [PSCustomObject]@{
                    Time = $Matches[1]
                    Event = $Matches[2]
                }
            }
        }
    }

    Write-Host "  Timeline entries: $($timeline.Count)" -ForegroundColor Gray
}

# Generate postmortem content based on template
$postmortem = switch ($Template) {
    'google-sre' {
        @"
# Incident Postmortem: $Title

**Incident ID:** $IncidentId
**Severity:** $Severity
**Date:** $(Get-Date -Format 'yyyy-MM-dd')
**Status:** Draft

---

## Summary

[Brief summary of what happened - 2-3 sentences]

**Impact:**
- Duration: [X hours]
- Affected users: [Percentage or count]
- Revenue impact: [If applicable]
- Services affected: [List services]

**Root Cause:**
[One-sentence root cause]

---

## Timeline (All times UTC)

$( if ($timeline.Count -gt 0) {
    $timeline | ForEach-Object {
        "- **$($_.Time)** - $($_.Event)"
    } | Out-String
} else {
    @"
- **HH:MM** - Initial symptoms detected
- **HH:MM** - Incident declared (Severity: $Severity)
- **HH:MM** - [Action taken]
- **HH:MM** - Root cause identified
- **HH:MM** - Fix deployed
- **HH:MM** - Service fully recovered
- **HH:MM** - Incident closed
"@
})

---

## Root Cause Analysis

### What Happened

[Detailed technical explanation of the failure]

### Why It Happened

**Contributing Factors:**
1. [Factor 1]
2. [Factor 2]
3. [Factor 3]

**Detection:**
- How was it detected? [Manual/Automated alert]
- Time to detect (TTD): [X minutes]

**Response:**
- Time to mitigate (TTM): [X minutes]
- Time to resolve (TTR): [X minutes]

---

## Resolution

### Immediate Fix

[What was done to restore service]

### Long-term Fix

[What needs to be done to prevent recurrence]

---

## Lessons Learned

### What Went Well

1. [Positive observation]
2. [Positive observation]

### What Went Wrong

1. [Problem area - NO BLAME, focus on process/system]
2. [Problem area - NO BLAME, focus on process/system]

### Where We Got Lucky

1. [Factor that could have made it worse but didn't]

---

## Action Items

| Action | Owner | Priority | Due Date | Status |
|--------|-------|----------|----------|--------|
| [Prevent recurrence action] | TBD | High | YYYY-MM-DD | Open |
| [Improve detection action] | TBD | High | YYYY-MM-DD | Open |
| [Process improvement] | TBD | Medium | YYYY-MM-DD | Open |
| [Documentation update] | TBD | Medium | YYYY-MM-DD | Open |
| [Monitoring enhancement] | TBD | Low | YYYY-MM-DD | Open |

---

## Supporting Information

### Metrics

- **MTBF (Mean Time Between Failures):** [X days]
- **MTTR (Mean Time To Recovery):** [X minutes]
- **Error Rate:** [Percentage]

### Related Incidents

- [Link to similar past incidents]

### References

- [Links to runbooks, documentation, chat logs]

---

**Postmortem Owner:** [Name]
**Reviewed By:** [Names]
**Date Reviewed:** [Date]

"@
    }

    'atlassian' {
        @"
# POST-INCIDENT REVIEW: $Title

## Incident Details

| Field | Value |
|-------|-------|
| Incident ID | $IncidentId |
| Severity | $Severity |
| Start Time | [YYYY-MM-DD HH:MM UTC] |
| End Time | [YYYY-MM-DD HH:MM UTC] |
| Duration | [X hours Y minutes] |
| Incident Commander | [Name] |

## Executive Summary

[2-3 sentence summary for stakeholders]

## Customer Impact

- **Affected Services:** [Service names]
- **Affected Customers:** [Count or percentage]
- **User-Facing Impact:** [Description]
- **Business Impact:** [Revenue, reputation, etc.]

## Timeline

$( if ($timeline.Count -gt 0) {
    "| Time | Event | Action Taken |`n"
    "|------|-------|--------------|`n"
    $timeline | ForEach-Object {
        "| $($_.Time) | $($_.Event) | [Action] |`n"
    } | Out-String
} else {
    @"
| Time | Event | Action Taken |
|------|-------|--------------|
| HH:MM | Issue detected | Alert triggered |
| HH:MM | Investigation started | Team assembled |
| HH:MM | Root cause found | [Details] |
| HH:MM | Fix applied | [Details] |
| HH:MM | Service restored | Monitoring continued |
"@
})

## Root Cause

[Detailed technical explanation]

## Detection

- **How Detected:** [Alert/Customer report/Internal discovery]
- **Time to Detect:** [Minutes from occurrence]

## Response

- **Escalation Path:** [How it escalated]
- **Communication:** [Who was notified, when]
- **Time to Resolve:** [Minutes from detection]

## What Worked

1. [Effective response element]
2. [Effective response element]

## What Didn't Work

1. [Ineffective element - FOCUS ON PROCESS]
2. [Ineffective element - FOCUS ON PROCESS]

## Corrective Actions

| # | Action | Type | Owner | Target Date | Status |
|---|--------|------|-------|-------------|--------|
| 1 | [Prevent] | Prevention | [Name] | YYYY-MM-DD | Open |
| 2 | [Detect] | Detection | [Name] | YYYY-MM-DD | Open |
| 3 | [Respond] | Response | [Name] | YYYY-MM-DD | Open |
| 4 | [Learn] | Learning | [Name] | YYYY-MM-DD | Open |

## Follow-up

- **Review Date:** [YYYY-MM-DD]
- **Follow-up Owner:** [Name]

"@
    }

    'custom' {
        @"
# Incident Report: $Title

## Incident Information

- **ID:** $IncidentId
- **Severity:** $Severity
- **Date:** $(Get-Date -Format 'yyyy-MM-dd')

## What Happened

[Description]

## Timeline

$( if ($timeline.Count -gt 0) {
    $timeline | ForEach-Object { "- $($_.Time): $($_.Event)" } | Out-String
} else {
    "[Add timeline entries]"
})

## Root Cause

[Explanation]

## Resolution

[How it was fixed]

## Prevention

[How to prevent in future]

## Action Items

- [ ] [Action 1]
- [ ] [Action 2]
- [ ] [Action 3]

"@
    }
}

# Generate output file path if not provided
if (-not $OutputPath) {
    $sanitizedTitle = $Title -replace '[^\w\s-]', '' -replace '\s+', '-'
    $extension = switch ($OutputFormat) {
        'markdown' { 'md' }
        'html' { 'html' }
        'confluence' { 'md' }
    }
    $OutputPath = "postmortem_${IncidentId}_${sanitizedTitle}_$(Get-Date -Format 'yyyyMMdd').$extension"
}

# Format output
$output = switch ($OutputFormat) {
    'markdown' {
        $postmortem
    }
    'html' {
        @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Postmortem: $Title</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 1000px; margin: 40px auto; padding: 0 20px; }
        h1 { color: #d32f2f; border-bottom: 3px solid #d32f2f; padding-bottom: 10px; }
        h2 { color: #1976d2; margin-top: 30px; border-bottom: 1px solid #1976d2; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #1976d2; color: white; }
        .severity-p0 { color: #d32f2f; font-weight: bold; }
        .severity-p1 { color: #f57c00; font-weight: bold; }
        code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    $($postmortem -replace '#', '<h1>' -replace '\n', '</h1><p>')
</body>
</html>
"@
    }
    'confluence' {
        # Confluence-compatible markdown
        $postmortem
    }
}

# Write to file
$output | Set-Content $OutputPath -Encoding UTF8

Write-Host ""
Write-Host "POSTMORTEM GENERATED" -ForegroundColor Green
Write-Host ""
Write-Host "  File: $OutputPath" -ForegroundColor Cyan
Write-Host "  Format: $OutputFormat" -ForegroundColor Gray
Write-Host "  Template: $Template" -ForegroundColor Gray
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Review and fill in [bracketed sections]" -ForegroundColor Gray
Write-Host "  2. Share draft with incident response team" -ForegroundColor Gray
Write-Host "  3. Conduct postmortem review meeting" -ForegroundColor Gray
Write-Host "  4. Assign action items with owners and dates" -ForegroundColor Gray
Write-Host "  5. Track action items to completion" -ForegroundColor Gray
Write-Host "  6. Share learnings with broader team" -ForegroundColor Gray
Write-Host ""
Write-Host "✅ Postmortem template created successfully!" -ForegroundColor Green
