<#
.SYNOPSIS
    Remove trailing whitespace from markdown files.

.DESCRIPTION
    Scans markdown files and removes trailing whitespace from each line.
    Common documentation quality issue that triggers warnings.

.PARAMETER Path
    Directory to scan (default: C:\scripts)

.PARAMETER DryRun
    Show what would be changed without making changes

.PARAMETER Verbose
    Show detailed output

.EXAMPLE
    .\trim-whitespace.ps1
    .\trim-whitespace.ps1 -DryRun
    .\trim-whitespace.ps1 -Path "C:\scripts\_machine"
#>

param(
    [string]$Path = "C:\scripts",
    [switch]$DryRun
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


Write-Host ""
Write-Host "=== WHITESPACE TRIMMER ===" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "Mode: DRY RUN" -ForegroundColor Yellow
}
Write-Host ""

$files = Get-ChildItem $Path -Filter "*.md" -Recurse
$fixedCount = 0
$fileCount = 0

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    # Check for trailing whitespace
    if ($content -match '[ \t]+$' -or $content -match '[ \t]+\r?\n') {
        $fileCount++

        # Fix trailing whitespace on each line
        $lines = $content -split "`r?`n"
        $trimmed = $lines | ForEach-Object { $_.TrimEnd() }
        $newContent = $trimmed -join "`n"

        # Also ensure file ends with single newline
        $newContent = $newContent.TrimEnd() + "`n"

        if ($newContent -ne $content) {
            if (-not $DryRun) {
                $newContent | Set-Content $file.FullName -NoNewline -Encoding UTF8
                Write-Host "[FIXED] $($file.Name)" -ForegroundColor Green
                $fixedCount++
            } else {
                Write-Host "[WOULD FIX] $($file.Name)" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Files scanned: $($files.Count)"
Write-Host "Files with whitespace issues: $fileCount"
if ($DryRun) {
    Write-Host "Would fix: $fileCount files" -ForegroundColor Yellow
} else {
    Write-Host "Fixed: $fixedCount files" -ForegroundColor Green
}
Write-Host ""
