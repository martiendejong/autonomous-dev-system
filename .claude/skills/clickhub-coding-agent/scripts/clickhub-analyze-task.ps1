# ClickHub Task Analyzer - Deep analysis of a single ClickUp task
# Performs comprehensive analysis of a ClickUp task to identify:
# - Related code in codebase
# - Existing branches/PRs
# - Uncertainties that need clarification
# - Implementation approach options

param(
    [Parameter(Mandatory)]
    [string]$TaskId
)

$ErrorActionPreference = "Stop"

# Paths
$toolsPath = "C:\scripts\tools"
$projectPath = "C:\Projects\client-manager"

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "   ClickHub Task Analyzer" -ForegroundColor Cyan
Write-Host "================================================================`n" -ForegroundColor Cyan

# Step 1: Fetch task details
Write-Host "[1/5] Fetching task details from ClickUp..." -ForegroundColor Yellow
try {
    $taskOutput = & "$toolsPath\clickup-sync.ps1" -Action show -TaskId $TaskId 2>&1 | Out-String
    Write-Host $taskOutput
} catch {
    Write-Error "Failed to fetch task: $($_.Exception.Message)"
    exit 1
}

# Step 2: Search for related branches
Write-Host "`n[2/5] Searching for related branches..." -ForegroundColor Yellow
Push-Location $projectPath
try {
    $branches = git branch -a 2>&1 | Select-String -Pattern $TaskId
    if ($branches) {
        Write-Host "Found related branches:" -ForegroundColor Green
        $branches | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "No related branches found" -ForegroundColor Gray
    }
} finally {
    Pop-Location
}

# Step 3: Search for related PRs
Write-Host "`n[3/5] Searching for related PRs..." -ForegroundColor Yellow
try {
    $prs = gh pr list --search $TaskId --json number,title,state 2>&1
    if ($prs -and $prs -ne "[]") {
        $prData = $prs | ConvertFrom-Json
        Write-Host "Found related PRs:" -ForegroundColor Green
        $prData | ForEach-Object {
            Write-Host "  PR #$($_.number): $($_.title) [$($_.state)]"
        }
    } else {
        Write-Host "No related PRs found" -ForegroundColor Gray
    }
} catch {
    Write-Host "Could not search PRs: $($_.Exception.Message)" -ForegroundColor DarkGray
}

# Step 4: Search codebase for related code
Write-Host "`n[4/5] Searching codebase for potential related code..." -ForegroundColor Yellow
Write-Host "NOTE: This is a basic search. Claude should use Task/Explore agent for comprehensive analysis." -ForegroundColor DarkCyan
Write-Host "Suggested search keywords:" -ForegroundColor Gray
Write-Host "  - Use Task/Explore agent with query about the feature" -ForegroundColor DarkGray
Write-Host "  - Search for related components/services" -ForegroundColor DarkGray
Write-Host "  - Look for similar existing implementations" -ForegroundColor DarkGray

# Step 5: Uncertainty Analysis
Write-Host "`n[5/5] Uncertainty Analysis..." -ForegroundColor Yellow
Write-Host "`nQuestions to consider:" -ForegroundColor Cyan
Write-Host "  [ ] Are requirements specific and complete?" -ForegroundColor White
Write-Host "  [ ] Is the technical approach clear?" -ForegroundColor White
Write-Host "  [ ] Are there multiple valid implementation options?" -ForegroundColor White
Write-Host "  [ ] Are there UI/UX specifications?" -ForegroundColor White
Write-Host "  [ ] Are there dependencies on other tasks/PRs?" -ForegroundColor White
Write-Host "  [ ] Are there architectural implications?" -ForegroundColor White
Write-Host "  [ ] Is the acceptance criteria clear?" -ForegroundColor White

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "   Analysis Complete" -ForegroundColor Green
Write-Host "================================================================`n" -ForegroundColor Green

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Review analysis above" -ForegroundColor White
Write-Host "  2. If uncertainties exist - Post questions and move to blocked" -ForegroundColor White
Write-Host "  3. If clear - Allocate worktree and implement" -ForegroundColor White
Write-Host "  4. Use allocate-worktree skill for implementation`n" -ForegroundColor White
