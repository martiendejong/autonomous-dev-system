<#
.SYNOPSIS
    Tool Composition Engine & Natural Language Invocation
    50-Expert Council Improvements #12, #20 | Priority: 1.8, 2.0

.DESCRIPTION
    Chains tools together declaratively.
    Supports natural language tool invocation.

.PARAMETER Chain
    Array of tools to chain together.

.PARAMETER NL
    Natural language command to interpret.

.PARAMETER Save
    Save a named composition.

.PARAMETER Name
    Name for saved composition.

.PARAMETER Run
    Run a saved composition.

.EXAMPLE
    tool-compose.ps1 -Chain @("q s", "predict-tasks.ps1 -Show")
    tool-compose.ps1 -NL "check status and predict tasks"
    tool-compose.ps1 -Save -Name "morning" -Chain @("workflow.ps1 -Workflow start")
#>

param(
    [string[]]$Chain = @()

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
,
    [string]$NL = "",
    [switch]$Save,
    [string]$Name = "",
    [switch]$Run,
    [switch]$List
)

$CompositionsFile = "C:\scripts\_machine\tool_compositions.json"
$ToolsPath = "C:\scripts\tools"

if (-not (Test-Path $CompositionsFile)) {
    @{
        compositions = @{
            "morning" = @("workflow.ps1 -Workflow start")
            "evening" = @("workflow.ps1 -Workflow end")
            "status" = @("q.ps1 s", "predict-tasks.ps1 -Show")
            "safety" = @("prevent-errors.ps1 -List", "reflect.ps1 -CheckOnly")
        }
    } | ConvertTo-Json -Depth 10 | Set-Content $CompositionsFile -Encoding UTF8
}

$comps = Get-Content $CompositionsFile -Raw | ConvertFrom-Json

function Parse-NaturalLanguage {
    param([string]$Text)

    $lower = $Text.ToLower()
    $commands = @()

    # Pattern matching for common phrases
    if ($lower -match 'check.*status|show.*status|status') {
        $commands += "q.ps1 s"
    }
    if ($lower -match 'predict|forecast|next.*task') {
        $commands += "predict-tasks.ps1 -Show"
    }
    if ($lower -match 'reflect|pause|think') {
        $commands += "reflect.ps1 -CheckOnly"
    }
    if ($lower -match 'prevent.*error|check.*safe') {
        $commands += "prevent-errors.ps1 -List"
    }
    if ($lower -match 'pattern|solution') {
        $commands += "pattern-library.ps1 -List"
    }
    if ($lower -match 'worktree') {
        $commands += "worktree-status.ps1 -Compact"
    }
    if ($lower -match 'github|pr') {
        $commands += "q.ps1 g"
    }
    if ($lower -match 'clickup|task') {
        $commands += "q.ps1 c"
    }
    if ($lower -match 'start.*session|begin.*day|morning') {
        $commands += "workflow.ps1 -Workflow start"
    }
    if ($lower -match 'end.*session|finish.*day|evening') {
        $commands += "workflow.ps1 -Workflow end"
    }

    return $commands
}

function Execute-Chain {
    param([string[]]$Commands)

    Write-Host "=== EXECUTING TOOL CHAIN ===" -ForegroundColor Cyan
    Write-Host ""

    $results = @()
    foreach ($cmd in $Commands) {
        Write-Host "→ $cmd" -ForegroundColor Yellow
        Write-Host ""

        try {
            if ($cmd -match '^q\.ps1\s+(\w)$') {
                & "$ToolsPath\q.ps1" $matches[1]
            } else {
                $parts = $cmd -split '\s+', 2
                $script = $parts[0]
                $args = if ($parts.Count -gt 1) { $parts[1] } else { "" }

                if ($script -notmatch '\.ps1$') { $script += ".ps1" }
                $scriptPath = Join-Path $ToolsPath $script

                if (Test-Path $scriptPath) {
                    if ($args) {
                        Invoke-Expression "& `"$scriptPath`" $args"
                    } else {
                        & $scriptPath
                    }
                } else {
                    Write-Host "  Script not found: $script" -ForegroundColor Red
                }
            }
            $results += @{ cmd = $cmd; status = "success" }
        } catch {
            Write-Host "  Error: $_" -ForegroundColor Red
            $results += @{ cmd = $cmd; status = "failed"; error = $_.ToString() }
        }

        Write-Host ""
        Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
    }

    return $results
}

if ($Chain.Count -gt 0) {
    Execute-Chain -Commands $Chain
}
elseif ($NL) {
    Write-Host "=== NATURAL LANGUAGE INTERPRETATION ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Input: `"$NL`"" -ForegroundColor Yellow
    Write-Host ""

    $commands = Parse-NaturalLanguage -Text $NL

    if ($commands.Count -eq 0) {
        Write-Host "Could not interpret. Try:" -ForegroundColor Yellow
        Write-Host "  'check status'" -ForegroundColor Gray
        Write-Host "  'predict tasks'" -ForegroundColor Gray
        Write-Host "  'start session'" -ForegroundColor Gray
    } else {
        Write-Host "Interpreted as:" -ForegroundColor Magenta
        foreach ($c in $commands) {
            Write-Host "  $c" -ForegroundColor White
        }
        Write-Host ""

        Execute-Chain -Commands $commands
    }
}
elseif ($Save -and $Name -and $Chain.Count -gt 0) {
    $comps.compositions | Add-Member -NotePropertyName $Name -NotePropertyValue $Chain -Force
    $comps | ConvertTo-Json -Depth 10 | Set-Content $CompositionsFile -Encoding UTF8

    Write-Host "✓ Saved composition: $Name" -ForegroundColor Green
    Write-Host "  Commands: $($Chain -join ' → ')" -ForegroundColor Gray
}
elseif ($Run -and $Name) {
    $chain = $comps.compositions.$Name
    if (-not $chain) {
        Write-Host "Composition not found: $Name" -ForegroundColor Red
        return
    }

    Write-Host "Running composition: $Name" -ForegroundColor Cyan
    Execute-Chain -Commands $chain
}
elseif ($List) {
    Write-Host "=== SAVED COMPOSITIONS ===" -ForegroundColor Cyan
    Write-Host ""

    foreach ($c in $comps.compositions.PSObject.Properties) {
        Write-Host "$($c.Name):" -ForegroundColor Yellow
        foreach ($cmd in $c.Value) {
            Write-Host "  → $cmd" -ForegroundColor White
        }
        Write-Host ""
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Chain @('cmd1', 'cmd2')   Execute tool chain" -ForegroundColor White
    Write-Host "  -NL 'natural language'     Interpret and execute" -ForegroundColor White
    Write-Host "  -Save -Name x -Chain @()   Save composition" -ForegroundColor White
    Write-Host "  -Run -Name x               Run saved composition" -ForegroundColor White
    Write-Host "  -List                      List compositions" -ForegroundColor White
}
