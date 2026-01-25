<#
.SYNOPSIS
    Detect configuration drift between environments (dev/staging/prod)

.DESCRIPTION
    Identifies configuration inconsistencies across environments:
    - Compares appsettings.json, web.config, .env files
    - Detects missing/extra configuration keys
    - Identifies value mismatches
    - Validates environment-specific overrides
    - Tracks configuration changes over time
    - Generates drift reports

    Prevents production issues from configuration drift.

.PARAMETER SourceEnvironment
    Source environment configuration path

.PARAMETER TargetEnvironment
    Target environment configuration path

.PARAMETER ConfigType
    Configuration type: appsettings, env, webconfig, all

.PARAMETER ShowOnlyDifferences
    Show only configuration differences (hide matches)

.PARAMETER OutputFormat
    Output format: table (default), json, html, diff

.PARAMETER BaselineFile
    Save/load configuration baseline for drift tracking

.EXAMPLE
    # Compare staging vs production
    .\configuration-drift-detector.ps1 -SourceEnvironment "./staging" -TargetEnvironment "./prod" -ConfigType appsettings

.EXAMPLE
    # Show only differences
    .\configuration-drift-detector.ps1 -SourceEnvironment "./dev" -TargetEnvironment "./staging" -ShowOnlyDifferences

.EXAMPLE
    # Track drift against baseline
    .\configuration-drift-detector.ps1 -TargetEnvironment "./prod" -BaselineFile "baseline.json"

.NOTES
    Value: 8/10 - Prevents config-related outages
    Effort: 1.3/10 - Config file parsing + comparison
    Ratio: 6.2 (TIER S)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SourceEnvironment = "",

    [Parameter(Mandatory=$false)]
    [string]$TargetEnvironment = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [ValidateSet('appsettings', 'env', 'webconfig', 'all')]
    [string]$ConfigType = 'all',

    [Parameter(Mandatory=$false)]
    [switch]$ShowOnlyDifferences = $false,

    [Parameter(Mandatory=$false)]
    [ValidateSet('table', 'json', 'html', 'diff')]
    [string]$OutputFormat = 'table',

    [Parameter(Mandatory=$false)]
    [string]$BaselineFile = ""
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🔍 Configuration Drift Detector" -ForegroundColor Cyan
if ($SourceEnvironment) {
    Write-Host "  Source: $SourceEnvironment" -ForegroundColor Gray
}
Write-Host "  Target: $TargetEnvironment" -ForegroundColor Gray
Write-Host ""

# Load configuration
function Get-Configuration {
    param([string]$Path, [string]$Type)

    $config = @{}

    switch ($Type) {
        'appsettings' {
            $files = Get-ChildItem -Path $Path -Filter "appsettings*.json" -File -ErrorAction SilentlyContinue

            foreach ($file in $files) {
                try {
                    $json = Get-Content $file.FullName -Raw | ConvertFrom-Json
                    $flattened = Flatten-Object -Object $json -Prefix $file.Name

                    foreach ($key in $flattened.Keys) {
                        $config[$key] = $flattened[$key]
                    }
                } catch {
                    Write-Host "  ⚠️  Failed to parse $($file.Name)" -ForegroundColor Yellow
                }
            }
        }
        'env' {
            $files = Get-ChildItem -Path $Path -Filter ".env*" -File -ErrorAction SilentlyContinue

            foreach ($file in $files) {
                $content = Get-Content $file.FullName

                foreach ($line in $content) {
                    if ($line -match '^([^=]+)=(.*)$') {
                        $key = "$($file.Name):$($Matches[1].Trim())"
                        $value = $Matches[2].Trim()
                        $config[$key] = $value
                    }
                }
            }
        }
        'webconfig' {
            $files = Get-ChildItem -Path $Path -Filter "web.config" -File -ErrorAction SilentlyContinue

            foreach ($file in $files) {
                try {
                    [xml]$xml = Get-Content $file.FullName
                    $appSettings = $xml.configuration.appSettings.add

                    foreach ($setting in $appSettings) {
                        $config["$($file.Name):$($setting.key)"] = $setting.value
                    }
                } catch {
                    Write-Host "  ⚠️  Failed to parse $($file.Name)" -ForegroundColor Yellow
                }
            }
        }
    }

    return $config
}

