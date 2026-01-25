# ClickUp Dashboard Builder
# Generates dashboard configuration for brand2boost workspace

param(
    [string]$Action = "generate",
    [string]$OutputPath = "C:\scripts\_machine\clickup-dashboard-config.json"
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$dashboardConfig = @{
    name = "Brand2Boost Team Dashboard"
    description = "Sprint health, blockers, and team capacity tracking"
    workspace_id = "REPLACE_WITH_YOUR_WORKSPACE_ID"
    list_id = "901214097647"  # Brand Designer list
    widgets = @(
        # Widget 1: Blocked Items
        @{
            id = 1
            name = "[BLOCKED] Needs Action"
            type = "task_list"
            size = "third"
            position = @{ row = 1; col = 1 }
            settings = @{
                filters = @{
                    status = @("blocked")
                }
                sort = @{
                    field = "date_updated"
                    direction = "asc"
                }
                fields = @("name", "assignee", "custom_field_blocked_reason", "date_updated")
                limit = 20
                color = "#ff4444"
            }
        }

        # Widget 2: Review Queue
        @{
            id = 2
            name = "[REVIEW] SLA Tracker"
            type = "task_list"
            size = "third"
            position = @{ row = 1; col = 2 }
            settings = @{
                filters = @{
                    status = @("review")
                }
                sort = @{
                    field = "date_updated"
                    direction = "asc"
                }
                fields = @("name", "assignee", "days_in_review")
                limit = 20
                color = "#ff9800"
            }
        }

        # Widget 3: Sprint Velocity
        @{
            id = 3
            name = "Sprint Velocity Trend"
            type = "line_chart"
            size = "third"
            position = @{ row = 1; col = 3 }
            settings = @{
                filters = @{
                    status = @("done")
                }
                time_range = "last_6_weeks"
                group_by = "date_closed"
                aggregation = "count"
                target_line = 40
            }
        }

        # Widget 4: Team Workload
        @{
            id = 4
            name = "[TEAM] Capacity & WIP"
            type = "workload"
            size = "half"
            position = @{ row = 2; col = 1 }
            settings = @{
                filters = @{
                    status = @("busy", "review")
                }
                group_by = "assignee"
                show_wip_limit = $true
                wip_limit = 3
            }
        }

        # Widget 5: Epic Progress
        @{
            id = 5
            name = "[EPIC] Completion Status"
            type = "progress_bars"
            size = "half"
            position = @{ row = 2; col = 2 }
            settings = @{
                group_by = "epic"
                show_percentage = $true
                show_task_count = $true
                sort = "percentage_desc"
            }
        }

        # Widget 6: Sprint Kanban
        @{
            id = 6
            name = "[SPRINT] Active Sprint - All Tasks"
            type = "board"
            size = "full"
            position = @{ row = 3; col = 1 }
            settings = @{
                filters = @{
                    status = @("todo", "busy", "review", "blocked")
                }
                group_by = "status"
                columns = @("todo", "busy", "review", "blocked")
                card_fields = @("assignee", "priority", "tags", "due_date")
            }
        }

        # Widget 7: Tasks by Status
        @{
            id = 7
            name = "[CHART] Task Distribution"
            type = "pie_chart"
            size = "third"
            position = @{ row = 4; col = 1 }
            settings = @{
                filters = @{
                    status_not = @("done")
                }
                group_by = "status"
                show_percentage = $true
            }
        }

        # Widget 8: High Priority TODO
        @{
            id = 8
            name = "[PRIORITY] Top Priorities - Next Up"
            type = "task_list"
            size = "third"
            position = @{ row = 4; col = 2 }
            settings = @{
                filters = @{
                    status = @("todo")
                    priority = @("urgent", "high")
                }
                sort = @{
                    field = "priority"
                    direction = "desc"
                }
                limit = 10
            }
        }

        # Widget 9: Cycle Time
        @{
            id = 9
            name = "[METRIC] Average Cycle Time"
            type = "line_chart"
            size = "third"
            position = @{ row = 4; col = 3 }
            settings = @{
                metric = "cycle_time"
                time_range = "last_4_weeks"
                aggregation = "average"
                target_line = 3
            }
        }

        # Widget 10: Completed This Week
        @{
            id = 10
            name = "[DONE] Completed This Week"
            type = "task_list"
            size = "half"
            position = @{ row = 5; col = 1 }
            settings = @{
                filters = @{
                    status = @("done")
                    date_closed_gte = "7_days_ago"
                }
                sort = @{
                    field = "date_closed"
                    direction = "desc"
                }
                fields = @("name", "assignee", "date_closed", "custom_field_pr_link")
                limit = 15
            }
        }

        # Widget 11: Cumulative Flow
        @{
            id = 11
            name = "[FLOW] Work In Progress"
            type = "area_chart"
            size = "half"
            position = @{ row = 5; col = 2 }
            settings = @{
                time_range = "last_30_days"
                group_by = "status"
                stacked = $true
                layers = @("done", "review", "busy", "todo", "blocked")
            }
        }

        # Widget 12: Key Metrics
        @{
            id = 12
            name = "[METRICS] Sprint Health Indicators"
            type = "number_cards"
            size = "full"
            position = @{ row = 6; col = 1 }
            settings = @{
                metrics = @(
                    @{
                        name = "Tasks Done"
                        calculation = "count"
                        filter = @{ status = @("done"); time_range = "current_sprint" }
                        target = 40
                        trend = "increase_good"
                    }
                    @{
                        name = "Review Queue"
                        calculation = "count"
                        filter = @{ status = @("review") }
                        target = 3
                        trend = "decrease_good"
                    }
                    @{
                        name = "Blocked Items"
                        calculation = "count"
                        filter = @{ status = @("blocked") }
                        target = 2
                        trend = "decrease_good"
                    }
                    @{
                        name = "Avg Cycle Time"
                        calculation = "average_cycle_time"
                        filter = @{ time_range = "last_7_days" }
                        target = 3
                        unit = "days"
                        trend = "decrease_good"
                    }
                )
            }
        }
    )

    # Alert Rules
    alerts = @(
        @{
            name = "Blocked Items Alert"
            trigger = "count"
            condition = @{
                widget_id = 1
                operator = "greater_than"
                value = 5
            }
            action = @{
                type = "slack_notification"
                channel = "#dev-team"
                message = "[!] BLOCKED ITEMS ALERT: We have {{count}} blocked tasks requiring attention."
            }
            frequency = "daily"
            time = "09:00"
        }
        @{
            name = "Review SLA Alert"
            trigger = "custom_field"
            condition = @{
                widget_id = 2
                field = "days_in_review"
                operator = "greater_than"
                value = 2
            }
            action = @{
                type = "slack_notification"
                channel = "#dev-team"
                message = "[!] REVIEW SLA OVERDUE: {{task_name}} has been in review for {{days_in_review}} days."
            }
            frequency = "every_6_hours"
        }
    )

    # Custom Fields
    custom_fields = @(
        @{
            name = "RICE Score"
            type = "formula"
            formula = "(Reach * Impact * Confidence) / Effort"
            dependencies = @("Reach", "Impact", "Confidence", "Effort")
        }
        @{
            name = "Blocked Reason"
            type = "text"
            required_when = @{ status = "blocked" }
        }
        @{
            name = "Review SLA"
            type = "date"
            auto_set = $true
            formula = "date_moved_to_review + 24_hours"
        }
        @{
            name = "PR Link"
            type = "url"
        }
    )
}

# Generate configuration file
function Generate-Config {
    $json = $dashboardConfig | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "[OK] Dashboard configuration generated: $OutputPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Update workspace_id in the JSON file"
    Write-Host "2. Review widget configurations"
    Write-Host "3. Import into ClickUp or use as reference for manual setup"
    Write-Host "4. Configure Slack webhook for alerts"
    Write-Host ""
    Write-Host "Documentation: C:\scripts\_machine\clickup-dashboard-setup.md" -ForegroundColor Yellow
}

# Display current dashboard stats
function Show-Stats {
    Write-Host "[STATS] Current ClickUp Board Stats" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""

    # Run clickup-sync to get current stats
    $result = & "C:\scripts\tools\clickup-sync.ps1" -Action list 2>&1

    Write-Host $result
    Write-Host ""
    Write-Host "Dashboard will provide real-time views of this data." -ForegroundColor Green
}

# Generate setup instructions
function Generate-Instructions {
    $instructions = @"
================================================================
       CLICKUP DASHBOARD SETUP - STEP BY STEP GUIDE
================================================================

PREREQUISITES:
* ClickUp workspace access (brand2boost)
* Admin or Owner permissions
* List ID: 901214097647 (Brand Designer)

SETUP STEPS:

STEP 1: Create Dashboard
━━━━━━━━━━━━━━━━━━━━━━━━
1. Go to ClickUp → Dashboards (left sidebar)
2. Click "+ New Dashboard"
3. Name: "Team Dashboard - Sprint [Current Week]"
4. Description: "Sprint health, blockers, team capacity"
5. Visibility: Team

STEP 2: Add Widgets (Row 1 - Urgent Attention)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Widget 1: Blocked Items
  - Type: List
  - Filter: status = "blocked"
  - Sort: date_updated (oldest first)
  - Size: 1/3 width
  - Background: Red (#ff4444)

Widget 2: Review Queue
  - Type: List
  - Filter: status = "review"
  - Sort: date_updated (oldest first)
  - Size: 1/3 width
  - Background: Orange (#ff9800)

Widget 3: Sprint Velocity
  - Type: Line Chart
  - Data: Tasks completed per week
  - Time range: Last 6 weeks
  - Size: 1/3 width

STEP 3: Add Widgets (Row 2 - Team & Progress)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Widget 4: Team Workload
  - Type: Workload View
  - Filter: status = "busy" OR "review"
  - Group by: Assignee
  - Size: 1/2 width

Widget 5: Epic Progress
  - Type: Progress Calculation
  - Group by: Epic
  - Show: Progress bar + percentage
  - Size: 1/2 width

STEP 4: Add Widgets (Row 3 - Active Sprint)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Widget 6: Sprint Kanban
  - Type: Board View
  - Columns: TODO | BUSY | REVIEW | BLOCKED
  - Size: Full width

STEP 5: Configure Alerts
━━━━━━━━━━━━━━━━━━━━━━━━
1. Go to Settings → Integrations → Slack
2. Add webhook for #dev-team channel
3. Create automation:
   - Trigger: Blocked tasks > 5
   - Action: Send Slack notification
   - Frequency: Daily at 9 AM

4. Create automation:
   - Trigger: Task in review > 48 hours
   - Action: Send Slack notification
   - Frequency: Every 6 hours

STEP 6: Test Dashboard
━━━━━━━━━━━━━━━━━━━━━━
1. Open dashboard
2. Verify all widgets load data
3. Check filters are working
4. Test Slack notifications
5. Share with team

SUCCESS CRITERIA:
[ ] All widgets display data correctly
[ ] Blocked items widget shows current 7 blocked tasks
[ ] Review queue shows current 13 tasks
[ ] Team can access and view dashboard
[ ] Slack alerts are working

FULL DOCUMENTATION:
C:\scripts\_machine\clickup-dashboard-setup.md

CONFIGURATION FILE:
$OutputPath

NEED HELP?
- ClickUp docs: https://docs.clickup.com/en/articles/856285-dashboards
- Post in #dev-team Slack
- Review setup guide above

===============================================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@

    Write-Host $instructions
}

# Main execution
switch ($Action) {
    "generate" {
        Generate-Config
        Generate-Instructions
    }
    "stats" {
        Show-Stats
    }
    "instructions" {
        Generate-Instructions
    }
    default {
        Write-Host "Usage: .\clickup-dashboard-builder.ps1 -Action [generate|stats|instructions]" -ForegroundColor Yellow
    }
}
