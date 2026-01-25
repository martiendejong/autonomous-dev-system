<#
.SYNOPSIS
    Single-command worktree allocation with all safety checks.

.DESCRIPTION
    Automates the complete worktree allocation workflow:
    1. Checks for free seat (or auto-provisions new one)
    2. Verifies base repo is on develop
    3. Creates worktree with proper branch
    4. Updates pool.md
    5. Logs activity
    6. Optionally allocates paired Hazina worktree

.PARAMETER Repo
    Repository to allocate (client-manager or hazina)

.PARAMETER Branch
    Branch name for the worktree

.PARAMETER Seat
    Specific seat to use (optional - auto-selects if not provided)

.PARAMETER Paired
    Also allocate Hazina worktree (for client-manager work)

.PARAMETER Description
    Short description of what you're working on

.EXAMPLE
    .\worktree-allocate.ps1 -Repo client-manager -Branch feature/new-thing
    .\worktree-allocate.ps1 -Repo client-manager -Branch feature/x -Paired -Description "Adding PDF export"
    .\worktree-allocate.ps1 -Repo hazina -Branch fix/bug -Seat agent-003
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("client-manager", "hazina")]
    [string]$Repo,

    [Parameter(Mandatory=$true)]
    [string]$Branch,

    [string]$Seat,
    [switch]$Paired,
    [string]$Description = "Worktree allocation"
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ErrorActionPreference = "Stop"

# Configuration
$MachineContext = "C:\scripts\_machine"
$PoolPath = "$MachineContext\worktrees.pool.md"
$ActivityPath = "$MachineContext\worktrees.activity.md"
$WorkerAgentsPath = "C:\Projects\worker-agents"
$BaseRepos = @{
    "client-manager" = "C:\Projects\client-manager"
    "hazina" = "C:\Projects\hazina"
}

function Write-Step {
    param([string]$Message, [string]$Status = "INFO")
    $color = switch ($Status) {
        "OK" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$Status] $Message" -ForegroundColor $color
}

function Get-FreeSeat {
    $content = Get-Content $PoolPath -Raw
    $lines = $content -split "`n" | Where-Object { $_ -match '^\| agent-' }

    foreach ($line in $lines) {
        if ($line -match '\| (agent-\d+) .* \| FREE \|') {
            return $matches[1]
        }
    }

    # No free seat - provision new one
    $maxNum = 0
    foreach ($line in $lines) {
        if ($line -match '\| agent-(\d+)') {
            $num = [int]$matches[1]
            if ($num -gt $maxNum) { $maxNum = $num }
        }
    }

    $newSeat = "agent-" + ($maxNum + 1).ToString("000")
    Write-Step "No free seats - provisioning $newSeat" "WARN"

    # Add new seat to pool
    $newRow = "| $newSeat | $($newSeat.Replace('-','')) | C:\Projects | C:\Projects\worker-agents\$newSeat | FREE | - | - | $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ') | Auto-provisioned |"
    Add-Content $PoolPath "`n$newRow"

    return $newSeat
}

function Test-BaseRepoState {
    param([string]$RepoPath)

    $branch = git -C $RepoPath branch --show-current 2>$null
    if ($branch -ne "develop") {
        Write-Step "Base repo is on '$branch' instead of 'develop'" "WARN"
        $status = git -C $RepoPath status --porcelain 2>$null
        if ([string]::IsNullOrWhiteSpace($status)) {
            Write-Step "Switching to develop..." "INFO"
            git -C $RepoPath checkout develop 2>$null
            git -C $RepoPath pull 2>$null
        } else {
            throw "Base repo has uncommitted changes and is not on develop. Please resolve manually."
        }
    }

    # Ensure up to date
    git -C $RepoPath fetch 2>$null
    $behind = git -C $RepoPath rev-list --count "HEAD..@{u}" 2>$null
    if ($behind -gt 0) {
        Write-Step "Pulling $behind commits from remote..." "INFO"
        git -C $RepoPath pull 2>$null
    }
}

function New-Worktree {
    param(
        [string]$SeatName,
        [string]$RepoName,
        [string]$BranchName
    )

    $basePath = $BaseRepos[$RepoName]
    $worktreePath = "$WorkerAgentsPath\$SeatName\$RepoName"

    # Create parent directory
    $parentPath = Split-Path $worktreePath -Parent
    if (-not (Test-Path $parentPath)) {
        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
    }

    # Check if branch already exists
    $branchExists = git -C $basePath branch --list $BranchName 2>$null
    $remoteBranchExists = git -C $basePath branch -r --list "origin/$BranchName" 2>$null

    if ($branchExists -or $remoteBranchExists) {
        Write-Step "Branch '$BranchName' already exists - using existing branch" "INFO"
        git -C $basePath worktree add $worktreePath $BranchName 2>&1
    } else {
        Write-Step "Creating new branch '$BranchName'" "INFO"
        git -C $basePath worktree add $worktreePath -b $BranchName 2>&1
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create worktree at $worktreePath"
    }

    return $worktreePath
}

