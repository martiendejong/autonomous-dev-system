<#
.SYNOPSIS
    Anti-Pattern Detector
    50-Expert Council V2 Improvement #5 | Priority: 1.8

.DESCRIPTION
    Identifies known bad patterns with fix suggestions.

.PARAMETER Scan
    Scan for anti-patterns.

.PARAMETER Path
    Path to scan.

.EXAMPLE
    anti-pattern.ps1 -Scan -Path "src/"
#>

param(
    [switch]$Scan,
    [string]$Path = ".",
    [switch]$Verbose
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$patterns = @(
    @{
        name = "God Class"
        pattern = 'class\s+\w+[^{]*\{[^}]{5000,}'
        fix = "Split into smaller, focused classes"
        severity = "high"
    },
    @{
        name = "Empty Catch"
        pattern = 'catch\s*\([^)]*\)\s*\{\s*\}'
        fix = "Add error logging or handling"
        severity = "high"
    },
    @{
        name = "Magic String"
        pattern = '(==|!=)\s*"[a-z]{3,}"'
        fix = "Use constants or enums"
        severity = "medium"
    },
    @{
        name = "Nested Callbacks"
        pattern = '\)\s*=>\s*\{[^}]*\)\s*=>\s*\{[^}]*\)\s*=>'
        fix = "Use async/await or extract functions"
        severity = "high"
    },
    @{
        name = "Long Parameter List"
        pattern = '\([^)]{200,}\)'
        fix = "Use parameter object pattern"
        severity = "medium"
    },
    @{
        name = "Hardcoded URL"
        pattern = '(http|https)://[a-zA-Z0-9./-]+'
        fix = "Use configuration"
        severity = "medium"
    },
    @{
        name = "Console in Production"
        pattern = 'console\.(log|debug|info|warn)'
        fix = "Use proper logging"
        severity = "low"
    },
    @{
        name = "Synchronous in Async"
        pattern = '\.Result\b|\.Wait\(\)'
        fix = "Use await instead"
        severity = "high"
    },
    @{
        name = "String Concatenation in Loop"
        pattern = 'for.*\+='
        fix = "Use StringBuilder or join"
        severity = "medium"
    },
    @{
        name = "Primitive Obsession"
        pattern = 'string\s+(email|phone|url|id)\b'
        fix = "Create value object type"
        severity = "low"
    }
)

if ($Scan) {
    Write-Host "=== ANTI-PATTERN DETECTOR ===" -ForegroundColor Cyan
    Write-Host ""

    $files = Get-ChildItem -Path $Path -Recurse -Include "*.cs", "*.ts", "*.tsx", "*.js" -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -notmatch 'node_modules|bin|obj|dist|\.d\.ts$' }

    $findings = @()

    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        foreach ($p in $patterns) {
            $matches = [regex]::Matches($content, $p.pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($matches.Count -gt 0) {
                $findings += @{
                    file = $file.Name
                    pattern = $p.name
                    count = $matches.Count
                    fix = $p.fix
                    severity = $p.severity
                }
            }
        }
    }

    # Summary
    Write-Host "ANTI-PATTERN ANALYSIS" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Files scanned: $($files.Count)" -ForegroundColor White
    Write-Host "  Patterns checked: $($patterns.Count)" -ForegroundColor White
    Write-Host "  Issues found: $($findings.Count)" -ForegroundColor $(if ($findings.Count -gt 20) { "Red" } elseif ($findings.Count -gt 10) { "Yellow" } else { "Green" })
    Write-Host ""

    # By severity
    $high = ($findings | Where-Object { $_.severity -eq "high" }).Count
    $medium = ($findings | Where-Object { $_.severity -eq "medium" }).Count
    $low = ($findings | Where-Object { $_.severity -eq "low" }).Count

    Write-Host "BY SEVERITY:" -ForegroundColor Yellow
    Write-Host "  🔴 High: $high" -ForegroundColor Red
    Write-Host "  🟡 Medium: $medium" -ForegroundColor Yellow
    Write-Host "  🟢 Low: $low" -ForegroundColor Green
    Write-Host ""

    # By pattern type
    $byPattern = $findings | Group-Object pattern | Sort-Object Count -Descending
    Write-Host "BY PATTERN:" -ForegroundColor Yellow
    foreach ($g in $byPattern | Select-Object -First 10) {
        $color = switch (($findings | Where-Object { $_.pattern -eq $g.Name } | Select-Object -First 1).severity) {
            "high" { "Red" }
            "medium" { "Yellow" }
            default { "White" }
        }
        Write-Host "  $($g.Name): $($g.Count)" -ForegroundColor $color
    }

    if ($Verbose) {
        Write-Host ""
        Write-Host "DETAILED FINDINGS:" -ForegroundColor Yellow
        foreach ($f in $findings | Sort-Object severity | Select-Object -First 20) {
            $icon = switch ($f.severity) { "high" { "🔴" } "medium" { "🟡" } default { "🟢" } }
            Write-Host "  $icon $($f.pattern) in $($f.file)" -ForegroundColor White
            Write-Host "     Fix: $($f.fix)" -ForegroundColor Gray
        }
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Scan -Path 'x'     Scan for anti-patterns" -ForegroundColor White
    Write-Host "  -Verbose            Show detailed findings" -ForegroundColor White
}
