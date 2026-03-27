# Real-Time Code Smell Detector - File watcher for live analysis
# Wave 2 Tool #10 (Ratio: 6.7)

param(
    [Parameter(Mandatory=$false)]
    [string]$Path = ".",

    [Parameter(Mandatory=$false)]
    [string]$FilePattern = "*.cs",

    [Parameter(Mandatory=$false)]
    [int]$MaxLines = 300,

    [Parameter(Mandatory=$false)]
    [int]$MaxComplexity = 10
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Starting real-time code smell detector..." -ForegroundColor Cyan
Write-Host "  Path: $Path" -ForegroundColor Gray
Write-Host "  Pattern: $FilePattern" -ForegroundColor Gray
Write-Host "  Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $Path
$watcher.Filter = $FilePattern
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

function Analyze-File {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) { return }

    $content = Get-Content $FilePath -ErrorAction SilentlyContinue
    if (-not $content) { return }

    $smells = @()

    # Check file length
    if ($content.Count -gt $MaxLines) {
        $smells += "LONG_FILE: $($content.Count) lines (max $MaxLines)"
    }

    # Check for long methods
    $methodPattern = 'public|private|protected'
    $inMethod = $false
    $methodLines = 0
    $methodName = ""

    foreach ($line in $content) {
        if ($line -match "$methodPattern\s+\w+\s+(\w+)\s*\(") {
            if ($inMethod -and $methodLines -gt 50) {
                $smells += "LONG_METHOD: $methodName ($methodLines lines)"
            }
            $inMethod = $true
            $methodName = $Matches[1]
            $methodLines = 0
        }

        if ($inMethod) {
            $methodLines++
        }

        if ($line -match '^\s*\}' -and $inMethod) {
            $inMethod = $false
        }
    }

    # Check complexity (simple heuristic)
    $complexity = ($content | Select-String -Pattern '\b(if|for|while|switch|catch)\b').Count
    if ($complexity -gt $MaxComplexity) {
        $smells += "HIGH_COMPLEXITY: $complexity control structures"
    }

    # Check for magic numbers
    $magicNumbers = $content | Select-String -Pattern '\b\d{3,}\b' -AllMatches
    if ($magicNumbers.Matches.Count -gt 5) {
        $smells += "MAGIC_NUMBERS: $($magicNumbers.Matches.Count) numeric literals"
    }

    # Output
    if ($smells.Count -gt 0) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $FilePath" -ForegroundColor Yellow
        $smells | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor Red
        }
    }
}

# Event handler
$onChange = Register-ObjectEvent -InputObject $watcher -EventName Changed -Action {
    $path = $Event.SourceEventArgs.FullPath
    Start-Sleep -Milliseconds 100  # Debounce
    Analyze-File -FilePath $path
}

try {
    Write-Host "Watching for changes..." -ForegroundColor Green
    while ($true) {
        Start-Sleep -Seconds 1
    }
} finally {
    Unregister-Event -SourceIdentifier $onChange.Name
    $watcher.Dispose()
}
