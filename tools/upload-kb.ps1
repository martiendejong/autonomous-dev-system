# Load ClickUp config

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json
$apiKey = $config.api_key
$workspaceId = "9012956001"

$headers = @{
    Authorization = $apiKey
    'Content-Type' = 'application/json'
}

Write-Host "=== Creating Brand2Boost Knowledge Base in ClickUp ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create main Knowledge Base doc
Write-Host "[1/4] Creating Knowledge Base doc..." -ForegroundColor Cyan
$url = "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs"
$bodyObj = @{ name = "Brand2Boost Knowledge Base" }
$body = $bodyObj | ConvertTo-Json

try {
    $kbDoc = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
    $kbDocId = $kbDoc.id
    Write-Host "SUCCESS! Knowledge Base created: $kbDocId" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Upload Dashboard Setup Guide
Write-Host "[2/4] Uploading Dashboard Setup Guide..." -ForegroundColor Cyan
$dashboardPath = "C:\scripts\_machine\clickup-dashboard-setup.md"
if (Test-Path $dashboardPath) {
    $content = Get-Content $dashboardPath -Raw
    $url = "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$kbDocId/pages"
    $bodyObj = @{
        name = "ClickUp Dashboard Setup Guide"
        content = $content
    }
    $body = $bodyObj | ConvertTo-Json

    try {
        $page = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
        Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
    }
    catch {
        Write-Host "WARNING: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "SKIP: File not found" -ForegroundColor Yellow
}
Write-Host ""

# Step 3: Upload Development Workflow
Write-Host "[3/4] Uploading Development Workflow..." -ForegroundColor Cyan
$workflowPath = "C:\scripts\GENERAL_DUAL_MODE_WORKFLOW.md"
if (Test-Path $workflowPath) {
    $content = Get-Content $workflowPath -Raw
    $url = "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$kbDocId/pages"
    $bodyObj = @{
        name = "Development Workflow Guide"
        content = $content
    }
    $body = $bodyObj | ConvertTo-Json

    try {
        $page = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
        Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
    }
    catch {
        Write-Host "WARNING: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "SKIP: File not found" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Upload Worktree Protocol
Write-Host "[4/4] Uploading Worktree Protocol..." -ForegroundColor Cyan
$worktreePath = "C:\scripts\GENERAL_WORKTREE_PROTOCOL.md"
if (Test-Path $worktreePath) {
    $content = Get-Content $worktreePath -Raw
    $url = "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$kbDocId/pages"
    $bodyObj = @{
        name = "Worktree Management Protocol"
        content = $content
    }
    $body = $bodyObj | ConvertTo-Json

    try {
        $page = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
        Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
    }
    catch {
        Write-Host "WARNING: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "SKIP: File not found" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "=== COMPLETE ===" -ForegroundColor Green
Write-Host "Knowledge Base Doc ID: $kbDocId" -ForegroundColor Cyan
Write-Host "View in ClickUp workspace: gigshub (9012956001)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: Open ClickUp and convert to Wiki for better navigation" -ForegroundColor Yellow
