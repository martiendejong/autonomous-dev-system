$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json
$apiKey = $config.api_key
$workspaceId = "9012956001"
$docId = "8ckdjv1-1032"  # Already created knowledge base

$headers = @{
    Authorization = $apiKey
    'Content-Type' = 'application/json'
}

Write-Host "=== Populating Brand2Boost Knowledge Base ===" -ForegroundColor Cyan
Write-Host "Doc ID: $docId" -ForegroundColor Yellow
Write-Host ""

# Page 1: Dashboard Setup Guide
Write-Host "[1/4] Adding Dashboard Setup overview..." -ForegroundColor Cyan
$url = "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$docId/pages"
$content = @"
# ClickUp Dashboard Setup Guide

## Overview
Complete step-by-step guide for setting up a comprehensive team dashboard in ClickUp for the Brand2Boost workspace.

## Dashboard Components
- 12 Widgets (Blocked Items, Review Queue, Sprint Velocity, Team Workload, Epic Progress, etc.)
- 2 Automated Slack Alerts
- 4 Custom Fields (RICE Score, Blocked Reason, Review SLA, PR Link)

## Key Features
1. **Urgent Attention Row** - Blocked tasks and review queue with SLA tracking
2. **Team Progress** - Workload distribution and epic completion status
3. **Active Sprint** - Full Kanban board view
4. **Metrics & Analytics** - Task distribution, cycle time, velocity trends

## Setup Time
Approximately 30-45 minutes for complete dashboard configuration

## Full Documentation
See complete guide at: `C:\scripts\_machine\clickup-dashboard-setup.md`

Configuration JSON available at: `C:\scripts\_machine\clickup-dashboard-config.json`

## Next Steps
1. Open ClickUp → Dashboards
2. Create new dashboard: "Team Dashboard - Sprint [Current Week]"
3. Add widgets following the configuration guide
4. Configure Slack integration for automated alerts
5. Set up custom fields for RICE scoring and SLA tracking
"@

$bodyObj = @{
    name = "Dashboard Setup Guide"
    content = $content
}
$body = $bodyObj | ConvertTo-Json -Depth 10

try {
    $page = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
    Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Page 2: Development Workflow
Write-Host "[2/4] Adding Development Workflow..." -ForegroundColor Cyan
$content = @"
# Development Workflow Guide

## Overview
Comprehensive guide for managing development workflow across client-manager and hazina repositories.

## Dual-Mode Workflow

### Feature Development Mode
Use when implementing NEW features or planned work:
- Allocate dedicated worktree in `C:\Projects\worker-agents\agent-XXX\`
- Work in isolated environment
- Create PR when complete
- Release worktree after PR creation

### Active Debugging Mode
Use when fixing bugs or debugging:
- Work directly in base repo (`C:\Projects\<repo>\`)
- Stay on user's current branch
- NO worktree allocation needed
- Fast turnaround for fixes

## Zero Tolerance Rules
1. NEVER edit code in base repos during feature development
2. ALWAYS use worktrees for new feature work
3. Base repos MUST stay on `develop` branch after PR
4. ONE task in progress at a time

## Full Documentation
See complete workflow guide at: `C:\scripts\GENERAL_DUAL_MODE_WORKFLOW.md`

## Quick Commands
- Check worktree status: `worktree-status.ps1`
- Allocate worktree: `worktree-allocate.ps1 -Repo client-manager -Branch feature/xyz`
- Release worktree: `worktree-release-all.ps1`
"@

$bodyObj = @{
    name = "Development Workflow"
    content = $content
}
$body = $bodyObj | ConvertTo-Json -Depth 10

try {
    $page = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
    Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Page 3: Worktree Protocol
Write-Host "[3/4] Adding Worktree Protocol..." -ForegroundColor Cyan
$content = @"
# Worktree Management Protocol

## Overview
Git worktree-based development system for parallel agent execution with conflict detection.

## Atomic Allocation Protocol
1. Read `worktrees.pool.md`
2. Find FREE seat
3. Mark seat BUSY
4. Create worktree: `git worktree add`
5. Log activity in `worktrees.activity.md`

## Release Protocol
1. Commit all changes
2. Push to remote
3. Create PR
4. Mark seat FREE in pool
5. Update last activity timestamp

## Worktree Seats
- 12 agent seats (agent-001 through agent-012)
- States: FREE, BUSY, STALE, BROKEN
- Location: `C:\Projects\worker-agents\agent-XXX\`

## Multi-Agent Conflict Detection
MANDATORY check before allocation:
- Read pool to verify no other agent is working on same branch
- Auto-provision new seat if all are BUSY

## Full Documentation
See complete protocol at: `C:\scripts\GENERAL_WORKTREE_PROTOCOL.md`

Pool status: `C:\scripts\_machine\worktrees.pool.md`
"@

$bodyObj = @{
    name = "Worktree Protocol"
    content = $content
}
$body = $bodyObj | ConvertTo-Json -Depth 10

try {
    $page = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
    Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Page 4: Quick Reference
Write-Host "[4/4] Adding Quick Reference..." -ForegroundColor Cyan
$content = @"
# Quick Reference

## Essential Tools

### ClickUp Management
- List tasks: `clickup-sync.ps1 -Action list`
- Update task: `clickup-sync.ps1 -Action update -TaskId XXX -Status busy`
- Add comment: `clickup-sync.ps1 -Action comment -TaskId XXX -Comment "PR created"`

### Worktree Operations
- Check status: `worktree-status.ps1`
- Allocate: `worktree-allocate.ps1 -Repo client-manager -Branch feature/xyz`
- Release: `worktree-release-all.ps1`

### Project Status
- Repository dashboard: `repo-dashboard.sh`
- System health: `system-health.ps1`
- Bootstrap snapshot: `bootstrap-snapshot.ps1`

## Repository Structure
- **client-manager**: `C:\Projects\client-manager` (Frontend + API)
- **hazina**: `C:\Projects\hazina` (Framework)
- **Worker agents**: `C:\Projects\worker-agents\agent-XXX\`
- **Scripts**: `C:\scripts`
- **Machine state**: `C:\scripts\_machine`

## ClickUp Workspace
- **Workspace**: gigshub (9012956001)
- **List**: Brand Designer (901214097647)
- **Statuses**: todo, busy, review, blocked, done

## Project Details
- **Type**: SaaS promotion and brand development platform
- **Tech Stack**: ASP.NET Core, React/TypeScript, SQLite
- **Admin**: wreckingball / Th1s1sSp4rt4!

## Documentation Location
All documentation files are in `C:\scripts\` directory
"@

$bodyObj = @{
    name = "Quick Reference"
    content = $content
}
$body = $bodyObj | ConvertTo-Json -Depth 10

try {
    $page = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
    Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

Write-Host "=== KNOWLEDGE BASE COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "Knowledge Base Doc ID: $docId" -ForegroundColor Cyan
Write-Host "Location: ClickUp → gigshub workspace → Docs" -ForegroundColor Cyan
Write-Host ""
Write-Host "Pages added:" -ForegroundColor Yellow
Write-Host "  1. Dashboard Setup Guide" -ForegroundColor White
Write-Host "  2. Development Workflow" -ForegroundColor White
Write-Host "  3. Worktree Protocol" -ForegroundColor White
Write-Host "  4. Quick Reference" -ForegroundColor White
Write-Host ""
Write-Host "NEXT STEP: Convert to Wiki in ClickUp for better navigation" -ForegroundColor Yellow