# Flatten nested JSON object
function Flatten-Object {
    param($Object, $Prefix = "")

    $result = @{}

    foreach ($prop in $Object.PSObject.Properties) {
        $key = if ($Prefix) { "$Prefix.$($prop.Name)" } else { $prop.Name }

        if ($prop.Value -is [PSCustomObject]) {
            $nested = Flatten-Object -Object $prop.Value -Prefix $key
            foreach ($nestedKey in $nested.Keys) {
                $result[$nestedKey] = $nested[$nestedKey]
            }
        } else {
            $result[$key] = $prop.Value
        }
    }

    return $result
}

# Load configurations
$configTypes = if ($ConfigType -eq 'all') { @('appsettings', 'env', 'webconfig') } else { @($ConfigType) }

$sourceConfig = @{}
$targetConfig = @{}

foreach ($type in $configTypes) {
    if ($SourceEnvironment) {
        $sourceConfig += Get-Configuration -Path $SourceEnvironment -Type $type
    }
    $targetConfig += Get-Configuration -Path $TargetEnvironment -Type $type
}

# Load baseline if provided
if ($BaselineFile -and (Test-Path $BaselineFile)) {
    Write-Host "📋 Loading baseline from $BaselineFile..." -ForegroundColor Yellow
    $baselineContent = Get-Content $BaselineFile -Raw | ConvertFrom-Json
    $sourceConfig = @{}
    foreach ($prop in $baselineContent.PSObject.Properties) {
        $sourceConfig[$prop.Name] = $prop.Value
    }
} elseif ($BaselineFile) {
    # Save current target as baseline
    Write-Host "💾 Saving baseline to $BaselineFile..." -ForegroundColor Yellow
    $targetConfig | ConvertTo-Json -Depth 10 | Set-Content $BaselineFile -Encoding UTF8
}

if ($sourceConfig.Count -eq 0 -and -not $BaselineFile) {
    Write-Host "❌ No source configuration found" -ForegroundColor Red
    exit 1
}

Write-Host "📊 Comparing configurations..." -ForegroundColor Yellow
Write-Host "  Source keys: $($sourceConfig.Count)" -ForegroundColor Gray
Write-Host "  Target keys: $($targetConfig.Count)" -ForegroundColor Gray
Write-Host ""

# Compare configurations
$differences = @()
$allKeys = ($sourceConfig.Keys + $targetConfig.Keys) | Select-Object -Unique

foreach ($key in $allKeys) {
    $sourceValue = $sourceConfig[$key]
    $targetValue = $targetConfig[$key]

    $status = if (-not $sourceConfig.ContainsKey($key)) {
        "Added in target"
    } elseif (-not $targetConfig.ContainsKey($key)) {
        "Missing in target"
    } elseif ($sourceValue -ne $targetValue) {
        "Value differs"
    } else {
        "Match"
    }

    $differences += [PSCustomObject]@{
        Key = $key
        SourceValue = if ($sourceValue) { $sourceValue.ToString() } else { "(missing)" }
        TargetValue = if ($targetValue) { $targetValue.ToString() } else { "(missing)" }
        Status = $status
        IsDrift = $status -ne "Match"
    }
}

# Filter if showing only differences
if ($ShowOnlyDifferences) {
    $differences = $differences | Where-Object { $_.IsDrift }
}

Write-Host ""
Write-Host "CONFIGURATION DRIFT REPORT" -ForegroundColor Cyan
Write-Host ""

$driftCount = ($differences | Where-Object { $_.IsDrift }).Count
$matchCount = ($differences | Where-Object { -not $_.IsDrift }).Count

