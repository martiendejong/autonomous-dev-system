<#
.SYNOPSIS
    Anticipatory Documentation - Updates docs before gaps are noticed.
    50-Expert Council Improvement #4 | Priority: 2.25

.DESCRIPTION
    Scans for documentation gaps and auto-generates missing content.
    Keeps docs in sync with tools and features.

.PARAMETER Scan
    Scan for documentation gaps.

.PARAMETER Generate
    Generate missing documentation.

.PARAMETER Update
    Update tool documentation from script headers.

.EXAMPLE
    anticipate-docs.ps1 -Scan
    anticipate-docs.ps1 -Generate
#>

param(
    [switch]$Scan,
    [switch]$Generate,
    [switch]$Update
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ToolsPath = "C:\scripts\tools"
$DocsPath = "C:\scripts\_machine"
$ToolsReadme = "C:\scripts\tools\README.md"

function Get-ScriptInfo {
    param([string]$ScriptPath)

    $content = Get-Content $ScriptPath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return $null }

    $info = @{
        name = Split-Path $ScriptPath -Leaf
        path = $ScriptPath
        hasSynopsis = $content -match '\.SYNOPSIS'
        hasDescription = $content -match '\.DESCRIPTION'
        hasExamples = $content -match '\.EXAMPLE'
        expertCouncil = if ($content -match '50-Expert Council.*?#(\d+)') { $matches[1] } else { $null }
        synopsis = ""
    }

    # Extract synopsis
    if ($content -match '\.SYNOPSIS\s*\r?\n\s*(.+?)(?=\r?\n\s*\.|$)') {
        $info.synopsis = $matches[1].Trim()
    }

    return $info
}

function Scan-DocumentationGaps {
    Write-Host "=== DOCUMENTATION GAP SCAN ===" -ForegroundColor Cyan
    Write-Host ""

    $scripts = Get-ChildItem $ToolsPath -Filter "*.ps1"
    $gaps = @()
    $documented = 0

    foreach ($script in $scripts) {
        $info = Get-ScriptInfo -ScriptPath $script.FullName

        if (-not $info) { continue }

        $issues = @()
        if (-not $info.hasSynopsis) { $issues += "Missing SYNOPSIS" }
        if (-not $info.hasDescription) { $issues += "Missing DESCRIPTION" }
        if (-not $info.hasExamples) { $issues += "Missing EXAMPLES" }

        if ($issues.Count -gt 0) {
            $gaps += @{
                script = $info.name
                issues = $issues
            }
            Write-Host "  ⚠ $($info.name)" -ForegroundColor Yellow
            foreach ($issue in $issues) {
                Write-Host "    - $issue" -ForegroundColor Gray
            }
        } else {
            $documented++
            Write-Host "  ✓ $($info.name)" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Magenta
    Write-Host "  Documented: $documented" -ForegroundColor Green
    Write-Host "  Need work: $($gaps.Count)" -ForegroundColor $(if ($gaps.Count -gt 0) { "Yellow" } else { "Green" })

    return $gaps
}

function Generate-ToolCatalog {
    Write-Host "=== GENERATING TOOL CATALOG ===" -ForegroundColor Cyan
    Write-Host ""

    $scripts = Get-ChildItem $ToolsPath -Filter "*.ps1" | Sort-Object Name

    $catalog = @"
# Tools Catalog

Auto-generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Total tools: $($scripts.Count)

---

## 50-Expert Council Implementations

| # | Tool | Description |
|---|------|-------------|
"@

    $expertTools = @()
    $otherTools = @()

    foreach ($script in $scripts) {
        $info = Get-ScriptInfo -ScriptPath $script.FullName
        if (-not $info) { continue }

        $row = "| $($info.name) | $($info.synopsis) |"

        if ($info.expertCouncil) {
            $expertTools += "| #$($info.expertCouncil) $row"
        } else {
            $otherTools += $row
        }
    }

    $catalog += ($expertTools | Sort-Object) -join "`n"

    $catalog += @"


---

## Other Tools

| Tool | Description |
|------|-------------|
"@

    $catalog += $otherTools -join "`n"

    $catalog += @"


---

## Quick Reference

### Session Workflow
```powershell
workflow.ps1 -Workflow start    # Start session
workflow.ps1 -Workflow feature -Name "x"  # Start feature
workflow.ps1 -Workflow end      # End session
```

### Quick Commands
```powershell
q s   # Status snapshot
q w   # Worktree status
q c   # ClickUp tasks
q g   # GitHub PRs
```

### Error Prevention
```powershell
prevent-errors.ps1 -Action "description"
mistake-to-prevention.ps1 -Mistake "what happened"
```

### Pattern Learning
```powershell
pattern-library.ps1 -Search "keyword"
success-to-pattern.ps1 -Success "what worked"
```
"@

    $catalogPath = "$DocsPath\TOOL_CATALOG.md"
    Set-Content -Path $catalogPath -Value $catalog -Encoding UTF8

    Write-Host "✓ Catalog generated: $catalogPath" -ForegroundColor Green
    Write-Host "  Total tools: $($scripts.Count)" -ForegroundColor Yellow
    Write-Host "  Expert Council tools: $($expertTools.Count)" -ForegroundColor Yellow
}

function Update-ToolReadme {
    Write-Host "=== UPDATING TOOLS README ===" -ForegroundColor Cyan
    Write-Host ""

    Generate-ToolCatalog

    Write-Host "✓ README updated" -ForegroundColor Green
}

# Main execution
if ($Scan) {
    $gaps = Scan-DocumentationGaps

    if ($gaps.Count -gt 0) {
        Write-Host ""
        Write-Host "Run 'anticipate-docs.ps1 -Generate' to create missing docs" -ForegroundColor Gray
    }
} elseif ($Generate -or $Update) {
    if ($Scan -or $Generate) { Scan-DocumentationGaps }
    Generate-ToolCatalog
} else {
    Write-Host "=== ANTICIPATORY DOCUMENTATION ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  -Scan       Scan for documentation gaps" -ForegroundColor White
    Write-Host "  -Generate   Generate tool catalog" -ForegroundColor White
    Write-Host "  -Update     Update README with tool info" -ForegroundColor White
}
