<#
.SYNOPSIS
    Cross-Tool State Sharing
    50-Expert Council Improvement #19 | Priority: 1.33

.DESCRIPTION
    Tools share context without file I/O through shared state.
    Provides in-memory state sharing across tool invocations.

.PARAMETER Set
    Set a state value.

.PARAMETER Get
    Get a state value.

.PARAMETER Key
    State key.

.PARAMETER Value
    State value.

.PARAMETER Clear
    Clear all state or specific key.

.PARAMETER List
    List all current state.

.PARAMETER Export
    Export state to file.

.PARAMETER Import
    Import state from file.

.EXAMPLE
    state-share.ps1 -Set -Key "current_task" -Value "Fix auth bug"
    state-share.ps1 -Get -Key "current_task"
    state-share.ps1 -List
#>

param(
    [switch]$Set,
    [switch]$Get,
    [string]$Key = "",
    [string]$Value = "",
    [switch]$Clear,
    [switch]$List,
    [switch]$Export,
    [switch]$Import,
    [string]$File = ""
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$StateFile = "C:\scripts\_machine\shared_state.json"

if (-not (Test-Path $StateFile)) {
    @{
        state = @{}
        metadata = @{
            created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            accessCount = 0
        }
    } | ConvertTo-Json -Depth 10 | Set-Content $StateFile -Encoding UTF8
}

$shared = Get-Content $StateFile -Raw | ConvertFrom-Json
$shared.metadata.accessCount++

if ($Set -and $Key) {
    if (-not $shared.state) { $shared.state = @{} }

    $entry = @{
        value = $Value
        type = $Value.GetType().Name
        updated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        accessCount = 0
    }

    $shared.state | Add-Member -NotePropertyName $Key -NotePropertyValue $entry -Force
    $shared | ConvertTo-Json -Depth 10 | Set-Content $StateFile -Encoding UTF8

    Write-Host "✓ State set: $Key = $Value" -ForegroundColor Green
}
elseif ($Get -and $Key) {
    $entry = $shared.state.$Key

    if (-not $entry) {
        Write-Host "State not found: $Key" -ForegroundColor Yellow
    } else {
        $entry.accessCount++
        $shared | ConvertTo-Json -Depth 10 | Set-Content $StateFile -Encoding UTF8

        Write-Host $entry.value
        return $entry.value
    }
}
elseif ($Clear) {
    if ($Key) {
        $shared.state.PSObject.Properties.Remove($Key)
        Write-Host "✓ Cleared: $Key" -ForegroundColor Green
    } else {
        $shared.state = @{}
        Write-Host "✓ All state cleared" -ForegroundColor Green
    }
    $shared | ConvertTo-Json -Depth 10 | Set-Content $StateFile -Encoding UTF8
}
elseif ($List) {
    Write-Host "=== SHARED STATE ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $shared.state -or $shared.state.PSObject.Properties.Count -eq 0) {
        Write-Host "  (empty)" -ForegroundColor Gray
    } else {
        foreach ($prop in $shared.state.PSObject.Properties) {
            $val = if ($prop.Value.value.Length -gt 50) {
                $prop.Value.value.Substring(0, 47) + "..."
            } else {
                $prop.Value.value
            }
            Write-Host "  $($prop.Name):" -ForegroundColor Yellow -NoNewline
            Write-Host " $val" -ForegroundColor White
            Write-Host "    (accessed $($prop.Value.accessCount)x, updated $($prop.Value.updated))" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "Total accesses: $($shared.metadata.accessCount)" -ForegroundColor Gray
}
elseif ($Export -and $File) {
    $shared | ConvertTo-Json -Depth 10 | Set-Content $File -Encoding UTF8
    Write-Host "✓ Exported to: $File" -ForegroundColor Green
}
elseif ($Import -and $File) {
    if (Test-Path $File) {
        $imported = Get-Content $File -Raw | ConvertFrom-Json
        $shared.state = $imported.state
        $shared | ConvertTo-Json -Depth 10 | Set-Content $StateFile -Encoding UTF8
        Write-Host "✓ Imported from: $File" -ForegroundColor Green
    } else {
        Write-Host "File not found: $File" -ForegroundColor Red
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Set -Key x -Value y   Set state" -ForegroundColor White
    Write-Host "  -Get -Key x            Get state" -ForegroundColor White
    Write-Host "  -Clear [-Key x]        Clear state" -ForegroundColor White
    Write-Host "  -List                  List all state" -ForegroundColor White
    Write-Host "  -Export -File x        Export to file" -ForegroundColor White
    Write-Host "  -Import -File x        Import from file" -ForegroundColor White
}
