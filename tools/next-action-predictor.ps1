# Next Action Predictor - Predict what user will do next based on patterns
# Wave 2 Tool #9 (Ratio: 6.0)

param(
    [Parameter(Mandatory=$false)]
    [int]$TopN = 5
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$HistoryPath = (Get-PSReadlineOption).HistorySavePath

if (-not (Test-Path $HistoryPath)) {
    Write-Host "No history available" -ForegroundColor Yellow
    exit 0
}

# Read recent history
$history = Get-Content $HistoryPath -Tail 100 -Encoding UTF8

# Find common patterns
$patterns = @{}

for ($i = 0; $i -lt ($history.Count - 1); $i++) {
    $current = $history[$i]
    $next = $history[$i + 1]

    # Extract command (first word)
    if ($current -match '^(\S+)') {
        $currentCmd = $Matches[1]

        if ($next -match '^(\S+)') {
            $nextCmd = $Matches[1]

            $pattern = "$currentCmd -> $nextCmd"

            if (-not $patterns.ContainsKey($pattern)) {
                $patterns[$pattern] = 0
            }
            $patterns[$pattern]++
        }
    }
}

# Get last command
$lastCmd = if ($history[-1] -match '^(\S+)') { $Matches[1] } else { "" }

Write-Host ""
Write-Host "NEXT ACTION PREDICTIONS" -ForegroundColor Cyan
Write-Host "Based on: $lastCmd" -ForegroundColor Gray
Write-Host ""

# Find patterns starting with last command
$predictions = $patterns.GetEnumerator() |
    Where-Object { $_.Key -like "$lastCmd -> *" } |
    Sort-Object Value -Descending |
    Select-Object -First $TopN

if ($predictions) {
    Write-Host "Likely next commands:" -ForegroundColor Yellow
    $predictions | ForEach-Object {
        $nextCmd = $_.Key -replace '.* -> ', ''
        $confidence = [Math]::Round(($_.Value / ($patterns.Values | Measure-Object -Sum).Sum) * 100, 1)
        Write-Host "  $nextCmd ($confidence% confidence)" -ForegroundColor Green
    }
} else {
    Write-Host "No predictions available (not enough history)" -ForegroundColor Yellow
}

Write-Host ""
