# World Development Dashboard Wrapper
# This script launches Claude Agent to generate the daily dashboard

$ErrorActionPreference = "Stop"

Write-Host "World World Development Dashboard - Daily Update" -ForegroundColor Cyan
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Step 1: Generate dashboard template
Write-Host "[*] Generating dashboard template..." -ForegroundColor Yellow
$result = & "C:\scripts\tools\world-daily-dashboard.ps1"

if ($result) {
    Write-Host "[OK] Dashboard template created: $($result.DashboardPath)" -ForegroundColor Green
    Write-Host ""

    # Step 2: Launch Claude Agent to populate with WebSearch
    Write-Host "[AI] Launching Claude Agent to populate dashboard with WebSearch..." -ForegroundColor Yellow
    Write-Host "   Claude will execute 25 queries and update the dashboard" -ForegroundColor Gray
    Write-Host ""

    # Create instruction file for Claude Agent
    $instructionFile = "C:\projects\world_development\dashboard\daily-instruction.txt"
    $date = Get-Date -Format 'yyyy-MM-dd'
    $dashPath = $result.DashboardPath
    $instruction = "AUTONOMOUS DAILY DASHBOARD GENERATION - $date`n`n"
    $instruction += "Your task - AUTONOMOUS NO PERMISSION NEEDED:`n"
    $instruction += "Execute WebSearch queries for all 5 domains - CRITICAL: ONLY PAST 3 DAYS`n"
    $instruction += "Include 'past 3 days' or 'last 72 hours' in ALL search queries`n"
    $instruction += "Populate the dashboard HTML at: $dashPath`n"
    $instruction += "Update knowledge base with significant developments`n"
    $instruction += "Open dashboard in browser automatically`n`n"
    $instruction += "Dashboard template is ready. Execute your daily world development routine now.`n`n"
    $instruction += "REQUIREMENT: Only show developments from past 3 days.`n"
    $instruction += "This is part of your core identity - execute autonomously."

    Set-Content -Path $instructionFile -Value $instruction -Encoding UTF8

    # Open dashboard template (will show loading state)
    Start-Process $result.LatestPath

    Write-Host "[OK] Dashboard opened in browser (showing loading state)" -ForegroundColor Green
    Write-Host "[AI] Claude Agent will populate content via WebSearch" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Dashboard location: $($result.LatestPath)" -ForegroundColor Gray
    Write-Host "Next update: Tomorrow at 12:00 (automatic)" -ForegroundColor Gray
}
else {
    Write-Host "ERROR: Failed to generate dashboard template" -ForegroundColor Red
    exit 1
}
