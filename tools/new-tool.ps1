<#
.SYNOPSIS
    Generates a new tool from template.

.DESCRIPTION
    Creates a new PowerShell tool with:
    - Standard comment-based help
    - Common parameters (DryRun, Verbose)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
    - Config import
    - Error handling
    - Logging

.PARAMETER Name
    Name of the new tool (without .ps1)

.PARAMETER Description
    Brief description for the tool

.PARAMETER Type
    Template type: simple, interactive, or report

.EXAMPLE
    .\new-tool.ps1 -Name "my-tool" -Description "Does something useful"
    .\new-tool.ps1 -Name "checker" -Description "Checks things" -Type report
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [string]$Description,

    [ValidateSet("simple", "interactive", "report")]
    [string]$Type = "simple"
)

$ToolsPath = "C:\scripts\tools"
$OutputPath = Join-Path $ToolsPath "$Name.ps1"

if (Test-Path $OutputPath) {
    Write-Host "ERROR: Tool already exists at $OutputPath" -ForegroundColor Red
    exit 1
}

$Templates = @{
    simple = @'
<#
.SYNOPSIS
    {DESCRIPTION}

.DESCRIPTION
    {DESCRIPTION}

.PARAMETER DryRun
    Show what would happen without making changes

.EXAMPLE
    .\{NAME}.ps1
    .\{NAME}.ps1 -DryRun
#>

param(
    [switch]$DryRun
)

# Import config
. "$PSScriptRoot\config.ps1"

# Main execution
Write-Host ""
Write-Host "=== {NAME_UPPER} ===" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] Would execute tool logic here" -ForegroundColor Yellow
    exit 0
}

# TODO: Implement tool logic here

Write-Host "Done." -ForegroundColor Green
'@

    interactive = @'
<#
.SYNOPSIS
    {DESCRIPTION}

.DESCRIPTION
    {DESCRIPTION}

.PARAMETER DryRun
    Show what would happen without making changes

.PARAMETER Force
    Execute without confirmation

.EXAMPLE
    .\{NAME}.ps1
    .\{NAME}.ps1 -Force
    .\{NAME}.ps1 -DryRun
#>

param(
    [switch]$DryRun,
    [switch]$Force
)

# Import config
. "$PSScriptRoot\config.ps1"

# Main execution
Write-Host ""
Write-Host "=== {NAME_UPPER} ===" -ForegroundColor Cyan
Write-Host ""

# TODO: Add detection/analysis logic here
$itemsToProcess = @()

if ($itemsToProcess.Count -eq 0) {
    Write-Host "Nothing to process." -ForegroundColor Green
    exit 0
}

Write-Host "Found $($itemsToProcess.Count) items to process:" -ForegroundColor Yellow
# TODO: Display items

if ($DryRun) {
    Write-Host ""
    Write-Host "[DRY RUN] Would process $($itemsToProcess.Count) items" -ForegroundColor Yellow
    exit 0
}

if (-not $Force) {
    $confirm = Read-Host "Proceed? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# TODO: Process items

Write-Host ""
Write-Host "Done." -ForegroundColor Green
'@

    report = @'
<#
.SYNOPSIS
    {DESCRIPTION}

.DESCRIPTION
    {DESCRIPTION}

.PARAMETER Format
    Output format: text, json, or markdown

.EXAMPLE
    .\{NAME}.ps1
    .\{NAME}.ps1 -Format json
    .\{NAME}.ps1 -Format markdown
#>

param(
    [ValidateSet("text", "json", "markdown")]
    [string]$Format = "text"
)

# Import config
. "$PSScriptRoot\config.ps1"

# Gather data
$report = @{
    generated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    # TODO: Add report data here
}

# Output based on format
switch ($Format) {
    "json" {
        $report | ConvertTo-Json -Depth 5
    }
    "markdown" {
        @"
# {NAME_UPPER} Report
Generated: $($report.generated)

## Summary
TODO: Add markdown content

---
"@
    }
    "text" {
        Write-Host ""
        Write-Host "=== {NAME_UPPER} REPORT ===" -ForegroundColor Cyan
        Write-Host "Generated: $($report.generated)" -ForegroundColor DarkGray
        Write-Host ""

        # TODO: Display report

        Write-Host ""
    }
}
'@
}

# Generate from template
$template = $Templates[$Type]
$content = $template `
    -replace '\{NAME\}', $Name `
    -replace '\{NAME_UPPER\}', $Name.ToUpper() `
    -replace '\{DESCRIPTION\}', $Description

$content | Set-Content $OutputPath -Encoding UTF8

Write-Host ""
Write-Host "Tool created: $OutputPath" -ForegroundColor Green
Write-Host ""
Write-Host "Template: $Type" -ForegroundColor DarkGray
Write-Host "Description: $Description" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Edit $OutputPath" -ForegroundColor DarkGray
Write-Host "  2. Implement TODO sections" -ForegroundColor DarkGray
Write-Host "  3. Test with: .\$Name.ps1 -DryRun" -ForegroundColor DarkGray
Write-Host "  4. Add to tools/README.md" -ForegroundColor DarkGray
Write-Host ""
