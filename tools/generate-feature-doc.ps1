<#
.SYNOPSIS
    Generate feature documentation from template.

.DESCRIPTION
    Creates a new feature documentation file from a template.
    Replaces placeholders with provided values.

.PARAMETER FeatureName
    Name of the feature being documented

.PARAMETER Version
    Version number of the feature

.PARAMETER OutputPath
    Path where the documentation file will be created

.EXAMPLE
    .\generate-feature-doc.ps1 -FeatureName "Context Compression" -Version "2.0.0" -OutputPath "C:\Projects\hazina\docs\CONTEXT_COMPRESSION.md"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$FeatureName,

    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

# Check if template exists
$templatePath = "C:\scripts\templates\FEATURE_GUIDE_TEMPLATE.md"
if (-not (Test-Path $templatePath)) {
    Write-Error "❌ Template not found: $templatePath"
    exit 1
}

# Read template
$template = Get-Content $templatePath -Raw

# Replace placeholders
$doc = $template `
    -replace '\[FEATURE\]', $FeatureName `
    -replace '\[PRODUCT\]', 'Hazina' `
    -replace '\[VERSION\]', $Version `
    -replace '\[DATE\]', (Get-Date -Format "yyyy-MM-dd")

# Create output directory if needed
$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "📁 Created directory: $outputDir"
}

# Save
$doc | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host "✅ Created: $OutputPath"
Write-Host "📝 Now fill in the following sections:"
Write-Host "   - Replace [METRIC] placeholders with actual metrics"
Write-Host "   - Add code examples (problem/solution)"
Write-Host "   - Fill in use cases (3-5 scenarios)"
Write-Host "   - Add troubleshooting issues"
Write-Host "   - Update API reference"
Write-Host ""
Write-Host "💡 Tip: Search for [ and ] to find all placeholders"
