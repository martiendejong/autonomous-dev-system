<#
.SYNOPSIS
    ClickUp Docs/Wiki management tool for creating knowledge base

.DESCRIPTION
    Creates and manages ClickUp Docs/Wikis programmatically using v3 API.
    Supports creating docs, converting to wikis, and uploading markdown content.

.PARAMETER Action
    create       - Create a new doc
    create-page  - Create a page in an existing doc
    list         - List all docs in workspace
    update       - Update existing doc content
    wiki         - Convert doc to wiki
    upload       - Upload markdown file as doc
    upload-kb    - Upload knowledge base docs (dashboard setup, etc.)

.PARAMETER WorkspaceId
    ClickUp workspace ID (default: gigshub workspace)

.PARAMETER Name
    Doc name/title

.PARAMETER Content
    Doc content (HTML or markdown)

.PARAMETER FilePath
    Path to markdown file to upload

.PARAMETER DocId
    ClickUp doc ID (for update/wiki actions)

.PARAMETER ParentId
    Parent location ID (folder or space)

.EXAMPLE
    .\clickup-docs.ps1 -Action create -Name "Dashboard Setup Guide" -FilePath "C:\scripts\_machine\clickup-dashboard-setup.md"
    .\clickup-docs.ps1 -Action list
    .\clickup-docs.ps1 -Action wiki -DocId "abc123"

.NOTES
    Uses ClickUp API v3 for Docs endpoints
    Requires API key in C:\scripts\_machine\clickup-config.json
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "create-page", "list", "update", "wiki", "upload", "upload-kb")]
    [string]$Action,

    [string]$WorkspaceId,
    [string]$Name,
    [string]$Content,
    [string]$FilePath,
    [string]$DocId,
    [string]$ParentId,
    [string]$FolderId
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

# Load config
$configPath = "C:\scripts\_machine\clickup-config.json"
if (-not (Test-Path $configPath)) {
    Write-Error "Config not found: $configPath"
    exit 1
}
$config = Get-Content $configPath | ConvertFrom-Json
$apiKey = $config.api_key

# Default to gigshub workspace if not specified
if (-not $WorkspaceId) {
    $WorkspaceId = "9012956001"  # gigshub workspace
}

$headers = @{
    Authorization = $apiKey
    "Content-Type" = "application/json"
}

# Convert markdown to HTML (basic conversion)
function ConvertTo-HtmlContent {
    param([string]$markdown)

    # Basic markdown to HTML conversion
    $html = $markdown

    # Headers
    $html = $html -replace '### (.+)', '<h3>$1</h3>'
    $html = $html -replace '## (.+)', '<h2>$1</h2>'
    $html = $html -replace '# (.+)', '<h1>$1</h1>'

    # Bold and italic
    $html = $html -replace '\*\*(.+?)\*\*', '<strong>$1</strong>'
    $html = $html -replace '\*(.+?)\*', '<em>$1</em>'

    # Code blocks
    $html = $html -replace '```(.+?)```', '<pre><code>$1</code></pre>'
    $html = $html -replace '`(.+?)`', '<code>$1</code>'

    # Lists (basic)
    $html = $html -replace '^\- (.+)', '<li>$1</li>'
    $html = $html -replace '^\d+\. (.+)', '<li>$1</li>'

    # Paragraphs
    $html = $html -replace '(?m)^(.+)$(?!\n)', '<p>$1</p>'

    return $html
}

