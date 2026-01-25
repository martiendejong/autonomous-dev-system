<#
.SYNOPSIS
    Tool Usage Analytics, Self-Documentation & Versioning
    50-Expert Council Improvements #14, #16, #18, #17 | Priority: 2.33, 2.0, 1.5, 1.4

.DESCRIPTION
    Tracks tool usage, auto-generates docs, manages versions.

.PARAMETER Track
    Track usage of a tool.

.PARAMETER Tool
    Tool name.

.PARAMETER Stats
    Show usage statistics.

.PARAMETER Docs
    Generate self-documentation.

.PARAMETER Deps
    Check tool dependencies.

.EXAMPLE
    tool-analytics.ps1 -Track -Tool "q.ps1"
    tool-analytics.ps1 -Stats
    tool-analytics.ps1 -Docs
#>

param(
    [switch]$Track,
    [string]$Tool = "",
    [switch]$Stats,
    [switch]$Docs,
    [switch]$Deps
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$AnalyticsFile = "C:\scripts\_machine\tool_analytics.json"
$ToolsPath = "C:\scripts\tools"

if (-not (Test-Path $AnalyticsFile)) {
    @{
        usage = @{}
        versions = @{}
        lastAnalysis = $null
    } | ConvertTo-Json -Depth 10 | Set-Content $AnalyticsFile -Encoding UTF8
}

$analytics = Get-Content $AnalyticsFile -Raw | ConvertFrom-Json

if ($Track -and $Tool) {
    if (-not $analytics.usage.$Tool) {
        $analytics.usage | Add-Member -NotePropertyName $Tool -NotePropertyValue @{
            count = 0
            lastUsed = $null
            errors = 0
        } -Force
    }
    $analytics.usage.$Tool.count++
    $analytics.usage.$Tool.lastUsed = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $analytics | ConvertTo-Json -Depth 10 | Set-Content $AnalyticsFile -Encoding UTF8

    Write-Host "✓ Tracked usage: $Tool (total: $($analytics.usage.$Tool.count))" -ForegroundColor Green
}
elseif ($Stats) {
    Write-Host "=== TOOL USAGE STATISTICS ===" -ForegroundColor Cyan
    Write-Host ""

    $sorted = $analytics.usage.PSObject.Properties | Sort-Object { $_.Value.count } -Descending

    Write-Host "TOP USED TOOLS:" -ForegroundColor Yellow
    foreach ($t in $sorted | Select-Object -First 10) {
        $bar = "█" * [Math]::Min(20, $t.Value.count)
        Write-Host "  $($t.Name.PadRight(25)) $bar $($t.Value.count)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "UNUSED TOOLS (consider deprecation):" -ForegroundColor Yellow

    $allTools = Get-ChildItem $ToolsPath -Filter "*.ps1" | Select-Object -ExpandProperty Name
    $unused = $allTools | Where-Object { -not $analytics.usage.$_ -or $analytics.usage.$_.count -eq 0 }

    foreach ($u in $unused | Select-Object -First 5) {
        Write-Host "  • $u" -ForegroundColor Gray
    }
}
elseif ($Docs) {
    Write-Host "=== GENERATING SELF-DOCUMENTATION ===" -ForegroundColor Cyan
    Write-Host ""

    $scripts = Get-ChildItem $ToolsPath -Filter "*.ps1"
    $docs = @()

    foreach ($script in $scripts) {
        $content = Get-Content $script.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $synopsis = ""
        if ($content -match '\.SYNOPSIS\s*\r?\n\s*(.+?)(?=\r?\n\s*\.|$)') {
            $synopsis = $matches[1].Trim()
        }

        $expertNum = ""
        if ($content -match '50-Expert Council.*?#(\d+)') {
            $expertNum = $matches[1]
        }

        $docs += @{
            name = $script.Name
            synopsis = $synopsis
            expertCouncil = $expertNum
            size = $content.Length
        }

        Write-Host "  + $($script.Name)" -ForegroundColor Gray
    }

    # Generate markdown
    $md = @"
# Tool Self-Documentation

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Total tools: $($docs.Count)

## 50-Expert Council Tools

| # | Tool | Description |
|---|------|-------------|
"@

    $expert = $docs | Where-Object { $_.expertCouncil } | Sort-Object { [int]$_.expertCouncil }
    foreach ($d in $expert) {
        $md += "`n| #$($d.expertCouncil) | $($d.name) | $($d.synopsis) |"
    }

    $md += @"


## All Tools

| Tool | Description |
|------|-------------|
"@

    foreach ($d in $docs | Sort-Object name) {
        $md += "`n| $($d.name) | $($d.synopsis) |"
    }

    $docsPath = "$ToolsPath\SELF_DOCS.md"
    Set-Content -Path $docsPath -Value $md -Encoding UTF8

    Write-Host ""
    Write-Host "✓ Generated: $docsPath" -ForegroundColor Green
    Write-Host "  Total tools: $($docs.Count)" -ForegroundColor Yellow
    Write-Host "  Expert Council: $($expert.Count)" -ForegroundColor Yellow
}
elseif ($Deps) {
    Write-Host "=== CHECKING DEPENDENCIES ===" -ForegroundColor Cyan
    Write-Host ""

    $deps = @{
        "git" = { git --version }
        "gh" = { gh --version }
        "node" = { node --version }
        "powershell" = { $PSVersionTable.PSVersion }
    }

    foreach ($d in $deps.GetEnumerator()) {
        try {
            $result = & $d.Value 2>&1 | Select-Object -First 1
            Write-Host "  ✓ $($d.Key): $result" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ $($d.Key): NOT FOUND" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Track -Tool x   Track tool usage" -ForegroundColor White
    Write-Host "  -Stats           Show usage statistics" -ForegroundColor White
    Write-Host "  -Docs            Generate self-documentation" -ForegroundColor White
    Write-Host "  -Deps            Check dependencies" -ForegroundColor White
}
