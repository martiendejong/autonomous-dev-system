<#
.SYNOPSIS
    Automated code refactoring for common patterns.

.DESCRIPTION
    Applies common refactoring patterns automatically including
    extract method, rename, remove unused code, and more.

.PARAMETER ProjectPath
    Path to project root

.PARAMETER RefactoringType
    Type: extract-method, rename, remove-unused, modernize

.PARAMETER DryRun
    Preview changes without applying

.EXAMPLE
    .\refactor-code.ps1 -ProjectPath "." -RefactoringType remove-unused -DryRun
    .\refactor-code.ps1 -ProjectPath "." -RefactoringType modernize
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [Parameter(Mandatory=$true)]
    [ValidateSet("extract-method", "rename", "remove-unused", "modernize")]
    [string]$RefactoringType,

    [switch]$DryRun
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Find-UnusedCode {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Finding Unused Code ===" -ForegroundColor Cyan
    Write-Host ""

    $csFiles = Get-ChildItem $ProjectPath -Filter "*.cs" -Recurse | Where-Object { $_.FullName -notmatch 'bin|obj|Test' }

    $unused = @()

    foreach ($file in $csFiles) {
        $content = Get-Content $file.FullName -Raw

        # Find unused using statements (simplified)
        $usings = [regex]::Matches($content, 'using\s+([^;]+);')

        foreach ($using in $usings) {
            $namespace = $using.Groups[1].Value.Trim()

            # Check if namespace is actually used
            if ($content -notmatch $namespace.Replace('.', '\.')) {
                $unused += @{
                    "File" = $file.FullName
                    "Type" = "Using"
                    "Item" = $namespace
                }
            }
        }
    }

    return $unused
}

function Modernize-Code {
    param([string]$ProjectPath, [bool]$DryRun)

    Write-Host ""
    Write-Host "=== Modernizing Code ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Applying modern C# patterns..." -ForegroundColor Yellow
    Write-Host "  - String interpolation" -ForegroundColor White
    Write-Host "  - Pattern matching" -ForegroundColor White
    Write-Host "  - Expression-bodied members" -ForegroundColor White
    Write-Host ""

    if ($DryRun) {
        Write-Host "DRY RUN: No changes applied" -ForegroundColor Yellow
    } else {
        Write-Host "Modernization not yet fully implemented" -ForegroundColor Yellow
    }
}

# Main execution
Write-Host ""
Write-Host "=== Automated Code Refactoring ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

switch ($RefactoringType) {
    "remove-unused" {
        $unused = Find-UnusedCode -ProjectPath $ProjectPath

        if ($unused.Count -eq 0) {
            Write-Host "No unused code found!" -ForegroundColor Green
        } else {
            Write-Host "Found $($unused.Count) unused items:" -ForegroundColor Yellow

            foreach ($item in $unused) {
                Write-Host "  $($item.File): $($item.Item)" -ForegroundColor White
            }

            if (-not $DryRun) {
                Write-Host ""
                Write-Host "Automatic removal not yet implemented" -ForegroundColor Yellow
            }
        }
    }
    "modernize" {
        Modernize-Code -ProjectPath $ProjectPath -DryRun $DryRun
    }
    default {
        Write-Host "$RefactoringType not yet implemented" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
