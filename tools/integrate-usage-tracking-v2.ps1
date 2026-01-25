# Integrate Usage Tracking V2 - FIXED param block detection
# Properly handles multi-line param blocks with nested parentheses

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

Write-Host "Integrating usage tracking into all tools (V2 - FIXED)..." -ForegroundColor Cyan
Write-Host "  Dry Run: $DryRun" -ForegroundColor Gray
Write-Host ""

function Find-ParamBlockEnd {
    param([string]$Content)

    # Find param( start
    if ($Content -notmatch 'param\s*\(') {
        return -1
    }

    $paramStart = $Content.IndexOf('param')
    $parenStart = $Content.IndexOf('(', $paramStart)

    # Count parentheses to find matching closing )
    $depth = 1
    $i = $parenStart + 1

    while ($i -lt $Content.Length -and $depth -gt 0) {
        $char = $Content[$i]

        if ($char -eq '(') {
            $depth++
        } elseif ($char -eq ')') {
            $depth--
        }

        $i++
    }

    if ($depth -eq 0) {
        return $i  # Position right after closing )
    }

    return -1  # No matching ) found
}

$tools = Get-ChildItem $ToolsDir -Filter "*.ps1" | Where-Object {
    $_.Name -notmatch '^_' -and
    $_.Name -ne 'integrate-usage-tracking.ps1' -and
    $_.Name -ne 'integrate-usage-tracking-v2.ps1' -and
    $_.Name -ne 'rollback-usage-tracking.ps1'
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

    # Find insertion point
    $paramEnd = Find-ParamBlockEnd -Content $content

    if ($paramEnd -gt 0) {
        # Insert after param block
        $before = $content.Substring(0, $paramEnd)
        $after = $content.Substring($paramEnd)
        $newContent = $before + $LoggerSnippet + $after
    } else {
        # No param block - insert at start after comments
        $lines = $content -split "`n"
        $firstCodeLine = 0

        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -notmatch '^\s*#' -and $lines[$i] -notmatch '^\s*<#' -and $lines[$i] -match '\S') {
                $firstCodeLine = $i
                break
            }
        }

        if ($firstCodeLine -eq 0) {
            $newContent = $LoggerSnippet + "`n" + $content
        } else {
            $before = ($lines[0..($firstCodeLine - 1)] -join "`n")
            $after = ($lines[$firstCodeLine..($lines.Count - 1)] -join "`n")
            $newContent = $before + "`n" + $LoggerSnippet + "`n" + $after
        }
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
    Write-Host "Usage tracking integrated successfully!" -ForegroundColor Green
    Write-Host "All tools will now auto-log to: C:\_machine\tool-usage-log.jsonl" -ForegroundColor Gray
    Write-Host ""
    Write-Host "View dashboard: .\usage-dashboard.ps1" -ForegroundColor Cyan
}
