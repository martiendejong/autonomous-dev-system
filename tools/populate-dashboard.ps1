<#
.SYNOPSIS
    Populate World Development Dashboard with WebSearch results

.DESCRIPTION
    This script is called by Claude Agent to inject WebSearch results into the dashboard HTML.
    Claude executes WebSearch queries and passes results to this script for rendering.

.PARAMETER DashboardPath
    Path to dashboard HTML file to populate

.PARAMETER Domain
    Domain to update (ai, climate, economics, geopolitics, science, predictions, critical)

.PARAMETER Items
    Array of items to display (hashtables with Title, Content, Critical properties)

.EXAMPLE
    $items = @(
        @{ Title = "OpenAI GPT-5 Released"; Content = "Major breakthrough..."; Critical = $false }
        @{ Title = "AGI Debate Intensifies"; Content = "Industry consensus..."; Critical = $true }
    )
    .\populate-dashboard.ps1 -DashboardPath "C:\...\latest.html" -Domain "ai" -Items $items

.NOTES
    Called by Claude Agent during daily dashboard generation
    Created: 2026-01-25
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$DashboardPath,

    [Parameter(Mandatory=$true)]
    [ValidateSet("ai", "climate", "economics", "geopolitics", "science", "predictions", "critical")]
    [string]$Domain,

    [Parameter(Mandatory=$true)]
    [array]$Items
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DashboardPath)) {
    Write-Error "Dashboard file not found: $DashboardPath"
    exit 1
}

Write-Host "📊 Populating dashboard: $Domain section" -ForegroundColor Cyan

# Read current HTML
$html = Get-Content -Path $DashboardPath -Raw -Encoding UTF8

# Generate HTML for items
$itemsHtml = ""
foreach ($item in $Items) {
    $criticalClass = if ($item.Critical) { " critical" } else { "" }
    $itemsHtml += @"
                    <div class="item$criticalClass">
                        <strong>$($item.Title)</strong>
                        $($item.Content)
                    </div>

"@
}

# Update appropriate section based on domain
switch ($Domain) {
    "ai" {
        $contentId = "ai-content"
    }
    "climate" {
        $contentId = "climate-content"
    }
    "economics" {
        $contentId = "economics-content"
    }
    "geopolitics" {
        $contentId = "geopolitics-content"
    }
    "science" {
        $contentId = "science-content"
    }
    "predictions" {
        $contentId = "predictions-content"
    }
    "critical" {
        # Handle critical section separately
        if ($Items.Count -gt 0) {
            $criticalHtml = ""
            foreach ($item in $Items) {
                $criticalHtml += "<div><strong>$($item.Title):</strong> $($item.Content)</div>`n"
            }

            $html = $html -replace '<div id="critical-section" style="display: none;">', '<div id="critical-section">'
            $html = $html -replace '<div id="critical-content"></div>', "<div id='critical-content'>$criticalHtml</div>"
        }

        # Save and exit for critical section
        Set-Content -Path $DashboardPath -Value $html -Encoding UTF8
        Write-Host "✅ Critical section updated" -ForegroundColor Green
        return
    }
}

# Replace loading placeholder with actual content
$pattern = "(<div class=`"card-content`" id=`"$contentId`">).*?(</div>\s*</div>)"
$replacement = "`$1`n$itemsHtml                </div>`n            </div>"

$html = $html -replace $pattern, $replacement, [System.Text.RegularExpressions.RegexOptions]::Singleline

# Save updated HTML
Set-Content -Path $DashboardPath -Value $html -Encoding UTF8

Write-Host "✅ Dashboard section updated: $Domain ($($Items.Count) items)" -ForegroundColor Green
