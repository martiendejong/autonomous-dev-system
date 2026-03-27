<#
.SYNOPSIS
    One-Command Workflows - Complex multi-tool operations as single commands.
    50-Expert Council Improvement #15 | Priority: 2.0

.DESCRIPTION
    Executes complete workflows with a single command.
    Chains multiple tools together in the correct sequence.

.PARAMETER Workflow
    The workflow to execute:
    - feature: Complete feature development workflow
    - bugfix: Bug fix workflow
    - pr: Create PR workflow
    - release: Release worktree workflow
    - start: Session start workflow
    - end: Session end workflow
    - improve: Meta-improvement workflow

.PARAMETER Name
    Name/description for the workflow (used in branches, commits, etc.)

.PARAMETER DryRun
    Show what would be executed without running.

.EXAMPLE
    workflow.ps1 -Workflow feature -Name "add-user-auth"
    workflow.ps1 -Workflow start
    workflow.ps1 -Workflow end -DryRun
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("feature", "bugfix", "pr", "release", "start", "end", "improve")]
    [string]$Workflow,

    [string]$Name = "",

    [switch]$DryRun
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ToolsPath = "C:\scripts\tools"

function Execute-Step {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

    Write-Host "  → $Description" -ForegroundColor Cyan

    if (-not $DryRun) {
        try {
            & $Action
            Write-Host "    ✓ Complete" -ForegroundColor Green
        } catch {
            Write-Host "    ✗ Failed: $_" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "    [DRY RUN - would execute]" -ForegroundColor Gray
    }
    return $true
}

function Run-FeatureWorkflow {
    param([string]$FeatureName)

    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║           FEATURE DEVELOPMENT WORKFLOW                       ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    $branchName = "feature/$FeatureName"

    Execute-Step "Check error prevention rules" {
        & "$ToolsPath\prevent-errors.ps1" -Action "feature development $FeatureName"
    }

    Execute-Step "Allocate worktree for client-manager" {
        & "$ToolsPath\worktree-allocate.ps1" -Repo client-manager -Branch $branchName -ErrorAction SilentlyContinue
    }

    Execute-Step "Update task predictions" {
        & "$ToolsPath\predict-tasks.ps1" -Context "feature development $FeatureName"
    }

    Execute-Step "Run reflection checkpoint" {
        & "$ToolsPath\reflect.ps1" -Context "Starting $FeatureName" -Goal "Implement $FeatureName feature" -CheckOnly
    }

    Write-Host ""
    Write-Host "Feature workflow initialized. Ready for development." -ForegroundColor Green
    Write-Host "Branch: $branchName" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Magenta
    Write-Host "  1. Implement the feature" -ForegroundColor White
    Write-Host "  2. Run tests" -ForegroundColor White
    Write-Host "  3. Execute: workflow.ps1 -Workflow pr -Name '$FeatureName'" -ForegroundColor White
}

function Run-BugfixWorkflow {
    param([string]$BugName)

    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║           BUG FIX WORKFLOW                                   ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""

    $branchName = "bugfix/$BugName"

    Execute-Step "Check error prevention rules" {
        & "$ToolsPath\prevent-errors.ps1" -Action "bug fix $BugName"
    }

    Execute-Step "Allocate worktree" {
        & "$ToolsPath\worktree-allocate.ps1" -Repo client-manager -Branch $branchName -ErrorAction SilentlyContinue
    }

    Execute-Step "Update task predictions" {
        & "$ToolsPath\predict-tasks.ps1" -Context "bug fix $BugName"
    }

    Write-Host ""
    Write-Host "Bugfix workflow initialized." -ForegroundColor Green
    Write-Host "Branch: $branchName" -ForegroundColor Yellow
}

function Run-PRWorkflow {
    param([string]$PRName)

    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║           CREATE PR WORKFLOW                                 ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""

    Execute-Step "Run alignment check" {
        & "$ToolsPath\align.ps1" -Check
    }

    Execute-Step "Check for uncommitted changes" {
        git status -s
    }

    Execute-Step "Push branch to remote" {
        git push -u origin HEAD
    }

    Write-Host ""
    Write-Host "Ready to create PR. Use 'gh pr create' or GitHub UI." -ForegroundColor Green
}

function Run-ReleaseWorkflow {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║           RELEASE WORKTREE WORKFLOW                          ║" -ForegroundColor Blue
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""

    Execute-Step "Release all worktrees" {
        & "$ToolsPath\worktree-release-all.ps1" -AutoCommit -ErrorAction SilentlyContinue
    }

    Execute-Step "Update worktree status" {
        & "$ToolsPath\worktree-status.ps1" -Compact -ErrorAction SilentlyContinue
    }

    Execute-Step "Learn from completed task" {
        & "$ToolsPath\predict-tasks.ps1" -Learn
    }

    Write-Host ""
    Write-Host "Worktree released successfully." -ForegroundColor Green
}

function Run-StartWorkflow {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           SESSION START WORKFLOW                             ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    Execute-Step "Full status snapshot" {
        & "$ToolsPath\q.ps1" s
    }

    Execute-Step "Check activity context" {
        & "$ToolsPath\monitor-activity.ps1" -Mode context -ErrorAction SilentlyContinue
    }

    Execute-Step "Analyze prompt patterns" {
        & "$ToolsPath\pattern-learn.ps1" -Analyze -ErrorAction SilentlyContinue
    }

    Execute-Step "Scan for error prevention" {
        & "$ToolsPath\prevent-errors.ps1" -Scan -ErrorAction SilentlyContinue
    }

    Execute-Step "Show task predictions" {
        & "$ToolsPath\predict-tasks.ps1" -Show
    }

    Write-Host ""
    Write-Host "Session started. Full context loaded." -ForegroundColor Green
}

function Run-EndWorkflow {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor DarkGray
    Write-Host "║           SESSION END WORKFLOW                               ║" -ForegroundColor DarkGray
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor DarkGray
    Write-Host ""

    Execute-Step "Run final reflection" {
        & "$ToolsPath\reflect.ps1" -CheckOnly
    }

    Execute-Step "Check for unreleased worktrees" {
        & "$ToolsPath\worktree-status.ps1" -Compact -ErrorAction SilentlyContinue
    }

    Execute-Step "Learn patterns from session" {
        & "$ToolsPath\pattern-learn.ps1" -Analyze -Suggest -ErrorAction SilentlyContinue
    }

    Execute-Step "Commit and push scripts repo" {
        Push-Location "C:\scripts"
        git add -A
        $hasChanges = git diff --cached --quiet; $LASTEXITCODE -ne 0
        if ($hasChanges) {
            git commit -m "docs: Session end auto-commit $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            git push
        }
        Pop-Location
    }

    Write-Host ""
    Write-Host "Session ended. All learnings committed." -ForegroundColor Green
}

function Run-ImproveWorkflow {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║           META-IMPROVEMENT WORKFLOW                          ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""

    Execute-Step "Analyze current patterns" {
        & "$ToolsPath\pattern-learn.ps1" -Analyze -Suggest
    }

    Execute-Step "Update task predictions" {
        & "$ToolsPath\predict-tasks.ps1" -Context "meta improvement system enhancement"
    }

    Execute-Step "Run reflection checkpoint" {
        & "$ToolsPath\reflect.ps1" -Context "System improvement" -Goal "Make system 50x better"
    }

    Write-Host ""
    Write-Host "Improvement workflow initialized. Ready to enhance the system." -ForegroundColor Green
}

# Main execution
Write-Host ""
Write-Host "WORKFLOW: $Workflow" -ForegroundColor White
if ($DryRun) {
    Write-Host "[DRY RUN MODE]" -ForegroundColor Yellow
}
Write-Host ""

switch ($Workflow) {
    "feature" {
        if (-not $Name) { $Name = "unnamed-feature" }
        Run-FeatureWorkflow -FeatureName $Name
    }
    "bugfix" {
        if (-not $Name) { $Name = "unnamed-fix" }
        Run-BugfixWorkflow -BugName $Name
    }
    "pr" {
        Run-PRWorkflow -PRName $Name
    }
    "release" {
        Run-ReleaseWorkflow
    }
    "start" {
        Run-StartWorkflow
    }
    "end" {
        Run-EndWorkflow
    }
    "improve" {
        Run-ImproveWorkflow
    }
}

Write-Host ""
Write-Host "Workflow '$Workflow' complete." -ForegroundColor Green
