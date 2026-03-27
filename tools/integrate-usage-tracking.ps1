# Integrate Usage Tracking - Patch all existing tools with auto-logging
# Run once to add usage tracking to all tools

param(
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false,

    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

$ToolsDir = "C:\scripts\tools"
$LoggerSnippet = @'
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

'@

Write-Host "Integrating usage tracking into all tools..." -ForegroundColor Cyan
Write-Host "  Dry Run: $DryRun" -ForegroundColor Gray
Write-Host ""

$tools = Get-ChildItem $ToolsDir -Filter "*.ps1" | Where-Object {
    $_.Name -notmatch '^_' -and  # Skip internal tools
    $_.Name -ne 'integrate-usage-tracking.ps1'  # Skip self
}

$patched = 0
$skipped = 0
$errors = 0

foreach ($tool in $tools) {
    $content = Get-Content $tool.FullName -Raw -Encoding UTF8

    # Check if already has tracking
    if ($content -match 'AUTO-USAGE TRACKING' -or $content -match '_usage-logger') {
        Write-Host "[SKIP] $($tool.Name) - Already has tracking" -ForegroundColor Yellow
        $skipped++
        continue
    }

    # Find insertion point (after param block or at start)
    $insertionPoint = 0

    if ($content -match '(?s)param\s*\([^)]*\)') {
        # Insert after param block
        $paramEnd = $Matches[0].Length + $content.IndexOf($Matches[0])
        $before = $content.Substring(0, $paramEnd)
        $after = $content.Substring($paramEnd)

        $newContent = $before + "`n`n" + $LoggerSnippet + $after
    } else {
        # Insert at start (after shebang/comments if present)
        $lines = $content -split "`n"
        $firstCodeLine = 0

        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -notmatch '^\s*#' -and $lines[$i] -match '\S') {
                $firstCodeLine = $i
                break
            }
        }

        $before = ($lines[0..($firstCodeLine - 1)] -join "`n")
        $after = ($lines[$firstCodeLine..($lines.Count - 1)] -join "`n")

        $newContent = $before + "`n`n" + $LoggerSnippet + "`n" + $after
    }

    if ($DryRun) {
        Write-Host "[DRY-RUN] Would patch: $($tool.Name)" -ForegroundColor Cyan
    } else {
        try {
            $newContent | Set-Content $tool.FullName -Encoding UTF8 -NoNewline
            Write-Host "[PATCHED] $($tool.Name)" -ForegroundColor Green
            $patched++
        } catch {
            Write-Host "[ERROR] $($tool.Name): $_" -ForegroundColor Red
            $errors++
        }
    }
}

Write-Host ""
Write-Host "SUMMARY:" -ForegroundColor Yellow
Write-Host "  Total tools: $($tools.Count)" -ForegroundColor Gray
Write-Host "  Patched: $patched" -ForegroundColor Green
Write-Host "  Skipped: $skipped" -ForegroundColor Yellow
Write-Host "  Errors: $errors" -ForegroundColor Red
Write-Host ""

if ($DryRun) {
    Write-Host "Run without -DryRun to apply patches" -ForegroundColor Cyan
} else {
    Write-Host "Usage tracking integrated!" -ForegroundColor Green
    Write-Host "All tools will now auto-log to: C:\_machine\tool-usage-log.jsonl" -ForegroundColor Gray
    Write-Host ""
    Write-Host "View dashboard: .\usage-dashboard.ps1" -ForegroundColor Cyan
}
