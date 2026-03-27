<#


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    ClickUp Knowledge Base Creator

.DESCRIPTION
    Creates a knowledge base doc in ClickUp and uploads documentation pages.

.EXAMPLE
    .\clickup-kb.ps1

.NOTES
    Uses ClickUp API v3 for Docs endpoints
#>

# Load config
$configPath = "C:\scripts\_machine\clickup-config.json"
if (-not (Test-Path $configPath)) {
    Write-Error "Config not found: $configPath"
    exit 1
}
$config = Get-Content $configPath | ConvertFrom-Json
$apiKey = $config.api_key
$workspaceId = "9012956001"  # gigshub workspace

$headers = @{
    Authorization = $apiKey
    "Content-Type" = "application/json"
}

Write-Host "=== Creating Knowledge Base in ClickUp ===" -ForegroundColor Cyan
Write-Host "Workspace: gigshub ($workspaceId)" -ForegroundColor Yellow
Write-Host ""

# Step 1: Create main Knowledge Base doc
Write-Host "[1/4] Creating Knowledge Base doc..." -ForegroundColor Cyan
$url = "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs"
$body = @{
    name = "Brand2Boost Knowledge Base"
} | ConvertTo-Json

try {
    $kbDoc = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
    $kbDocId = $kbDoc.id
    Write-Host "✓ Knowledge Base created!" -ForegroundColor Green
    Write-Host "  Doc ID: $kbDocId" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host "✗ Error creating knowledge base doc:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    if ($_.ErrorDetails) { Write-Host $_.ErrorDetails.Message }
    exit 1
}

# Step 2: Add Dashboard Setup Guide
Write-Host "[2/4] Adding Dashboard Setup Guide..." -ForegroundColor Cyan
$dashboardPath = "C:\scripts\_machine\clickup-dashboard-setup.md"
if (Test-Path $dashboardPath) {
    $content = Get-Content $dashboardPath -Raw
    $url = "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$kbDocId/pages"
    $body = @{
        name = "ClickUp Dashboard Setup Guide"
        content = $content
    } | ConvertTo-Json

    try {
        $page = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
        Write-Host "✓ Dashboard guide added (Page ID: $($page.id))" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ Error adding dashboard guide: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ Dashboard setup file not found, skipping" -ForegroundColor Yellow
}
Write-Host ""

# Step 3: Add Development Workflow
Write-Host "[3/4] Adding Development Workflow..." -ForegroundColor Cyan
$workflowPath = "C:\scripts\GENERAL_DUAL_MODE_WORKFLOW.md"
if (Test-Path $workflowPath) {
    $content = Get-Content $workflowPath -Raw
    $url = "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$kbDocId/pages"
    $body = @{
        name = "Development Workflow Guide"
        content = $content
    } | ConvertTo-Json

    try {
        $page = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
        Write-Host "✓ Workflow guide added (Page ID: $($page.id))" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ Error adding workflow guide: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ Workflow file not found, skipping" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Add Worktree Protocol
Write-Host "[4/4] Adding Worktree Protocol..." -ForegroundColor Cyan
$worktreePath = "C:\scripts\GENERAL_WORKTREE_PROTOCOL.md"
if (Test-Path $worktreePath) {
    $content = Get-Content $worktreePath -Raw
    $url = "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$kbDocId/pages"
    $body = @{
        name = "Worktree Management Protocol"
        content = $content
    } | ConvertTo-Json

    try {
        $page = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
        Write-Host "✓ Worktree protocol added (Page ID: $($page.id))" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ Error adding worktree protocol: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ Worktree protocol file not found, skipping" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "=== Knowledge Base Upload Complete ===" -ForegroundColor Green
Write-Host "Doc ID: $kbDocId" -ForegroundColor Cyan
Write-Host "View in ClickUp workspace: gigshub" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: Open ClickUp and convert this doc to a Wiki for better organization" -ForegroundColor Yellow