switch ($OutputFormat) {
    'table' {
        $differences | Format-Table -AutoSize -Wrap -Property @(
            @{Label='Key'; Expression={$_.Key}; Width=40}
            @{Label='Source'; Expression={$_.SourceValue.Substring(0, [Math]::Min(30, $_.SourceValue.Length))}; Width=32}
            @{Label='Target'; Expression={$_.TargetValue.Substring(0, [Math]::Min(30, $_.TargetValue.Length))}; Width=32}
            @{Label='Status'; Expression={$_.Status}; Width=20}
        )

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Total keys: $($allKeys.Count)" -ForegroundColor Gray
        Write-Host "  Matching: $matchCount" -ForegroundColor Green
        Write-Host "  Drifted: $driftCount" -ForegroundColor $(if($driftCount -gt 0){"Yellow"}else{"Green"})
        Write-Host "  Missing in target: $(($differences | Where-Object {$_.Status -eq 'Missing in target'}).Count)" -ForegroundColor Red
        Write-Host "  Added in target: $(($differences | Where-Object {$_.Status -eq 'Added in target'}).Count)" -ForegroundColor Yellow
        Write-Host "  Value differs: $(($differences | Where-Object {$_.Status -eq 'Value differs'}).Count)" -ForegroundColor Yellow
    }

    'json' {
        @{
            Summary = @{
                TotalKeys = $allKeys.Count
                Matching = $matchCount
                Drifted = $driftCount
                Missing = ($differences | Where-Object {$_.Status -eq 'Missing in target'}).Count
                Added = ($differences | Where-Object {$_.Status -eq 'Added in target'}).Count
                Different = ($differences | Where-Object {$_.Status -eq 'Value differs'}).Count
            }
            Differences = $differences
        } | ConvertTo-Json -Depth 10
    }

    'html' {
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Configuration Drift Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #1976d2; }
        .drift { background: #fff3e0; }
        .missing { background: #ffebee; }
        .added { background: #e8f5e9; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #1976d2; color: white; }
    </style>
</head>
<body>
    <h1>Configuration Drift Report</h1>
    <h2>Summary</h2>
    <p><strong>Total Keys:</strong> $($allKeys.Count)</p>
    <p><strong>Matching:</strong> $matchCount</p>
    <p><strong>Drifted:</strong> $driftCount</p>
    <table>
        <tr>
            <th>Key</th>
            <th>Source</th>
            <th>Target</th>
            <th>Status</th>
        </tr>
"@

        foreach ($diff in $differences) {
            $rowClass = switch ($diff.Status) {
                "Missing in target" { "missing" }
                "Added in target" { "added" }
                "Value differs" { "drift" }
                default { "" }
            }

            $html += @"
        <tr class="$rowClass">
            <td>$($diff.Key)</td>
            <td>$($diff.SourceValue)</td>
            <td>$($diff.TargetValue)</td>
            <td>$($diff.Status)</td>
        </tr>
"@
        }

        $html += @"
    </table>
</body>
</html>
"@

        $reportPath = "config_drift_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
        $html | Set-Content $reportPath -Encoding UTF8
        Write-Host "✅ Report generated: $reportPath" -ForegroundColor Green
    }

    'diff' {
        # Git-style diff format
        Write-Host "diff --git a/source b/target" -ForegroundColor Cyan
        Write-Host "--- a/source" -ForegroundColor Cyan
        Write-Host "+++ b/target" -ForegroundColor Cyan

        foreach ($diff in $differences | Where-Object { $_.IsDrift }) {
            Write-Host ""
            Write-Host "@@ $($diff.Key) @@" -ForegroundColor Cyan

            if ($diff.Status -eq "Missing in target") {
                Write-Host "- $($diff.SourceValue)" -ForegroundColor Red
            } elseif ($diff.Status -eq "Added in target") {
                Write-Host "+ $($diff.TargetValue)" -ForegroundColor Green
            } else {
                Write-Host "- $($diff.SourceValue)" -ForegroundColor Red
                Write-Host "+ $($diff.TargetValue)" -ForegroundColor Green
            }
        }
    }
}

Write-Host ""
if ($driftCount -gt 0) {
    Write-Host "⚠️  Configuration drift detected - review changes" -ForegroundColor Yellow
} else {
    Write-Host "✅ No configuration drift detected" -ForegroundColor Green
}
