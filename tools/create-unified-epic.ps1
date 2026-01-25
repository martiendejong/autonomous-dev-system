<#


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Creates the Unified Content System epic in ClickUp.

.DESCRIPTION
    One-time script to create the EPIC task and phase subtasks
    for the Unified Content System implementation.

.EXAMPLE
    .\create-unified-epic.ps1
#>

$ApiKey = 'pk_74525428_TXT8V1QUA13N7SCRM0UUM6WNQO2I2NML'
$ListId = '901214097647'
$Headers = @{ Authorization = $ApiKey; 'Content-Type' = 'application/json' }

# Create Epic task
$EpicBody = @{
    name = 'EPIC: Unified Content System'
    description = @"
Implement a unified component system that:
- Combines analysis-fields with custom user data
- Supports AI-generated, user-uploaded, and extracted content
- Displays components in chat, sidebar, and fullscreen modes
- Includes action components (file upload, OAuth, confirmation)

See: unified-content-integration-plan.md

Phases:
1. Merge PR #149 (allitemslist) first
2. Extend type system
3. Action components framework
4. Unified configuration
5. Chat integration
6. Restaurant menu integration
"@
    status = 'todo'
    priority = 2
} | ConvertTo-Json -Compress

try {
    $Epic = Invoke-RestMethod -Uri "https://api.clickup.com/api/v2/list/$ListId/task" -Method Post -Headers $Headers -Body $EpicBody
    Write-Host "Created Epic: $($Epic.id) - $($Epic.name)"

    # Create subtasks
    $Subtasks = @(
        @{
            name = "Phase 0: Review and Merge PR #149 (allitemslist)"
            description = "PREREQUISITE: Must complete before unified system work begins.`n`nSubtasks:`n- Code review`n- Test with feature flag`n- Deploy to staging`n- Enable for beta users`n- Full rollout"
            status = "busy"
            priority = 2
        },
        @{
            name = "Phase 1: Extend Type System for Unified Components"
            description = "Add unified component fields to ActivityItem types.`n`nSubtasks:`n- Add 'extracted' source type`n- Add displayConfig to ActivityItemBase`n- Add generationConfig to ActivityItemBase`n- Add menu-item type`n- Unit tests"
            status = "todo"
            priority = 3
        },
        @{
            name = "Phase 2: Action Components Framework"
            description = "Create framework for action components (file upload, OAuth, etc).`n`nSubtasks:`n- Create ActionComponentRegistry`n- Implement FileUploadAction`n- Implement OAuthConnectAction`n- Implement ConfirmationAction`n- Extend PopupDetailModal`n- Unit tests"
            status = "todo"
            priority = 3
        },
        @{
            name = "Phase 3: Unified Configuration System"
            description = "Create unified-components.config.json and config loader.`n`nSubtasks:`n- Design schema`n- Create componentConfigService`n- Integrate with ActivityItem rendering`n- Migration from analysis-fields.config.json`n- Unit tests"
            status = "todo"
            priority = 3
        },
        @{
            name = "Phase 4: Chat Component Integration"
            description = "Enable components to render in chat.`n`nSubtasks:`n- Create ChatItemRenderer`n- Implement content cards (TextCard, ImageCard, etc)`n- Implement action cards`n- Agent integration for inserting components`n- Unit tests"
            status = "todo"
            priority = 3
        },
        @{
            name = "Phase 5: Restaurant Menu Unified Integration"
            description = "Integrate restaurant menu with unified system.`n`nSubtasks:`n- Register menu-item in unified config`n- Create MenuItemCard for chat`n- Create SidebarMenuItem`n- Create MenuItemEditor fullscreen`n- Integration with MenuItemService`n- Unit tests"
            status = "todo"
            priority = 3
        }
    )

    foreach ($task in $Subtasks) {
        $body = $task | ConvertTo-Json -Compress
        $created = Invoke-RestMethod -Uri "https://api.clickup.com/api/v2/list/$ListId/task" -Method Post -Headers $Headers -Body $body
        Write-Host "Created: $($created.id) - $($created.name)"
    }

    Write-Host "`nAll tasks created successfully!"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}
