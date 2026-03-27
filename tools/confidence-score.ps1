<#
.SYNOPSIS
    Understanding Confidence Score & Expertise Tracking
    50-Expert Council Improvements #50, #28, #27 | Priority: 2.0, 1.75, 1.11

.DESCRIPTION
    Reports how well Claude understands current request.
    Tracks domain expertise growth and identifies gaps.

.PARAMETER Request
    Analyze understanding of this request.

.PARAMETER Domain
    Track expertise in domain.

.PARAMETER Level
    Expertise level (1-10).

.PARAMETER ShowExpertise
    Show all tracked expertise.

.PARAMETER Gaps
    Show expertise gaps.

.EXAMPLE
    confidence-score.ps1 -Request "Implement OAuth for the API"
    confidence-score.ps1 -Domain "authentication" -Level 8
#>

param(
    [string]$Request = "",
    [string]$Domain = "",
    [int]$Level = 0,
    [switch]$ShowExpertise,
    [switch]$Gaps
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ExpertiseFile = "C:\scripts\_machine\expertise_tracking.json"

if (-not (Test-Path $ExpertiseFile)) {
    @{
        domains = @{
            "csharp" = @{ level = 9; experience = "20+ years" }
            "react" = @{ level = 8; experience = "4+ years" }
            "ef-core" = @{ level = 8; experience = "Entity Framework migrations" }
            "git-worktrees" = @{ level = 9; experience = "Advanced workflows" }
            "ci-cd" = @{ level = 8; experience = "GitHub Actions" }
            "authentication" = @{ level = 7; experience = "JWT, OAuth basics" }
            "postgresql" = @{ level = 7; experience = "Production usage" }
            "ai-agents" = @{ level = 9; experience = "Building multi-agent systems" }
        }
        confidenceHistory = @()
        lastUpdate = $null
    } | ConvertTo-Json -Depth 10 | Set-Content $ExpertiseFile -Encoding UTF8
}

$exp = Get-Content $ExpertiseFile -Raw | ConvertFrom-Json

function Analyze-Confidence {
    param([string]$Text)

    $lower = $Text.ToLower()
    $confidenceFactors = @{
        domain = 5  # Base
        complexity = 0
        clarity = 0
        familiarity = 0
    }

    # Check against known domains
    foreach ($d in $exp.domains.PSObject.Properties) {
        if ($lower -match $d.Name) {
            $confidenceFactors.familiarity = $d.Value.level
            break
        }
    }

    # Complexity indicators (lower confidence)
    if ($lower -match 'complex|difficult|advanced|tricky') {
        $confidenceFactors.complexity = -2
    }

    # Clarity indicators
    if ($lower -match 'please|specific|exactly|must') {
        $confidenceFactors.clarity = 1
    }
    if ($lower -match 'maybe|might|could|not sure') {
        $confidenceFactors.clarity = -1
    }

    # Calculate total (max 10)
    $total = [Math]::Max(1, [Math]::Min(10,
        $confidenceFactors.domain +
        $confidenceFactors.complexity +
        $confidenceFactors.clarity +
        ($confidenceFactors.familiarity / 2)
    ))

    return @{
        score = $total
        factors = $confidenceFactors
        recommendation = if ($total -ge 8) {
            "High confidence. Proceeding autonomously."
        } elseif ($total -ge 5) {
            "Moderate confidence. Will confirm key decisions."
        } else {
            "Low confidence. Will ask clarifying questions."
        }
    }
}

if ($Request) {
    Write-Host "=== UNDERSTANDING CONFIDENCE ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Request: `"$Request`"" -ForegroundColor Yellow
    Write-Host ""

    $analysis = Analyze-Confidence -Text $Request

    $color = if ($analysis.score -ge 8) { "Green" } elseif ($analysis.score -ge 5) { "Yellow" } else { "Red" }
    Write-Host "CONFIDENCE SCORE: $($analysis.score)/10" -ForegroundColor $color
    Write-Host ""
    Write-Host "Factors:" -ForegroundColor Magenta
    Write-Host "  Domain knowledge: $($analysis.factors.familiarity)/10" -ForegroundColor Gray
    Write-Host "  Complexity adjustment: $($analysis.factors.complexity)" -ForegroundColor Gray
    Write-Host "  Clarity adjustment: $($analysis.factors.clarity)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Recommendation: $($analysis.recommendation)" -ForegroundColor White

    # Log
    $exp.confidenceHistory += @{
        request = $Request.Substring(0, [Math]::Min(100, $Request.Length))
        score = $analysis.score
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    $exp | ConvertTo-Json -Depth 10 | Set-Content $ExpertiseFile -Encoding UTF8
}
elseif ($Domain -and $Level -gt 0) {
    if (-not $exp.domains.$Domain) {
        $exp.domains | Add-Member -NotePropertyName $Domain -NotePropertyValue @{} -Force
    }
    $exp.domains.$Domain.level = $Level
    $exp.domains.$Domain.updated = (Get-Date).ToString("yyyy-MM-dd")
    $exp.lastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $exp | ConvertTo-Json -Depth 10 | Set-Content $ExpertiseFile -Encoding UTF8

    Write-Host "✓ Expertise updated: $Domain = $Level/10" -ForegroundColor Green
}
elseif ($ShowExpertise) {
    Write-Host "=== EXPERTISE TRACKING ===" -ForegroundColor Cyan
    Write-Host ""

    $sorted = $exp.domains.PSObject.Properties | Sort-Object { $_.Value.level } -Descending

    foreach ($d in $sorted) {
        $level = $d.Value.level
        $bar = "█" * $level + "░" * (10 - $level)
        $color = if ($level -ge 8) { "Green" } elseif ($level -ge 5) { "Yellow" } else { "Red" }
        Write-Host "  $($d.Name.PadRight(15)) [$bar] $level/10" -ForegroundColor $color
    }
}
elseif ($Gaps) {
    Write-Host "=== EXPERTISE GAPS ===" -ForegroundColor Cyan
    Write-Host ""

    $gaps = $exp.domains.PSObject.Properties | Where-Object { $_.Value.level -lt 6 }

    if ($gaps.Count -eq 0) {
        Write-Host "No significant gaps identified!" -ForegroundColor Green
    } else {
        Write-Host "Areas for improvement:" -ForegroundColor Yellow
        foreach ($g in $gaps) {
            Write-Host "  • $($g.Name) (level $($g.Value.level))" -ForegroundColor White
        }
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Request <text>          Analyze confidence for request" -ForegroundColor White
    Write-Host "  -Domain x -Level n       Update expertise" -ForegroundColor White
    Write-Host "  -ShowExpertise           Show all expertise" -ForegroundColor White
    Write-Host "  -Gaps                    Show expertise gaps" -ForegroundColor White
}
