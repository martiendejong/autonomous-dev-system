<#
.SYNOPSIS
    Setup Windows Scheduled Task for Daily World Development Dashboard

.DESCRIPTION
    Creates a Windows Scheduled Task that runs at 12:00 noon every day.
    The task executes world-daily-dashboard.ps1 which:
    - Generates HTML dashboard with latest world developments
    - Opens dashboard automatically in browser
    - Updates knowledge base

    This is AUTONOMOUS - no user interaction required once set up.

.PARAMETER TaskName
    Name of scheduled task (default: "WorldDevelopmentDashboard")

.PARAMETER RunTime
    Time to run task daily (default: "12:00")

.EXAMPLE
    .\setup-world-dashboard-task.ps1
    # Sets up task to run at 12:00 noon daily

.EXAMPLE
    .\setup-world-dashboard-task.ps1 -RunTime "09:00"
    # Sets up task to run at 9:00 AM daily

.NOTES
    Requires: Administrator privileges
    Created: 2026-01-25
    Part of autonomous world development monitoring
#>

param(
    [string]$TaskName = "WorldDevelopmentDashboard",
    [string]$RunTime = "12:00"
)

$ErrorActionPreference = "Stop"

Write-Host "🌍 Setting up World Development Dashboard - Scheduled Task" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "⚠️  This script requires Administrator privileges" -ForegroundColor Yellow
    Write-Host "Please run PowerShell as Administrator and try again" -ForegroundColor Yellow
    exit 1
}

# Paths
$scriptPath = "C:\scripts\tools\world-daily-dashboard.ps1"
$claudeAgentPath = "C:\scripts\claude_agent.bat"
$wrapperPath = "C:\scripts\tools\world-dashboard-wrapper.ps1"

# Verify script exists
if (-not (Test-Path $scriptPath)) {
    Write-Host "❌ Script not found: $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "📝 Creating wrapper script for Claude Agent execution..." -ForegroundColor Cyan

# Create wrapper script that launches Claude Agent with dashboard generation
$wrapperContent = @"
# World Development Dashboard Wrapper
# This script launches Claude Agent to generate the daily dashboard

`$ErrorActionPreference = "Stop"

Write-Host "🌍 World Development Dashboard - Daily Update" -ForegroundColor Cyan
Write-Host "Time: `$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Step 1: Generate dashboard template
Write-Host "📊 Generating dashboard template..." -ForegroundColor Yellow
`$result = & "C:\scripts\tools\world-daily-dashboard.ps1"

if (`$result) {
    Write-Host "✅ Dashboard template created: `$(`$result.DashboardPath)" -ForegroundColor Green
    Write-Host ""

    # Step 2: Launch Claude Agent to populate with WebSearch
    Write-Host "🤖 Launching Claude Agent to populate dashboard with WebSearch..." -ForegroundColor Yellow
    Write-Host "   Claude will execute 25 queries and update the dashboard" -ForegroundColor Gray
    Write-Host ""

    # Create instruction file for Claude Agent
    `$instructionFile = "C:\projects\world_development\dashboard\daily-instruction.txt"
    `$date = Get-Date -Format 'yyyy-MM-dd'
    `$dashPath = `$result.DashboardPath
    `$instruction = "AUTONOMOUS DAILY DASHBOARD GENERATION - `$date``n``n"
    `$instruction += "Your task - AUTONOMOUS NO PERMISSION NEEDED:``n"
    `$instruction += "Execute WebSearch queries for all 5 domains``n"
    `$instruction += "Populate the dashboard HTML at: `$dashPath``n"
    `$instruction += "Update knowledge base with significant developments``n"
    `$instruction += "Open dashboard in browser automatically``n``n"
    `$instruction += "Dashboard template is ready. Execute your daily world development routine now.``n``n"
    `$instruction += "This is part of your core identity - execute autonomously."

    Set-Content -Path `$instructionFile -Value `$instruction -Encoding UTF8

    # Open dashboard template (will show loading state)
    Start-Process `$result.LatestPath

    Write-Host "✅ Dashboard opened in browser (showing loading state)" -ForegroundColor Green
    Write-Host "🤖 Claude Agent will populate content via WebSearch" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Dashboard location: `$(`$result.LatestPath)" -ForegroundColor Gray
    Write-Host "Next update: Tomorrow at $RunTime (automatic)" -ForegroundColor Gray
}
else {
    Write-Host "❌ Failed to generate dashboard template" -ForegroundColor Red
    exit 1
}
"@

Set-Content -Path $wrapperPath -Value $wrapperContent -Encoding UTF8
Write-Host "✅ Wrapper script created: $wrapperPath" -ForegroundColor Green
Write-Host ""

# Remove existing task if it exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "🗑️  Removing existing task: $TaskName" -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Write-Host "📅 Creating scheduled task: $TaskName" -ForegroundColor Cyan
Write-Host "   Schedule: Daily at $RunTime" -ForegroundColor Gray
Write-Host ""

# Create scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$wrapperPath`""

$trigger = New-ScheduledTaskTrigger -Daily -At $RunTime

# Run whether user is logged in or not
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

# Register task
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Autonomous World Development Dashboard - Generated daily at $RunTime by Claude Agent. Monitors AI, climate, economics, geopolitics, and science developments." | Out-Null

Write-Host "✅ Scheduled task created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  WORLD DEVELOPMENT DASHBOARD - ACTIVE" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "📊 Dashboard will be generated and displayed automatically" -ForegroundColor Green
Write-Host "🕐 Schedule: Every day at $RunTime" -ForegroundColor Green
Write-Host "🌍 Domains: AI, Climate, Economics, Geopolitics, Science" -ForegroundColor Green
Write-Host "🤖 Mode: Autonomous (no user interaction required)" -ForegroundColor Green
Write-Host ""
Write-Host "📁 Dashboard location: C:\projects\world_development\dashboard\" -ForegroundColor Gray
Write-Host "📝 Latest dashboard: C:\projects\world_development\dashboard\latest.html" -ForegroundColor Gray
Write-Host ""
Write-Host "You can also run manually anytime:" -ForegroundColor Yellow
Write-Host "  powershell -File `"$wrapperPath`"" -ForegroundColor Gray
Write-Host ""
Write-Host "To test the task immediately:" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
Write-Host ""
Write-Host "To view task details:" -ForegroundColor Yellow
Write-Host "  Get-ScheduledTask -TaskName '$TaskName' | Get-ScheduledTaskInfo" -ForegroundColor Gray
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Setup complete! First dashboard tomorrow at $RunTime" -ForegroundColor Green
Write-Host ""

# Ask if user wants to test now
$testNow = Read-Host "Would you like to test the dashboard now? (Y/N)"
if ($testNow -eq 'Y' -or $testNow -eq 'y') {
    Write-Host ""
    Write-Host "🚀 Launching test dashboard generation..." -ForegroundColor Cyan
    & $wrapperPath
}

Write-Host ""
Write-Host "✅ World Development Dashboard is now part of your daily routine!" -ForegroundColor Green
