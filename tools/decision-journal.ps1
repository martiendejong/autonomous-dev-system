<#
.SYNOPSIS
    Decision Journal - Log decisions with context for future reference.
    50-Expert Council Improvement #25 | Priority: 2.67

.DESCRIPTION
    Systematically log significant decisions with:
    - Context and alternatives considered
    - Reasoning and expert perspectives
    - Outcome tracking

.PARAMETER Decision
    The decision made.

.PARAMETER Context
    Context and situation.

.PARAMETER Alternatives
    Alternatives considered.

.PARAMETER Reasoning
    Why this decision was made.

.PARAMETER List
    List recent decisions.

.PARAMETER Review
    Review past decision outcomes.

.EXAMPLE
    decision-journal.ps1 -Decision "Use worktree workflow" -Context "Multi-agent development" -Reasoning "Prevents conflicts"
#>

param(
    [string]$Decision = "",
    [string]$Context = "",
    [string]$Alternatives = "",
    [string]$Reasoning = "",
    [switch]$List,
    [switch]$Review
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$JournalFile = "C:\scripts\_machine\decision_journal.json"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if (-not (Test-Path $JournalFile)) {
    @{ decisions = @() } | ConvertTo-Json | Set-Content $JournalFile -Encoding UTF8
}

$journal = Get-Content $JournalFile -Raw | ConvertFrom-Json

if ($Decision) {
    $entry = @{
        id = [guid]::NewGuid().ToString().Substring(0, 8)
        decision = $Decision
        context = $Context
        alternatives = $Alternatives
        reasoning = $Reasoning
        timestamp = $Timestamp
        outcome = $null
        reviewed = $false
    }

    $journal.decisions += $entry
    $journal | ConvertTo-Json -Depth 10 | Set-Content $JournalFile -Encoding UTF8

    Write-Host "=== DECISION LOGGED ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Decision: $Decision" -ForegroundColor Yellow
    Write-Host "Context: $Context" -ForegroundColor White
    Write-Host "Alternatives: $Alternatives" -ForegroundColor Gray
    Write-Host "Reasoning: $Reasoning" -ForegroundColor Green
    Write-Host ""
    Write-Host "ID: $($entry.id) (use for outcome review)" -ForegroundColor Gray
}
elseif ($List) {
    Write-Host "=== RECENT DECISIONS ===" -ForegroundColor Cyan
    Write-Host ""

    $recent = $journal.decisions | Select-Object -Last 10

    foreach ($d in $recent) {
        Write-Host "[$($d.id)] $($d.decision)" -ForegroundColor Yellow
        Write-Host "  Context: $($d.context)" -ForegroundColor Gray
        Write-Host "  Reasoning: $($d.reasoning)" -ForegroundColor White
        Write-Host "  Time: $($d.timestamp)" -ForegroundColor DarkGray
        Write-Host ""
    }
}
elseif ($Review) {
    Write-Host "=== DECISIONS PENDING REVIEW ===" -ForegroundColor Cyan
    Write-Host ""

    $pending = $journal.decisions | Where-Object { -not $_.reviewed }

    if ($pending.Count -eq 0) {
        Write-Host "No decisions pending review." -ForegroundColor Green
    } else {
        foreach ($d in $pending) {
            Write-Host "[$($d.id)] $($d.decision)" -ForegroundColor Yellow
            Write-Host "  Made: $($d.timestamp)" -ForegroundColor Gray
        }
    }
}
else {
    Write-Host "Usage: decision-journal.ps1 -Decision 'what' -Context 'why' -Reasoning 'how'" -ForegroundColor Yellow
    Write-Host "       decision-journal.ps1 -List" -ForegroundColor Yellow
    Write-Host "       decision-journal.ps1 -Review" -ForegroundColor Yellow
}
