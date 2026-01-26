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
    $instruction += "Execute WebSearch queries for USER'S PERSONALIZED INTERESTS - CRITICAL: ONLY PAST 3 DAYS`n`n"
    $instruction += "REQUIRED TOPICS (include 'past 3 days' or 'last 72 hours' in ALL queries):`n"
    $instruction += "1. KENYA NEWS - Politics, economy, technology, business developments in Kenya`n"
    $instruction += "2. NETHERLANDS NEWS - Politics, economy, technology, business developments in Netherlands`n"
    $instruction += "3. NEW AI MODELS AND TOOLS - Latest releases, announcements, launches (GPT, Claude, Gemini, Llama, etc)`n"
    $instruction += "4. HOLOCHAIN HOT - Price, news, developments, partnerships (user is holding this cryptocurrency)`n"
    $instruction += "5. RELEVANT YOUTUBE VIDEOS - AI tutorials, Kenya tech, Netherlands tech, Holochain content`n`n"
    $instruction += "Populate the dashboard HTML at: $dashPath`n"
    $instruction += "Update knowledge base with significant developments`n"
    $instruction += "Open dashboard in browser automatically`n`n"
    $instruction += "REQUIREMENT: Only show developments from past 3 days.`n"
    $instruction += "This is personalized monitoring - execute autonomously."

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
