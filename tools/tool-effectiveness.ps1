<#
.SYNOPSIS
    Tool Effectiveness Scorer
    50-Expert Council V2 Improvement #46 | Priority: 2.0

.DESCRIPTION
    Measures which tools actually help productivity.

.PARAMETER Analyze
    Analyze tool effectiveness.

.PARAMETER Track
    Track tool usage outcome.

.PARAMETER Tool
    Tool name.

.PARAMETER Helpful
    Was it helpful (true/false).

.EXAMPLE
    tool-effectiveness.ps1 -Analyze
    tool-effectiveness.ps1 -Track -Tool "q.ps1" -Helpful
#>

param(
    [switch]$Analyze,
    [switch]$Track,
    [string]$Tool = "",
    [switch]$Helpful,
    [switch]$Report
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$EffectivenessFile = "C:\scripts\_machine\tool_effectiveness.json"

if (-not (Test-Path $EffectivenessFile)) {
    @{
        tools = @{}
        recommendations = @()
    } | ConvertTo-Json -Depth 10 | Set-Content $EffectivenessFile -Encoding UTF8
}

$data = Get-Content $EffectivenessFile -Raw | ConvertFrom-Json

if ($Track -and $Tool) {
    if (-not $data.tools.$Tool) {
        $data.tools | Add-Member -NotePropertyName $Tool -NotePropertyValue @{
            helpful = 0
            notHelpful = 0
            totalUses = 0
        } -Force
    }

    $data.tools.$Tool.totalUses++
    if ($Helpful) {
        $data.tools.$Tool.helpful++
    }
    else {
        $data.tools.$Tool.notHelpful++
    }

    $data | ConvertTo-Json -Depth 10 | Set-Content $EffectivenessFile -Encoding UTF8

    $rate = [Math]::Round(($data.tools.$Tool.helpful / $data.tools.$Tool.totalUses) * 100)
    Write-Host "✓ Tracked: $Tool (effectiveness: $rate%)" -ForegroundColor Green
}
elseif ($Analyze -or $Report) {
    Write-Host "=== TOOL EFFECTIVENESS REPORT ===" -ForegroundColor Cyan
    Write-Host ""

    # Get tool analytics
    $analyticsFile = "C:\scripts\_machine\tool_analytics.json"
    $analytics = if (Test-Path $analyticsFile) {
        Get-Content $analyticsFile -Raw | ConvertFrom-Json
    } else { @{ usage = @{} } }

    # Combine data
    $toolStats = @()

    foreach ($prop in $analytics.usage.PSObject.Properties) {
        $toolName = $prop.Name
        $uses = $prop.Value.count

        $effectiveness = if ($data.tools.$toolName) {
            $t = $data.tools.$toolName
            if ($t.totalUses -gt 0) {
                [Math]::Round(($t.helpful / $t.totalUses) * 100)
            } else { 50 }
        } else { 50 }

        $toolStats += @{
            name = $toolName
            uses = $uses
            effectiveness = $effectiveness
            score = $uses * ($effectiveness / 100)
        }
    }

    # Sort by score
    $sorted = $toolStats | Sort-Object { $_.score } -Descending

    Write-Host "TOP EFFECTIVE TOOLS:" -ForegroundColor Green
    $sorted | Where-Object { $_.uses -gt 0 } | Select-Object -First 10 | ForEach-Object {
        $bar = "█" * [Math]::Min(10, [Math]::Round($_.effectiveness / 10))
        Write-Host "  $($_.name.PadRight(30)) [$bar] $($_.effectiveness)% ($($_.uses) uses)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "UNDERPERFORMING TOOLS:" -ForegroundColor Yellow
    $sorted | Where-Object { $_.uses -gt 5 -and $_.effectiveness -lt 50 } | Select-Object -First 5 | ForEach-Object {
        Write-Host "  ⚠ $($_.name): $($_.effectiveness)% effective" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "UNUSED TOOLS (consider removing):" -ForegroundColor Red
    $allTools = Get-ChildItem "C:\scripts\tools\*.ps1" | Select-Object -ExpandProperty Name
    $unused = $allTools | Where-Object { -not $analytics.usage.$_ -or $analytics.usage.$_.count -eq 0 } | Select-Object -First 10
    foreach ($u in $unused) {
        Write-Host "  • $u" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "RECOMMENDATIONS:" -ForegroundColor Magenta
    Write-Host "  1. Focus on tools with >70% effectiveness" -ForegroundColor White
    Write-Host "  2. Review or deprecate tools <30% effectiveness" -ForegroundColor White
    Write-Host "  3. Track outcomes: tool-effectiveness.ps1 -Track -Tool x -Helpful" -ForegroundColor White
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Analyze                     Analyze effectiveness" -ForegroundColor White
    Write-Host "  -Track -Tool x -Helpful      Track helpful usage" -ForegroundColor White
    Write-Host "  -Track -Tool x               Track unhelpful usage" -ForegroundColor White
}
