<#
.SYNOPSIS
    Technical Debt Quantifier
    50-Expert Council V2 Improvement #2 | Priority: 1.8

.DESCRIPTION
    Calculates technical debt in hours, tracks over time.

.PARAMETER Scan
    Scan for technical debt.

.PARAMETER Path
    Path to scan.

.PARAMETER Track
    Track debt over time.

.EXAMPLE
    tech-debt.ps1 -Scan -Path "src/"
#>

param(
    [switch]$Scan,
    [string]$Path = ".",
    [switch]$Track,
    [switch]$Trends
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$DebtFile = "C:\scripts\_machine\tech_debt.json"

if (-not (Test-Path $DebtFile)) {
    @{
        scans = @()
        currentDebt = 0
    } | ConvertTo-Json -Depth 10 | Set-Content $DebtFile -Encoding UTF8
}

$data = Get-Content $DebtFile -Raw | ConvertFrom-Json

function Estimate-DebtHours {
    param($Issues)

    $hours = 0

    foreach ($i in $Issues) {
        $hours += switch ($i.type) {
            "todo" { 0.5 }
            "fixme" { 1 }
            "hack" { 2 }
            "complexity" { 4 }
            "duplicate" { 1 }
            "deprecated" { 0.5 }
            "no-tests" { 2 }
            "magic-number" { 0.25 }
            default { 0.5 }
        }
    }

    return $hours
}

if ($Scan) {
    Write-Host "=== TECHNICAL DEBT SCANNER ===" -ForegroundColor Cyan
    Write-Host ""

    $files = Get-ChildItem -Path $Path -Recurse -Include "*.cs", "*.ts", "*.tsx", "*.js" -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -notmatch 'node_modules|bin|obj|dist' }

    $issues = @()

    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $fileName = $file.Name

        # TODO comments
        $todos = [regex]::Matches($content, '//\s*TODO[:\s](.{0,50})')
        foreach ($m in $todos) {
            $issues += @{ type = "todo"; file = $fileName; text = $m.Groups[1].Value.Trim() }
        }

        # FIXME comments
        $fixmes = [regex]::Matches($content, '//\s*FIXME[:\s](.{0,50})')
        foreach ($m in $fixmes) {
            $issues += @{ type = "fixme"; file = $fileName; text = $m.Groups[1].Value.Trim() }
        }

        # HACK comments
        $hacks = [regex]::Matches($content, '//\s*HACK[:\s](.{0,50})')
        foreach ($m in $hacks) {
            $issues += @{ type = "hack"; file = $fileName; text = $m.Groups[1].Value.Trim() }
        }

        # Deprecated usage
        if ($content -match '\[Obsolete\]|\[Deprecated\]') {
            $issues += @{ type = "deprecated"; file = $fileName; text = "Uses deprecated code" }
        }

        # Magic numbers (simplified)
        $magics = [regex]::Matches($content, '(?<![\w.])([2-9]\d{2,}|[1-9]\d{3,})(?![\w])')
        if ($magics.Count -gt 5) {
            $issues += @{ type = "magic-number"; file = $fileName; text = "$($magics.Count) magic numbers" }
        }
    }

    $totalHours = Estimate-DebtHours $issues

    Write-Host "TECHNICAL DEBT REPORT" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Files scanned: $($files.Count)" -ForegroundColor White
    Write-Host "  Issues found: $($issues.Count)" -ForegroundColor Yellow
    Write-Host "  Estimated debt: $([Math]::Round($totalHours, 1)) hours" -ForegroundColor $(if ($totalHours -gt 40) { "Red" } elseif ($totalHours -gt 20) { "Yellow" } else { "Green" })
    Write-Host ""

    # Group by type
    $byType = $issues | Group-Object type
    Write-Host "BY TYPE:" -ForegroundColor Yellow
    foreach ($g in $byType | Sort-Object Count -Descending) {
        $typeHours = Estimate-DebtHours $g.Group
        Write-Host "  $($g.Name): $($g.Count) (~$([Math]::Round($typeHours, 1))h)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "SAMPLE ISSUES:" -ForegroundColor Yellow
    $issues | Select-Object -First 10 | ForEach-Object {
        Write-Host "  [$($_.type)] $($_.file): $($_.text)" -ForegroundColor Gray
    }

    if ($Track) {
        $data.scans += @{
            date = (Get-Date).ToString("yyyy-MM-dd")
            issues = $issues.Count
            hours = $totalHours
            path = $Path
        }
        $data.currentDebt = $totalHours
        $data | ConvertTo-Json -Depth 10 | Set-Content $DebtFile -Encoding UTF8

        Write-Host ""
        Write-Host "✓ Debt tracked for trending" -ForegroundColor Green
    }
}
elseif ($Trends) {
    Write-Host "=== TECHNICAL DEBT TRENDS ===" -ForegroundColor Cyan
    Write-Host ""

    if ($data.scans.Count -eq 0) {
        Write-Host "No scans recorded. Run: tech-debt.ps1 -Scan -Track" -ForegroundColor Yellow
        return
    }

    foreach ($scan in $data.scans | Select-Object -Last 10) {
        $bar = "█" * [Math]::Min(30, [Math]::Round($scan.hours))
        Write-Host "  $($scan.date) [$bar] $($scan.hours)h ($($scan.issues) issues)" -ForegroundColor Gray
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Scan -Path 'x'     Scan for debt" -ForegroundColor White
    Write-Host "  -Track              Save for trending" -ForegroundColor White
    Write-Host "  -Trends             Show debt over time" -ForegroundColor White
}
