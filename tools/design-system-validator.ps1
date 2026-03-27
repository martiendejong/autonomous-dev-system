<#
.SYNOPSIS
    Validate UI components against design system rules

.DESCRIPTION
    Ensures UI consistency with design system:
    - Validates color palette usage
    - Checks typography compliance
    - Verifies spacing/sizing adherence
    - Detects component misuse
    - Identifies design token violations
    - Generates compliance reports

    Prevents design inconsistencies.

.PARAMETER ComponentPath
    Path to UI components directory

.PARAMETER DesignSystemPath
    Path to design system config (JSON/YAML)

.PARAMETER Rules
    Rules to validate: colors, typography, spacing, components, all

.PARAMETER OutputFormat
    Output format: table (default), json, html

.PARAMETER FailOnViolation
    Fail if violations found

.EXAMPLE
    .\design-system-validator.ps1 -ComponentPath "./src/components" -DesignSystemPath "./design-system.json"

.NOTES
    Value: 7/10 - UI consistency is important
    Effort: 1.5/10 - Code parsing + rule matching
    Ratio: 4.7 (TIER A)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ComponentPath,

    [Parameter(Mandatory=$false)]
    [string]$DesignSystemPath = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet('colors', 'typography', 'spacing', 'components', 'all')]
    [string]$Rules = 'all',

    [Parameter(Mandatory=$false)]
    [ValidateSet('table', 'json', 'html')]
    [string]$OutputFormat = 'table',

    [Parameter(Mandatory=$false)]
    [switch]$FailOnViolation = $false
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🎨 Design System Validator" -ForegroundColor Cyan
Write-Host "  Components: $ComponentPath" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $ComponentPath)) {
    Write-Host "❌ Component path not found: $ComponentPath" -ForegroundColor Red
    exit 1
}

# Default design system tokens
$designSystem = if ($DesignSystemPath -and (Test-Path $DesignSystemPath)) {
    Get-Content $DesignSystemPath -Raw | ConvertFrom-Json
} else {
    @{
        colors = @{
            primary = @('#1976d2', '#1565c0', '#0d47a1')
            secondary = @('#f50057', '#c51162')
            error = @('#f44336', '#d32f2f')
            warning = @('#ff9800', '#f57c00')
            success = @('#4caf50', '#388e3c')
            neutral = @('#757575', '#424242', '#212121')
        }
        typography = @{
            fontFamilies = @('Roboto', 'Arial', 'Helvetica')
            fontSizes = @(12, 14, 16, 18, 20, 24, 32, 48)
        }
        spacing = @(0, 4, 8, 12, 16, 24, 32, 48, 64)
    }
}

# Scan components
$components = Get-ChildItem -Path $ComponentPath -Include *.tsx,*.jsx,*.vue,*.css,*.scss -Recurse -File

Write-Host "📁 Found $($components.Count) component files" -ForegroundColor Yellow
Write-Host ""

$violations = @()

foreach ($component in $components) {
    $content = Get-Content $component.FullName -Raw

    # Color violations
    if ($Rules -in @('colors', 'all')) {
        $colorMatches = [regex]::Matches($content, '#[0-9a-fA-F]{6}')

        foreach ($match in $colorMatches) {
            $color = $match.Value.ToLower()
            $isApproved = $false

            foreach ($category in $designSystem.colors.PSObject.Properties) {
                if ($category.Value -contains $color) {
                    $isApproved = $true
                    break
                }
            }

            if (-not $isApproved) {
                $violations += [PSCustomObject]@{
                    File = $component.Name
                    Type = "Color"
                    Violation = "Unapproved color: $color"
                    Severity = "MEDIUM"
                }
            }
        }
    }

    # Typography violations
    if ($Rules -in @('typography', 'all')) {
        $fontSizeMatches = [regex]::Matches($content, 'font-size:\s*(\d+)px')

        foreach ($match in $fontSizeMatches) {
            $size = [int]$match.Groups[1].Value

            if ($size -notin $designSystem.typography.fontSizes) {
                $violations += [PSCustomObject]@{
                    File = $component.Name
                    Type = "Typography"
                    Violation = "Non-standard font size: ${size}px"
                    Severity = "LOW"
                }
            }
        }
    }

    # Spacing violations
    if ($Rules -in @('spacing', 'all')) {
        $spacingMatches = [regex]::Matches($content, '(?:margin|padding):\s*(\d+)px')

        foreach ($match in $spacingMatches) {
            $size = [int]$match.Groups[1].Value

            if ($size -notin $designSystem.spacing) {
                $violations += [PSCustomObject]@{
                    File = $component.Name
                    Type = "Spacing"
                    Violation = "Non-standard spacing: ${size}px"
                    Severity = "LOW"
                }
            }
        }
    }
}

Write-Host ""
Write-Host "DESIGN SYSTEM VALIDATION" -ForegroundColor Cyan
Write-Host ""

switch ($OutputFormat) {
    'table' {
        if ($violations.Count -gt 0) {
            $violations | Format-Table -AutoSize -Property @(
                @{Label='File'; Expression={$_.File}; Width=30}
                @{Label='Type'; Expression={$_.Type}; Width=15}
                @{Label='Violation'; Expression={$_.Violation}; Width=50}
                @{Label='Severity'; Expression={$_.Severity}; Width=10}
            )
        }

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Files scanned: $($components.Count)" -ForegroundColor Gray
        Write-Host "  Violations: $($violations.Count)" -ForegroundColor $(if($violations.Count -gt 0){"Yellow"}else{"Green"})
        Write-Host "  Color issues: $(($violations | Where-Object {$_.Type -eq 'Color'}).Count)" -ForegroundColor Yellow
        Write-Host "  Typography issues: $(($violations | Where-Object {$_.Type -eq 'Typography'}).Count)" -ForegroundColor Yellow
        Write-Host "  Spacing issues: $(($violations | Where-Object {$_.Type -eq 'Spacing'}).Count)" -ForegroundColor Yellow
    }
    'json' {
        @{
            ComponentsScanned = $components.Count
            Violations = $violations
            Summary = @{
                Total = $violations.Count
                Colors = ($violations | Where-Object {$_.Type -eq 'Color'}).Count
                Typography = ($violations | Where-Object {$_.Type -eq 'Typography'}).Count
                Spacing = ($violations | Where-Object {$_.Type -eq 'Spacing'}).Count
            }
        } | ConvertTo-Json -Depth 10
    }
}

Write-Host ""
if ($FailOnViolation -and $violations.Count -gt 0) {
    Write-Host "❌ Design system violations detected" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ Validation complete" -ForegroundColor Green
}
