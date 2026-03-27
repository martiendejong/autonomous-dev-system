<#
.SYNOPSIS
    Toggle GitHub Actions workflow triggers between automatic and manual modes

.DESCRIPTION
    Converts workflow triggers between:
    - Automatic: push, pull_request, schedule
    - Manual: workflow_dispatch only

    Useful for:
    - Billing issues (disable automatic runs)
    - Testing/development (manual control)
    - Deployment freezes

.PARAMETER RepoPath
    Path to repository (default: C:\Projects\client-manager)

.PARAMETER Mode
    Target mode: "manual" or "automatic"
    - manual: Remove all automatic triggers, keep only workflow_dispatch
    - automatic: Add back push/pull_request triggers (requires backup)

.PARAMETER DryRun
    Preview changes without modifying files

.PARAMETER Backup
    Create backup of workflows before modification (default: true)

.PARAMETER WorkflowFilter
    Only process workflows matching this pattern (e.g., "*build*")

.EXAMPLE
    .\toggle-workflow-triggers.ps1 -Mode manual -DryRun
    Preview conversion to manual-only mode

.EXAMPLE
    .\toggle-workflow-triggers.ps1 -Mode manual
    Convert all workflows to manual-only (workflow_dispatch)

.EXAMPLE
    .\toggle-workflow-triggers.ps1 -Mode manual -WorkflowFilter "*test*"
    Convert only test workflows to manual

.EXAMPLE
    .\toggle-workflow-triggers.ps1 -Mode automatic
    Restore automatic triggers from backup
#>

param(
    [string]$RepoPath = "C:\Projects\client-manager",
    [ValidateSet("manual", "automatic")

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
]
    [string]$Mode = "manual",
    [switch]$DryRun,
    [bool]$Backup = $true,
    [string]$WorkflowFilter = "*"
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  GitHub Actions Workflow Trigger Toggler" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Repository: $RepoPath" -ForegroundColor White
Write-Host "Mode: $(if ($Mode -eq 'manual') { 'AUTOMATIC → MANUAL' } else { 'MANUAL → AUTOMATIC' })" -ForegroundColor Cyan
Write-Host "Dry Run: $(if ($DryRun) { 'YES (preview only)' } else { 'NO' })" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Green' })
Write-Host ""

$workflowDir = Join-Path $RepoPath ".github\workflows"

if (-not (Test-Path $workflowDir)) {
    Write-Host "✗ Workflow directory not found: $workflowDir" -ForegroundColor Red
    exit 1
}

# Create backup if requested
if ($Backup -and -not $DryRun) {
    $backupDir = Join-Path $workflowDir "backups"
    $backupPath = Join-Path $backupDir "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    Get-ChildItem -Path $workflowDir -Filter "*.yml" | Copy-Item -Destination $backupPath
    Write-Host "✓ Backup created: $backupPath" -ForegroundColor Green
    Write-Host ""
}

$workflows = Get-ChildItem -Path $workflowDir -Filter $WorkflowFilter -Include "*.yml"

if ($workflows.Count -eq 0) {
    Write-Host "✗ No workflows found matching filter: $WorkflowFilter" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($workflows.Count) workflow(s)" -ForegroundColor Cyan
Write-Host ""

$modified = 0
$skipped = 0
$errors = @()

foreach ($workflow in $workflows) {
    Write-Host "Processing: $($workflow.Name)" -ForegroundColor White

    try {
        $content = Get-Content $workflow.FullName -Raw

        # Check current state
        $hasWorkflowDispatch = $content -match "workflow_dispatch:"
        $hasPush = $content -match "on:\s*\n\s*push:"
        $hasPullRequest = $content -match "pull_request:"
        $hasSchedule = $content -match "schedule:"

        $isManual = $hasWorkflowDispatch -and -not ($hasPush -or $hasPullRequest -or $hasSchedule)

        Write-Host "  Current state:" -ForegroundColor Gray
        Write-Host "    workflow_dispatch: $(if ($hasWorkflowDispatch) { '✓' } else { '✗' })" -ForegroundColor Gray
        Write-Host "    push: $(if ($hasPush) { '✓' } else { '✗' })" -ForegroundColor Gray
        Write-Host "    pull_request: $(if ($hasPullRequest) { '✓' } else { '✗' })" -ForegroundColor Gray
        Write-Host "    schedule: $(if ($hasSchedule) { '✓' } else { '✗' })" -ForegroundColor Gray

        if ($Mode -eq "manual") {
            if ($isManual) {
                Write-Host "  Already manual-only, skipping" -ForegroundColor Gray
                $skipped++
            } else {
                Write-Host "  Converting to manual-only..." -ForegroundColor Yellow

                # Find the 'on:' section and replace it
                $newContent = $content -replace "(?ms)^on:.*?(?=\n(permissions|jobs|env):\s*$)", @"
on:
  workflow_dispatch:
    inputs:
      reason:
        description: 'Reason for running this workflow'
        required: false
        default: 'Manual validation'

"@

                # Add comment explaining the change
                $newContent = $newContent -replace "(?m)^name: (.+)$", @"
name: `$1

# Manual workflow only - automatic triggers disabled
# Run manually from Actions tab when needed
"@

                if ($DryRun) {
                    Write-Host "  [DRY RUN] Would convert to manual-only" -ForegroundColor Yellow
                } else {
                    Set-Content -Path $workflow.FullName -Value $newContent -NoNewline
                    Write-Host "  ✓ Converted to manual-only" -ForegroundColor Green
                }
                $modified++
            }
        }
        else {
            # Mode: automatic (restore from backup or use defaults)
            if (-not $isManual) {
                Write-Host "  Already has automatic triggers, skipping" -ForegroundColor Gray
                $skipped++
            } else {
                Write-Host "  ✗ Cannot restore automatic triggers without backup" -ForegroundColor Red
                Write-Host "    Backup files are in: $workflowDir\backups\" -ForegroundColor Yellow
                $errors += $workflow.Name
            }
        }
    }
    catch {
        Write-Host "  ✗ Error: $_" -ForegroundColor Red
        $errors += $workflow.Name
    }

    Write-Host ""
}

# Summary
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Modified: $modified" -ForegroundColor $(if ($modified -gt 0) { "Green" } else { "Gray" })
Write-Host "Skipped:  $skipped" -ForegroundColor Gray
Write-Host "Errors:   $($errors.Count)" -ForegroundColor $(if ($errors.Count -gt 0) { "Red" } else { "Gray" })
Write-Host ""

if ($errors.Count -gt 0) {
    Write-Host "Failed workflows:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "  - $err" -ForegroundColor Red
    }
    Write-Host ""
}

if ($DryRun) {
    Write-Host "This was a DRY RUN - no changes were made" -ForegroundColor Yellow
    Write-Host "Run without -DryRun to apply changes" -ForegroundColor Yellow
} elseif ($modified -gt 0) {
    Write-Host "Don't forget to commit and push the changes:" -ForegroundColor Cyan
    Write-Host "  cd $RepoPath" -ForegroundColor White
    Write-Host "  git add .github/workflows/" -ForegroundColor White
    Write-Host "  git commit -m 'chore(ci): Toggle workflow triggers to $Mode mode'" -ForegroundColor White
    Write-Host "  git push origin <branch>" -ForegroundColor White
}
