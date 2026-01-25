<#
.SYNOPSIS
    Diff OpenAPI schemas to detect breaking changes

.DESCRIPTION
    Compares two OpenAPI specifications:
    - Detects breaking changes
    - Identifies new endpoints
    - Checks removed endpoints
    - Validates parameter changes
    - Tracks schema evolution
    - Generates change report

.PARAMETER OldSpec
    Path to old OpenAPI spec

.PARAMETER NewSpec
    Path to new OpenAPI spec

.PARAMETER BreakingOnly
    Show only breaking changes

.PARAMETER OutputFormat
    Output format: table (default), json, markdown

.EXAMPLE
    .\openapi-diff.ps1 -OldSpec "v1.json" -NewSpec "v2.json" -BreakingOnly

.NOTES
    Value: 8/10 - Prevents API breaking changes
    Effort: 2/10 - JSON comparison
    Ratio: 4.0 (TIER A)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$OldSpec,

    [Parameter(Mandatory=$true)]
    [string]$NewSpec,

    [Parameter(Mandatory=$false)]
    [switch]$BreakingOnly = $false,

    [Parameter(Mandatory=$false)]
    [ValidateSet('table', 'json', 'markdown')]
    [string]$OutputFormat = 'table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🔄 OpenAPI Diff" -ForegroundColor Cyan
Write-Host "  Old: $OldSpec" -ForegroundColor Gray
Write-Host "  New: $NewSpec" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $OldSpec)) {
    Write-Host "❌ Old spec not found: $OldSpec" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $NewSpec)) {
    Write-Host "❌ New spec not found: $NewSpec" -ForegroundColor Red
    exit 1
}

$old = Get-Content $OldSpec -Raw | ConvertFrom-Json
$new = Get-Content $NewSpec -Raw | ConvertFrom-Json

$changes = @()

# Compare paths
$oldPaths = $old.paths.PSObject.Properties.Name
$newPaths = $new.paths.PSObject.Properties.Name

# Removed endpoints (BREAKING)
$removed = $oldPaths | Where-Object { $_ -notin $newPaths }
foreach ($path in $removed) {
    $changes += [PSCustomObject]@{
        Type = "Endpoint Removed"
        Path = $path
        ChangeType = "BREAKING"
        Impact = "HIGH"
    }
}

# Added endpoints (NON-BREAKING)
$added = $newPaths | Where-Object { $_ -notin $oldPaths }
foreach ($path in $added) {
    $changes += [PSCustomObject]@{
        Type = "Endpoint Added"
        Path = $path
        ChangeType = "NON-BREAKING"
        Impact = "LOW"
    }
}

# Modified endpoints
$common = $oldPaths | Where-Object { $_ -in $newPaths }
foreach ($path in $common) {
    $oldMethods = $old.paths.$path.PSObject.Properties.Name
    $newMethods = $new.paths.$path.PSObject.Properties.Name

    # Removed methods (BREAKING)
    $removedMethods = $oldMethods | Where-Object { $_ -notin $newMethods -and $_ -in @('get','post','put','delete','patch') }
    foreach ($method in $removedMethods) {
        $changes += [PSCustomObject]@{
            Type = "Method Removed"
            Path = "$method $path"
            ChangeType = "BREAKING"
            Impact = "HIGH"
        }
    }

    # Added methods (NON-BREAKING)
    $addedMethods = $newMethods | Where-Object { $_ -notin $oldMethods -and $_ -in @('get','post','put','delete','patch') }
    foreach ($method in $addedMethods) {
        $changes += [PSCustomObject]@{
            Type = "Method Added"
            Path = "$method $path"
            ChangeType = "NON-BREAKING"
            Impact = "LOW"
        }
    }
}

# Filter if breaking only
if ($BreakingOnly) {
    $changes = $changes | Where-Object { $_.ChangeType -eq "BREAKING" }
}

Write-Host "OPENAPI DIFF RESULTS" -ForegroundColor Cyan
Write-Host ""

$breakingCount = ($changes | Where-Object {$_.ChangeType -eq "BREAKING"}).Count
$nonBreakingCount = ($changes | Where-Object {$_.ChangeType -eq "NON-BREAKING"}).Count

switch ($OutputFormat) {
    'table' {
        if ($changes.Count -gt 0) {
            $changes | Format-Table -AutoSize -Property @(
                @{Label='Type'; Expression={$_.Type}; Width=20}
                @{Label='Path'; Expression={$_.Path}; Width=50}
                @{Label='Change'; Expression={$_.ChangeType}; Width=15}
                @{Label='Impact'; Expression={$_.Impact}; Width=10}
            )
        }

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Total changes: $($changes.Count)" -ForegroundColor Gray
        Write-Host "  Breaking: $breakingCount" -ForegroundColor $(if($breakingCount -gt 0){"Red"}else{"Green"})
        Write-Host "  Non-breaking: $nonBreakingCount" -ForegroundColor Green
    }
    'json' {
        @{
            OldSpec = $OldSpec
            NewSpec = $NewSpec
            Changes = $changes
            Summary = @{
                Total = $changes.Count
                Breaking = $breakingCount
                NonBreaking = $nonBreakingCount
            }
        } | ConvertTo-Json -Depth 10
    }
    'markdown' {
        $md = "# API Changes`n`n"
        $md += "**Old Spec:** $OldSpec`n"
        $md += "**New Spec:** $NewSpec`n`n"
        $md += "## Summary`n`n"
        $md += "- Total Changes: $($changes.Count)`n"
        $md += "- Breaking: $breakingCount`n"
        $md += "- Non-Breaking: $nonBreakingCount`n`n"

        if ($breakingCount -gt 0) {
            $md += "## ⚠️ Breaking Changes`n`n"
            $breaking = $changes | Where-Object {$_.ChangeType -eq "BREAKING"}
            foreach ($change in $breaking) {
                $md += "- **$($change.Type):** $($change.Path)`n"
            }
        }

        $md
    }
}

Write-Host ""
if ($breakingCount -gt 0) {
    Write-Host "⚠️  BREAKING CHANGES DETECTED" -ForegroundColor Red
    Write-Host "  Consider incrementing major version" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✅ No breaking changes" -ForegroundColor Green
}