function Update-Pool {
    param(
        [string]$SeatName,
        [string]$RepoName,
        [string]$BranchName,
        [string]$Desc
    )

    $content = Get-Content $PoolPath -Raw
    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
    $notes = "$Desc ($RepoName on $BranchName)"

    # Update the seat row
    $content = $content -replace "(\| $SeatName [^|]* \|[^|]*\|[^|]*\|) FREE (\|)[^|]*(\|)[^|]*(\|)[^|]*(\|).*\|", "`$1 BUSY `$2 $RepoName `$3 $BranchName `$4 $timestamp `$5 $notes |"

    $content | Set-Content $PoolPath -Encoding UTF8
}

function Log-Activity {
    param(
        [string]$SeatName,
        [string]$RepoName,
        [string]$BranchName
    )

    $entry = "| $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $SeatName | ALLOCATE | $RepoName | $BranchName | worktree-allocate.ps1 |"
    Add-Content $ActivityPath $entry
}

# Main execution
Write-Host ""
Write-Host "=== WORKTREE ALLOCATION ===" -ForegroundColor Cyan
Write-Host "Repository: $Repo"
Write-Host "Branch: $Branch"
Write-Host "Description: $Description"
if ($Paired) { Write-Host "Mode: PAIRED (client-manager + hazina)" }
Write-Host ""

try {
    # Step 1: Get seat
    if ($Seat) {
        # Verify specified seat is free
        $content = Get-Content $PoolPath -Raw
        if ($content -match "\| $Seat .* \| BUSY \|") {
            throw "Seat $Seat is already BUSY"
        }
        Write-Step "Using specified seat: $Seat" "OK"
    } else {
        $Seat = Get-FreeSeat
        Write-Step "Selected seat: $Seat" "OK"
    }

    # Step 2: Verify base repo
    Write-Step "Checking base repo state..." "INFO"
    Test-BaseRepoState -RepoPath $BaseRepos[$Repo]

    if ($Paired -and $Repo -eq "client-manager") {
        Write-Step "Checking Hazina base repo state..." "INFO"
        Test-BaseRepoState -RepoPath $BaseRepos["hazina"]
    }

    # Step 3: Create worktree(s)
    Write-Step "Creating worktree..." "INFO"
    $worktreePath = New-Worktree -SeatName $Seat -RepoName $Repo -BranchName $Branch
    Write-Step "Created: $worktreePath" "OK"

    if ($Paired -and $Repo -eq "client-manager") {
        Write-Step "Creating paired Hazina worktree..." "INFO"
        $hazinaPath = New-Worktree -SeatName $Seat -RepoName "hazina" -BranchName $Branch
        Write-Step "Created: $hazinaPath" "OK"
    }

    # Step 4: Update pool
    Write-Step "Updating pool status..." "INFO"
    Update-Pool -SeatName $Seat -RepoName $Repo -BranchName $Branch -Desc $Description
    Write-Step "Pool updated: $Seat -> BUSY" "OK"

    # Step 5: Log activity
    Log-Activity -SeatName $Seat -RepoName $Repo -BranchName $Branch
    if ($Paired) {
        Log-Activity -SeatName $Seat -RepoName "hazina" -BranchName $Branch
    }
    Write-Step "Activity logged" "OK"

    # Summary
    Write-Host ""
    Write-Host "=== ALLOCATION COMPLETE ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Seat: $Seat" -ForegroundColor White
    Write-Host "Primary: $WorkerAgentsPath\$Seat\$Repo" -ForegroundColor White
    if ($Paired) {
        Write-Host "Paired:  $WorkerAgentsPath\$Seat\hazina" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Edit code in: $WorkerAgentsPath\$Seat\$Repo" -ForegroundColor DarkGray
    Write-Host "  2. When done: .\tools\worktree-release-all.ps1 -Seats $Seat -AutoCommit" -ForegroundColor DarkGray
    Write-Host ""

} catch {
    Write-Step $_.Exception.Message "FAIL"
    Write-Host ""
    Write-Host "ALLOCATION FAILED" -ForegroundColor Red
    Write-Host "Please check the error above and try again." -ForegroundColor Red
    exit 1
}
