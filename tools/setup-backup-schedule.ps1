#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets up Windows Task Scheduler to run nightly backups of brand2boost data
.DESCRIPTION
    Creates a scheduled task that runs backup-brand2boost.ps1 every night at 3:00 AM
.EXAMPLE
    .\setup-backup-schedule.ps1
    .\setup-backup-schedule.ps1 -Time "02:00"
    .\setup-backup-schedule.ps1 -Uninstall
#>

param(
    [string]$Time = "03:00",  # Default 3:00 AM
    [switch]$Uninstall
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ErrorActionPreference = "Stop"

$taskName = "Brand2Boost Nightly Backup"
$taskDescription = "Nightly backup of brand2boost data folder with 5-day retention"
$scriptPath = Join-Path $PSScriptRoot "backup-brand2boost.ps1"

# Verify script exists
if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: Backup script not found at: $scriptPath" -ForegroundColor Red
    exit 1
}

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

if ($Uninstall) {
    Write-Host "Uninstalling scheduled task: $taskName" -ForegroundColor Yellow
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Host "✓ Scheduled task removed successfully" -ForegroundColor Green
    } catch {
        if ($_.Exception.Message -like "*No MSFT_ScheduledTask objects found*") {
            Write-Host "Task not found (already removed)" -ForegroundColor Gray
        } else {
            Write-Host "ERROR: Failed to remove task: $_" -ForegroundColor Red
            exit 1
        }
    }
    exit 0
}

Write-Host "=== SETTING UP NIGHTLY BACKUP SCHEDULE ===" -ForegroundColor Cyan
Write-Host "Task Name: $taskName"
Write-Host "Schedule: Daily at $Time"
Write-Host "Script: $scriptPath"
Write-Host ""

# Remove existing task if it exists
try {
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "Removing existing task..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
} catch {
    # Task doesn't exist, continue
}

# Create the action (run PowerShell script)
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$scriptPath`""

# Create the trigger (daily at specified time)
$trigger = New-ScheduledTaskTrigger -Daily -At $Time

# Create settings
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

# Create principal (run as SYSTEM with highest privileges)
$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Register the task
try {
    Register-ScheduledTask `
        -TaskName $taskName `
        -Description $taskDescription `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Force | Out-Null

    Write-Host "✓ Scheduled task created successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "CONFIGURATION:" -ForegroundColor Cyan
    Write-Host "  - Runs: Daily at $Time"
    Write-Host "  - Source: C:\stores\brand2boost"
    Write-Host "  - Backup Location: C:\backups\brand2boost"
    Write-Host "  - Retention: Last 5 backups (rotating)"
    Write-Host "  - Log File: C:\backups\brand2boost\backup.log"
    Write-Host "  - Excludes: .git, bin, obj, logs, model-usage-stats, .hazina"
    Write-Host ""
    Write-Host "MANUAL TESTING:" -ForegroundColor Cyan
    Write-Host "  Test backup:        .\backup-brand2boost.ps1"
    Write-Host "  Test dry run:       .\backup-brand2boost.ps1 -DryRun"
    Write-Host "  Run scheduled task: Start-ScheduledTask -TaskName '$taskName'"
    Write-Host "  Uninstall task:     .\setup-backup-schedule.ps1 -Uninstall"
    Write-Host ""
    Write-Host "VERIFY TASK:" -ForegroundColor Cyan
    Write-Host "  Get-ScheduledTask -TaskName '$taskName' | Get-ScheduledTaskInfo"
    Write-Host ""

    # Test run to verify it works
    Write-Host "Would you like to run a test backup now? (Y/N): " -NoNewline -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host ""
        Write-Host "Running test backup..." -ForegroundColor Cyan
        & $scriptPath
    }

} catch {
    Write-Host "ERROR: Failed to create scheduled task: $_" -ForegroundColor Red
    exit 1
}
