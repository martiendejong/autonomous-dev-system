#!/usr/bin/env pwsh
# Fix UTF-16 encoded files in the frontend

param(
    [string]$Path = "C:\Projects\client-manager\ClientManagerFrontend\src",
    [switch]$DryRun
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


Write-Host "Scanning for UTF-16 encoded files..." -ForegroundColor Cyan

$utf16Files = @()
$utf8BomFiles = @()

# Find all .ts and .tsx files
Get-ChildItem -Path $Path -Recurse -Include *.ts,*.tsx | ForEach-Object {
    $file = $_.FullName

    # Read first few bytes to detect encoding
    $bytes = Get-Content -Path $file -Encoding Byte -TotalCount 3

    # Check for UTF-16 LE BOM (FF FE)
    if ($bytes.Count -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $utf16Files += $file
        Write-Host "  UTF-16 LE: $($_.FullName.Replace($Path, '.'))" -ForegroundColor Yellow
    }
    # Check for UTF-8 BOM (EF BB BF)
    elseif ($bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $utf8BomFiles += $file
        Write-Host "  UTF-8 BOM: $($_.FullName.Replace($Path, '.'))" -ForegroundColor Magenta
    }
}

Write-Host "`nFound:" -ForegroundColor Cyan
Write-Host "  UTF-16 files: $($utf16Files.Count)" -ForegroundColor Yellow
Write-Host "  UTF-8 with BOM files: $($utf8BomFiles.Count)" -ForegroundColor Magenta

if ($DryRun) {
    Write-Host "`nDry run - no changes made" -ForegroundColor Green
    exit 0
}

# Fix UTF-16 files
if ($utf16Files.Count -gt 0) {
    Write-Host "`nConverting UTF-16 files to UTF-8..." -ForegroundColor Cyan
    foreach ($file in $utf16Files) {
        try {
            # Read as UTF-16 LE
            $content = Get-Content -Path $file -Encoding Unicode -Raw
            # Write as UTF-8 without BOM
            [System.IO.File]::WriteAllText($file, $content, (New-Object System.Text.UTF8Encoding $false))
            Write-Host "  ✓ Fixed: $($file.Replace($Path, '.'))" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ Error: $($file.Replace($Path, '.')): $_" -ForegroundColor Red
        }
    }
}

# Fix UTF-8 BOM files
if ($utf8BomFiles.Count -gt 0) {
    Write-Host "`nRemoving BOM from UTF-8 files..." -ForegroundColor Cyan
    foreach ($file in $utf8BomFiles) {
        try {
            # Read as UTF-8 with BOM
            $content = Get-Content -Path $file -Encoding UTF8 -Raw
            # Write as UTF-8 without BOM
            [System.IO.File]::WriteAllText($file, $content, (New-Object System.Text.UTF8Encoding $false))
            Write-Host "  ✓ Fixed: $($file.Replace($Path, '.'))" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ Error: $($file.Replace($Path, '.')): $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nAll files fixed!" -ForegroundColor Green