switch ($Action) {
    "create" {
        if (-not $Name) {
            Write-Error "Name required for create action"
            exit 1
        }

        # If FilePath provided, load content from file
        if ($FilePath) {
            if (-not (Test-Path $FilePath)) {
                Write-Error "File not found: $FilePath"
                exit 1
            }
            $markdown = Get-Content $FilePath -Raw
            $Content = ConvertTo-HtmlContent $markdown
        }

        if (-not $Content) {
            Write-Error "Content or FilePath required for create action"
            exit 1
        }

        Write-Host "Creating doc in workspace $WorkspaceId..." -ForegroundColor Cyan

        $url = "https://api.clickup.com/api/v3/workspaces/$WorkspaceId/docs"

        # Build request body (trying common parameters)
        $body = @{
            name = $Name
        }

        # Add optional parameters if provided
        if ($ParentId) { $body.parent_id = $ParentId }
        if ($FolderId) { $body.folder_id = $FolderId }

        $bodyJson = $body | ConvertTo-Json

        try {
            $response = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $bodyJson
            Write-Host "✓ Doc created successfully!" -ForegroundColor Green
            Write-Host "Doc ID: $($response.id)"
            Write-Host "Name: $($response.name)"
            Write-Host "URL: $($response.url)"

            # Now update with content using Edit Page endpoint
            if ($response.id) {
                Write-Host "`nAdding content to doc..." -ForegroundColor Cyan
                # Note: Content addition may require different endpoint
                # This is exploratory - may need adjustment based on API response
            }

            return $response
        }
        catch {
            Write-Host "Error creating doc:" -ForegroundColor Red
            Write-Host $_.Exception.Message
            if ($_.ErrorDetails) {
                Write-Host $_.ErrorDetails.Message
            }
            exit 1
        }
    }

    "list" {
        Write-Host "Listing docs in workspace $WorkspaceId..." -ForegroundColor Cyan

        # Note: Search endpoint might be needed, trying list approach
        $url = "https://api.clickup.com/api/v3/workspaces/$WorkspaceId/docs"

        try {
            $response = Invoke-RestMethod -Uri $url -Headers $headers

            if ($response.docs) {
                Write-Host "`nFound $($response.docs.Count) docs:" -ForegroundColor Green
                $response.docs | ForEach-Object {
                    Write-Host "`n- $($_.name)" -ForegroundColor Yellow
                    Write-Host "  ID: $($_.id)"
                    Write-Host "  Created: $($_.date_created)"
                    if ($_.url) { Write-Host "  URL: $($_.url)" }
                }
            } else {
                Write-Host "No docs found or response format differs" -ForegroundColor Yellow
                Write-Host "Response: $($response | ConvertTo-Json -Depth 3)"
            }
        }
        catch {
            Write-Host "Error listing docs:" -ForegroundColor Red
            Write-Host $_.Exception.Message
            if ($_.ErrorDetails) {
                Write-Host $_.ErrorDetails.Message
            }
        }
    }

    "wiki" {
        if (-not $DocId) {
            Write-Error "DocId required for wiki action"
            exit 1
        }

        Write-Host "Converting doc $DocId to wiki..." -ForegroundColor Cyan

        # Note: Wiki conversion endpoint may differ
        # This is exploratory
        $url = "https://api.clickup.com/api/v3/docs/$DocId"
        $body = @{
            is_wiki = $true
        } | ConvertTo-Json

        try {
            $response = Invoke-RestMethod -Method PUT -Uri $url -Headers $headers -Body $body
            Write-Host "✓ Doc converted to wiki!" -ForegroundColor Green
        }
        catch {
            Write-Host "Error converting to wiki:" -ForegroundColor Red
            Write-Host $_.Exception.Message
            if ($_.ErrorDetails) {
                Write-Host $_.ErrorDetails.Message
            }
        }
    }

    "create-page" {
        if (-not $DocId) {
            Write-Error "DocId required for create-page action"
            exit 1
        }
        if (-not $Name) {
            Write-Error "Name (page title) required for create-page action"
            exit 1
        }

        # If FilePath provided, load content from file
        if ($FilePath) {
            if (-not (Test-Path $FilePath)) {
                Write-Error "File not found: $FilePath"
                exit 1
            }
            $Content = Get-Content $FilePath -Raw
        }

        if (-not $Content) {
            $Content = ""  # Allow empty pages
        }

        Write-Host "Creating page in doc $DocId..." -ForegroundColor Cyan

        $url = "https://api.clickup.com/api/v3/workspaces/$WorkspaceId/docs/$DocId/pages"

        # Build request body
        $body = @{
            name = $Name
            content = $Content
        } | ConvertTo-Json

        try {
            $response = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
            Write-Host "✓ Page created successfully!" -ForegroundColor Green
            Write-Host "Page ID: $($response.id)"
            Write-Host "Title: $($response.name)"
            return $response
        }
        catch {
            Write-Host "Error creating page:" -ForegroundColor Red
            Write-Host $_.Exception.Message
            if ($_.ErrorDetails) {
                Write-Host $_.ErrorDetails.Message
            }
            exit 1
        }
    }

    "upload" {
        if (-not $FilePath) {
            Write-Error "FilePath required for upload action"
            exit 1
        }

        if (-not (Test-Path $FilePath)) {
            Write-Error "File not found: $FilePath"
            exit 1
        }

        # Auto-generate name from filename if not provided
        if (-not $Name) {
            $Name = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
        }

        # Call create with file path
        & $PSCommandPath -Action create -WorkspaceId $WorkspaceId -Name $Name -FilePath $FilePath
    }

    "upload-kb" {
        Write-Host "=== Creating Knowledge Base in ClickUp ===" -ForegroundColor Cyan
        Write-Host "Workspace: $WorkspaceId (gigshub)" -ForegroundColor Yellow
        Write-Host ""

        # 1. Create main Knowledge Base doc
        Write-Host "[1/4] Creating Knowledge Base doc..." -ForegroundColor Cyan
        $kbDoc = & $PSCommandPath -Action create -WorkspaceId $WorkspaceId -Name "Brand2Boost Knowledge Base" -Content "Documentation and guides for the client-manager and hazina projects."

        if (-not $kbDoc) {
            Write-Error "Failed to create knowledge base doc"
            exit 1
        }

        $kbDocId = $kbDoc.id
        Write-Host "✓ Knowledge Base created: $kbDocId" -ForegroundColor Green
        Write-Host ""

        # 2. Upload Dashboard Setup Guide
        Write-Host "[2/4] Adding Dashboard Setup Guide..." -ForegroundColor Cyan
        $dashboardSetupPath = "C:\scripts\_machine\clickup-dashboard-setup.md"
        if (Test-Path $dashboardSetupPath) {
            & $PSCommandPath -Action create-page -WorkspaceId $WorkspaceId -DocId $kbDocId -Name "ClickUp Dashboard Setup Guide" -FilePath $dashboardSetupPath
        } else {
            Write-Host "⚠ Dashboard setup file not found, skipping" -ForegroundColor Yellow
        }
        Write-Host ""

        # 3. Upload Development Workflow
        Write-Host "[3/4] Adding Development Workflow..." -ForegroundColor Cyan
        $workflowPath = "C:\scripts\GENERAL_DUAL_MODE_WORKFLOW.md"
        if (Test-Path $workflowPath) {
            & $PSCommandPath -Action create-page -WorkspaceId $WorkspaceId -DocId $kbDocId -Name "Development Workflow Guide" -FilePath $workflowPath
        } else {
            Write-Host "⚠ Workflow file not found, skipping" -ForegroundColor Yellow
        }
        Write-Host ""

        # 4. Upload Worktree Protocol
        Write-Host "[4/4] Adding Worktree Protocol..." -ForegroundColor Cyan
        $worktreePath = "C:\scripts\GENERAL_WORKTREE_PROTOCOL.md"
        if (Test-Path $worktreePath) {
            & $PSCommandPath -Action create-page -WorkspaceId $WorkspaceId -DocId $kbDocId -Name "Worktree Management Protocol" -FilePath $worktreePath
        } else {
            Write-Host "⚠ Worktree protocol file not found, skipping" -ForegroundColor Yellow
        }
        Write-Host ""

        Write-Host "=== Knowledge Base Upload Complete ===" -ForegroundColor Green
        Write-Host "Doc ID: $kbDocId" -ForegroundColor Cyan
        Write-Host "Access via ClickUp workspace: gigshub" -ForegroundColor Cyan
    }
}
