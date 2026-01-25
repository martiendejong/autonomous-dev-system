<#
.SYNOPSIS
    ClickHub Coding Agent - Continuous Operation

.DESCRIPTION
    Runs the ClickHub agent in continuous mode:
    - Execute cycle (via clickhub-single-cycle.ps1)
    - Sleep for specified duration
    - Repeat forever (until Ctrl+C or stop flag)

.PARAMETER SleepSeconds
    Duration to sleep between cycles (default: 600 = 10 minutes)

.PARAMETER MaxTasksPerCycle
    Maximum tasks to process per cycle (default: 5)

.PARAMETER DryRun
    Run in dry-run mode (no actual changes)

.EXAMPLE
    .\clickhub-continuous.ps1
    .\clickhub-continuous.ps1 -SleepSeconds 300 -MaxTasksPerCycle 3

.NOTES
    Create C:\scripts\_machine\clickhub-stop.flag to gracefully stop
#>

param(
    [int]$SleepSeconds = 600,
    [int]$MaxTasksPerCycle = 5,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Paths
$scriptRoot = Split-Path -Parent $PSCommandPath
$machinePath = "C:\scripts\_machine"
$stopFlag = "$machinePath\clickhub-stop.flag"
$activityLog = "$machinePath\clickhub-activity.log"

function Write-Log {
    param($Message)
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $logLine = "$timestamp | $Message"
    Add-Content -Path $activityLog -Value $logLine
    Write-Host "[$timestamp] $Message" -ForegroundColor Cyan
}

function Test-StopFlag {
    if (Test-Path $stopFlag) {
        Write-Log "STOP_FLAG | Detected stop flag, exiting gracefully..."
        Remove-Item $stopFlag -Force
        return $true
    }
    return $false
}

# Main Loop
Write-Log "CONTINUOUS_START | SleepSeconds=$SleepSeconds, MaxTasksPerCycle=$MaxTasksPerCycle"
Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ClickHub Coding Agent - CONTINUOUS MODE                 ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
Write-Host "Settings:" -ForegroundColor Yellow
Write-Host "  Sleep Duration: $SleepSeconds seconds" -ForegroundColor White
Write-Host "  Max Tasks/Cycle: $MaxTasksPerCycle" -ForegroundColor White
Write-Host "  Dry Run: $DryRun`n" -ForegroundColor White
Write-Host "Press Ctrl+C to stop, or create: $stopFlag`n" -ForegroundColor Gray

$cycleCount = 0

try {
    while ($true) {
        $cycleCount++

        # Check for stop flag
        if (Test-StopFlag) {
            break
        }

        Write-Host "`n════════════════════════════════════════════════════════════" -ForegroundColor Magenta
        Write-Host "  CYCLE #$cycleCount - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Magenta
        Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor Magenta

        # Execute single cycle
        $cycleParams = @{
            MaxTasks = $MaxTasksPerCycle
        }
        if ($DryRun) {
            $cycleParams.DryRun = $true
        }

        try {
            & "$scriptRoot\clickhub-single-cycle.ps1" @cycleParams
        } catch {
            Write-Log "CYCLE_ERROR | Cycle $cycleCount failed: $($_.Exception.Message)"
            Write-Host "Error in cycle, continuing..." -ForegroundColor Red
        }

        # Sleep
        Write-Host "`n────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "Sleeping for $SleepSeconds seconds..." -ForegroundColor DarkCyan
        Write-Host "Next cycle: $(Get-Date).AddSeconds($SleepSeconds) -Format 'HH:mm:ss')" -ForegroundColor DarkCyan
        Write-Host "────────────────────────────────────────────────────────────`n" -ForegroundColor DarkGray

        Start-Sleep -Seconds $SleepSeconds
    }

    Write-Log "CONTINUOUS_STOP | Stopped after $cycleCount cycles"

} catch {
    Write-Log "CONTINUOUS_ERROR | Fatal error: $($_.Exception.Message)"
    Write-Error $_
    exit 1
} finally {
    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║   ClickHub Coding Agent - STOPPED                         ║" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════════╝`n" -ForegroundColor Red
}
