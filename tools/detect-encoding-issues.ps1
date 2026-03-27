#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Detects and fixes file encoding issues in JavaScript/TypeScript projects

.DESCRIPTION
    Scans project directories for files with problematic encodings (UTF-16, UTF-8 with BOM)
    that can cause Babel/Vite parse errors. Optionally fixes them to UTF-8 without BOM.

.PARAMETER ProjectPath
    Path to project directory to scan (default: current directory)

.PARAMETER Fix
    Automatically fix files to UTF-8 without BOM

.PARAMETER FileTypes
    File extensions to check (default: .ts,.tsx,.js,.jsx)

.PARAMETER Recursive
    Scan subdirectories recursively

.EXAMPLE
    detect-encoding-issues.ps1 -ProjectPath C:\Projects\client-manager\ClientManagerFrontend

.EXAMPLE
    detect-encoding-issues.ps1 -ProjectPath . -Fix -Recursive

.NOTES
    Created: 2026-01-19
    Pattern: UTF-16 encoding causing Babel parse errors
    Impact: High - causes hard-to-diagnose build failures
#>

param(
    [string]$ProjectPath = ".",
    [switch]$Fix,
    [string[]]$FileTypes = @(".ts", ".tsx", ".js", ".jsx", ".vue", ".svelte")

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
,
    [switch]$Recursive
)

$ErrorActionPreference = "Stop"

# ANSI colors
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Cyan = "`e[36m"
$Reset = "`e[0m"

function Get-FileEncoding {
    param([string]$Path)

    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)

        if ($bytes.Length -eq 0) {
            return "EMPTY"
        }

        # Check for BOM
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            return "UTF8-BOM"
        }
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            return "UTF16-LE"
        }
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
            return "UTF16-BE"
        }

        # Heuristic: Check for null bytes (common in UTF-16)
        $nullCount = ($bytes | Where-Object { $_ -eq 0 }).Count
        if ($nullCount -gt ($bytes.Length * 0.1)) {
            return "UTF16-LIKELY"
        }

        # Check if valid UTF-8
        try {
            $utf8 = [System.Text.Encoding]::UTF8.GetString($bytes)
            $roundtrip = [System.Text.Encoding]::UTF8.GetBytes($utf8)
            if ($bytes.Length -eq $roundtrip.Length) {
                return "UTF8"
            }
        } catch {
            # Not valid UTF-8
        }

        return "UNKNOWN"
    } catch {
        return "ERROR: $_"
    }
}

function Fix-FileEncoding {
    param(
        [string]$Path,
        [string]$BackupDir
    )

    try {
        # Create backup
        $backupPath = Join-Path $BackupDir (Split-Path -Leaf $Path)
        $counter = 1
        while (Test-Path $backupPath) {
            $backupPath = Join-Path $BackupDir "$($counter)_$(Split-Path -Leaf $Path)"
            $counter++
        }
        Copy-Item -Path $Path -Destination $backupPath -Force

        # Read content (PowerShell handles encoding automatically)
        $content = Get-Content -Path $Path -Raw

        # Write as UTF-8 without BOM
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($Path, $content, $utf8)

        return $true
    } catch {
        Write-Host "${Red}Failed to fix: $_${Reset}"
        return $false
    }
}

# Resolve project path
$ProjectPath = Resolve-Path $ProjectPath -ErrorAction Stop

Write-Host "${Cyan}================================${Reset}"
Write-Host "${Cyan}File Encoding Issue Detector${Reset}"
Write-Host "${Cyan}================================${Reset}"
Write-Host ""
Write-Host "Scanning: ${Blue}$ProjectPath${Reset}"
Write-Host "File types: ${Yellow}$($FileTypes -join ', ')${Reset}"
Write-Host "Recursive: ${Yellow}$Recursive${Reset}"
Write-Host "Fix mode: ${Yellow}$Fix${Reset}"
Write-Host ""

# Create backup directory if fixing
$backupDir = $null
if ($Fix) {
    $backupDir = Join-Path $ProjectPath ".encoding-backups-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Host "${Green}Backup directory: $backupDir${Reset}"
    Write-Host ""
}

# Scan files
$searchArgs = @{
    Path = $ProjectPath
    Include = $FileTypes
    File = $true
}
if ($Recursive) {
    $searchArgs['Recurse'] = $true
}

$files = Get-ChildItem @searchArgs

$issues = @()
$fixed = 0
$errors = 0

foreach ($file in $files) {
    $encoding = Get-FileEncoding -Path $file.FullName

    # Check if problematic
    $isProblematic = $encoding -in @("UTF8-BOM", "UTF16-LE", "UTF16-BE", "UTF16-LIKELY")

    if ($isProblematic) {
        $relativePath = $file.FullName.Replace($ProjectPath, "").TrimStart('\', '/')

        $issue = [PSCustomObject]@{
            Path = $relativePath
            FullPath = $file.FullName
            Encoding = $encoding
            Size = $file.Length
        }
        $issues += $issue

        $color = switch ($encoding) {
            "UTF8-BOM" { $Yellow }
            "UTF16-LE" { $Red }
            "UTF16-BE" { $Red }
            "UTF16-LIKELY" { $Red }
            default { $Red }
        }

        Write-Host "${color}[{0,-12}]${Reset} {1}" -f $encoding, $relativePath

        if ($Fix) {
            Write-Host "  → Fixing..." -NoNewline
            if (Fix-FileEncoding -Path $file.FullName -BackupDir $backupDir) {
                Write-Host " ${Green}✓${Reset}"
                $fixed++
            } else {
                Write-Host " ${Red}✗${Reset}"
                $errors++
            }
        }
    }
}

# Summary
Write-Host ""
Write-Host "${Cyan}================================${Reset}"
Write-Host "${Cyan}Summary${Reset}"
Write-Host "${Cyan}================================${Reset}"
Write-Host "Total files scanned: ${Blue}$($files.Count)${Reset}"
Write-Host "Issues found: ${Yellow}$($issues.Count)${Reset}"

if ($Fix) {
    Write-Host "Successfully fixed: ${Green}$fixed${Reset}"
    if ($errors -gt 0) {
        Write-Host "Failed to fix: ${Red}$errors${Reset}"
    }

    if ($fixed -gt 0) {
        Write-Host ""
        Write-Host "${Yellow}⚠ IMPORTANT: Restart your dev server to clear cached modules${Reset}"
        Write-Host "  - Vite: Restart ${Cyan}npm run dev${Reset}"
        Write-Host "  - Browser: Hard refresh (Ctrl+Shift+R or Ctrl+F5)"
    }
}

if ($issues.Count -gt 0 -and -not $Fix) {
    Write-Host ""
    Write-Host "${Yellow}Run with -Fix to automatically convert to UTF-8 without BOM${Reset}"
}

# Exit code
if ($errors -gt 0) {
    exit 1
}
exit 0
