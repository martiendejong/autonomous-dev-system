# ADR Generator - Architecture Decision Records from PR discussions
# Wave 2 Tool #7 (Ratio: 8.0)

param(
    [Parameter(Mandatory=$false)]
    [string]$PRNumber,

    [Parameter(Mandatory=$false)]
    [string]$Title,

    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "docs/adr"
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Generate-ADR {
    param(
        [string]$PRNumber,
        [string]$Title
    )

    # Get PR details
    $pr = gh pr view $PRNumber --json title,body,comments 2>$null | ConvertFrom-Json

    if (-not $pr) {
        Write-Host "ERROR: PR #$PRNumber not found" -ForegroundColor Red
        exit 1
    }

    # Generate ADR number
    $existingADRs = Get-ChildItem $OutputDir -Filter "*.md" -ErrorAction SilentlyContinue
    $nextNum = ($existingADRs | Measure-Object).Count + 1
    $adrNum = $nextNum.ToString("0000")

    # Generate filename
    $filename = "$adrNum-$(($Title -replace '\s+', '-').ToLower()).md"
    $filepath = Join-Path $OutputDir $filename

    # Extract decision from PR
    $context = $pr.body
    $decision = $pr.title

    # ADR Template
    $adr = @"
# $adrNum. $Title

Date: $(Get-Date -Format "yyyy-MM-dd")

## Status

Accepted

## Context

$context

## Decision

$decision

## Consequences

[Extracted from PR #$PRNumber]

$($pr.body)

## References

- PR #$PRNumber: $(gh pr view $PRNumber --json url -q .url)
"@

    # Create directory if needed
    if (-not (Test-Path $OutputDir)) {
        New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
    }

    # Save ADR
    $adr | Set-Content $filepath -Encoding UTF8

    Write-Host "ADR created: $filepath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Review and edit as needed" -ForegroundColor Cyan

    return $filepath
}

if ($PRNumber) {
    if (-not $Title) {
        $Title = (gh pr view $PRNumber --json title -q .title)
    }
    Generate-ADR -PRNumber $PRNumber -Title $Title
} else {
    Write-Host "Usage: .\adr-generator.ps1 -PRNumber 123 -Title 'Use React Query for state'" -ForegroundColor Yellow
}
