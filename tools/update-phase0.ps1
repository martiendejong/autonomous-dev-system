<#


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Updates Phase 0 task in ClickUp with new strategy.

.DESCRIPTION
    One-time script to update the Phase 0 task with the
    allitemslist integration branch strategy.

.EXAMPLE
    .\update-phase0.ps1
#>

$ApiKey = 'pk_74525428_TXT8V1QUA13N7SCRM0UUM6WNQO2I2NML'
$TaskId = '869bt43qt'
$Headers = @{ Authorization = $ApiKey; 'Content-Type' = 'application/json' }

# Update task name and description
$UpdateBody = @{
    name = "Phase 0: Use allitemslist as Integration Branch"
    description = @"
UPDATED STRATEGY: All unified content work merges INTO allitemslist branch.

Branch: allitemslist (PR #149)
Target: All subsequent phases merge here, NOT to develop

Workflow:
1. feature/unified-types -> PR to allitemslist
2. feature/action-components -> PR to allitemslist
3. feature/unified-config -> PR to allitemslist
4. feature/chat-components -> PR to allitemslist
5. feature/unified-menu -> PR to allitemslist
6. FINAL: allitemslist -> develop (comprehensive PR)

Subtasks:
- [ ] Keep allitemslist rebased on develop
- [ ] Set up CI for allitemslist branch
- [ ] Create feature flag for unified UI
"@
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "https://api.clickup.com/api/v2/task/$TaskId" -Method Put -Headers $Headers -Body $UpdateBody | Out-Null
    Write-Host "Updated Phase 0 task to reflect integration branch strategy"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}
