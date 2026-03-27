<#
.SYNOPSIS
    Generate a complete index of all available tools.

.DESCRIPTION
    Scans the tools directory and generates documentation for all tools,
    extracting synopsis from comment-based help.

.PARAMETER Format
    Output format: text, markdown, or json

.PARAMETER OutputFile
    Optional file to write output to

.EXAMPLE
    .\generate-tool-index.ps1
    .\generate-tool-index.ps1 -Format markdown -OutputFile "TOOLS_INDEX.md"
    .\generate-tool-index.ps1 -Format json
#>

param(
    [ValidateSet("text", "markdown", "json")

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
]
    [string]$Format = "text",
    [string]$OutputFile
)

$ToolsPath = "C:\scripts\tools"

# Get all .ps1 files (excluding node_modules and subdirectories)
$tools = Get-ChildItem $ToolsPath -Filter "*.ps1" -File | Sort-Object Name

$toolData = @()

foreach ($tool in $tools) {
    $content = Get-Content $tool.FullName -Raw -ErrorAction SilentlyContinue
    $synopsis = ""
    $hasHelp = $false

    # Extract synopsis from comment-based help
    if ($content -match '\.SYNOPSIS\s*\r?\n\s*(.+?)(?=\r?\n\s*\.|$)') {
        $synopsis = $matches[1].Trim()
        $hasHelp = $true
    }

    # Fallback: try to get first comment line
    if (-not $synopsis -and $content -match '^#\s*(.+)$') {
        $synopsis = $matches[1]
    }

    $toolData += @{
        Name = $tool.BaseName
        FileName = $tool.Name
        Synopsis = $synopsis
        HasHelp = $hasHelp
    }
}

# Output based on format
switch ($Format) {
    "json" {
        $output = @{
            generated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            total = $toolData.Count
            withHelp = ($toolData | Where-Object { $_.HasHelp }).Count
            tools = $toolData
        } | ConvertTo-Json -Depth 3

        if ($OutputFile) {
            $output | Set-Content $OutputFile -Encoding UTF8
            Write-Host "Written to: $OutputFile"
        } else {
            $output
        }
    }

    "markdown" {
        $md = @"
# Tool Index

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm")
**Total Tools:** $($toolData.Count)
**With Help:** $(($toolData | Where-Object { $_.HasHelp }).Count)

## Available Tools

| Tool | Description |
|------|-------------|
"@
        foreach ($t in $toolData) {
            $desc = if ($t.Synopsis) { $t.Synopsis } else { "_(no description)_" }
            $md += "`n| ``$($t.Name).ps1`` | $desc |"
        }

        $md += @"

---

## Quick Reference

### System Management
``````powershell
.\system-health.ps1      # Check system health
.\fix-all.ps1            # One-command repair
.\maintenance.ps1        # Run maintenance tasks
``````

### Worktree Management
``````powershell
.\worktree-status.ps1    # Check pool status
.\worktree-allocate.ps1  # Allocate seat
.\worktree-release-all.ps1 # Release seats
.\worktree-cleanup.ps1   # Clean orphaned worktrees
``````

### Documentation
``````powershell
.\doc-lint.ps1           # Lint documentation
.\trim-whitespace.ps1    # Fix trailing whitespace
``````

### Development
``````powershell
.\cs-format.ps1          # Format C# code
.\smoke-test.ps1         # Run tool tests
.\new-tool.ps1           # Generate new tool
``````
"@

        if ($OutputFile) {
            $md | Set-Content $OutputFile -Encoding UTF8
            Write-Host "Written to: $OutputFile"
        } else {
            $md
        }
    }

    "text" {
        Write-Host ""
        Write-Host "=== TOOL INDEX ===" -ForegroundColor Cyan
        Write-Host "Total: $($toolData.Count) tools" -ForegroundColor DarkGray
        Write-Host ""

        foreach ($t in $toolData) {
            $helpIcon = if ($t.HasHelp) { "[OK]" } else { "[--]" }
            $color = if ($t.HasHelp) { "Green" } else { "Yellow" }
            Write-Host "$helpIcon " -NoNewline -ForegroundColor $color
            Write-Host "$($t.Name)" -NoNewline -ForegroundColor White
            if ($t.Synopsis) {
                Write-Host " - $($t.Synopsis)" -ForegroundColor DarkGray
            } else {
                Write-Host "" -ForegroundColor DarkGray
            }
        }

        Write-Host ""
        Write-Host "Legend: [OK] = has help, [--] = missing help" -ForegroundColor DarkGray
        Write-Host ""
    }
}
