<#
.SYNOPSIS
    Automated PR merge sequencer based on cross-repo dependencies.

.DESCRIPTION
    Reads pr-dependencies.md and merges PRs in correct topological order.
    Handles Hazina → client-manager dependencies automatically.

    Waits for CI to pass between merges to ensure stability.

.PARAMETER DryRun
    Show merge plan without executing

.PARAMETER WaitForCI
    Wait for CI checks to pass before proceeding (default: true)

.PARAMETER AutoUpdate
    Automatically update pr-dependencies.md after merges

.EXAMPLE
    .\merge-pr-sequence.ps1 -DryRun
    .\merge-pr-sequence.ps1
    .\merge-pr-sequence.ps1 -AutoUpdate
#>

param(
    [switch]$DryRun,
    [switch]$WaitForCI = $true,
    [switch]$AutoUpdate
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$DependenciesFile = "C:\scripts\_machine\pr-dependencies.md"
$Repositories = @{
    "hazina" = "C:\Projects\hazina"
    "client-manager" = "C:\Projects\client-manager"
    "artrevisionist" = "C:\Projects\artrevisionist"
    "bugattiinsights" = "C:\Projects\bugattiinsights"
}

function Parse-Dependencies {
    if (-not (Test-Path $DependenciesFile)) {
        Write-Host "ERROR: Dependencies file not found: $DependenciesFile" -ForegroundColor Red
        return @()
    }

    $content = Get-Content $DependenciesFile -Raw
    $dependencies = @()

    # Parse markdown table for dependencies
    # Format: | [client-manager#96](...) | [Hazina#37](...) | ⏳ Waiting | ... |
    $matches = [regex]::Matches($content, '\|\s*\[([^\]]+)\]\(([^\)]+)\)\s*\|\s*\[([^\]]+)\]\(([^\)]+)\)\s*\|\s*([^|]+)\s*\|')

    foreach ($match in $matches) {
        $downstream = $match.Groups[1].Value.Trim()
        $upstream = $match.Groups[3].Value.Trim()
        $status = $match.Groups[5].Value.Trim()

        # Parse repo and PR number
        if ($downstream -match '([^#]+)#(\d+)') {
            $downstreamRepo = $matches[1].Trim()
            $downstreamPR = $matches[2].Trim()
        }

        if ($upstream -match '([^#]+)#(\d+)') {
            $upstreamRepo = $matches[1].Trim()
            $upstreamPR = $matches[2].Trim()
        }

        $dependencies += @{
            "DownstreamRepo" = $downstreamRepo
            "DownstreamPR" = $downstreamPR
            "UpstreamRepo" = $upstreamRepo
            "UpstreamPR" = $upstreamPR
            "Status" = $status
        }
    }

    return $dependencies
}

function Get-AllOpenPRs {
    param([hashtable]$Repos)

    $allPRs = @()

    foreach ($repoName in $Repos.Keys) {
        $repoPath = $Repos[$repoName]
        if (-not (Test-Path $repoPath)) {
            Write-Host "WARNING: Repo not found: $repoPath" -ForegroundColor Yellow
            continue
        }

        Push-Location $repoPath
        try {
            $prs = gh pr list --json number,title,url,state --limit 100 | ConvertFrom-Json

            foreach ($pr in $prs) {
                if ($pr.state -eq "OPEN") {
                    $allPRs += @{
                        "Repo" = $repoName
                        "Number" = $pr.number
                        "Title" = $pr.title
                        "URL" = $pr.url
                    }
                }
            }
        } finally {
            Pop-Location
        }
    }

    return $allPRs
}

function Build-MergeOrder {
    param(
        [array]$Dependencies,
        [array]$AllPRs
    )

    # Build dependency graph
    $graph = @{}
    $inDegree = @{}

    # Initialize graph
    foreach ($pr in $AllPRs) {
        $key = "$($pr.Repo)#$($pr.Number)"
        $graph[$key] = @()
        $inDegree[$key] = 0
    }

    # Add edges (upstream -> downstream)
    foreach ($dep in $Dependencies) {
        $upstreamKey = "$($dep.UpstreamRepo)#$($dep.UpstreamPR)"
        $downstreamKey = "$($dep.DownstreamRepo)#$($dep.DownstreamPR)"

        if ($graph.ContainsKey($upstreamKey) -and $graph.ContainsKey($downstreamKey)) {
            $graph[$upstreamKey] += $downstreamKey
            $inDegree[$downstreamKey]++
        }
    }

    # Topological sort (Kahn's algorithm)
    $queue = [System.Collections.Queue]::new()
    $result = @()

    # Find all nodes with no incoming edges
    foreach ($key in $inDegree.Keys) {
        if ($inDegree[$key] -eq 0) {
            $queue.Enqueue($key)
        }
    }

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $result += $current

        foreach ($neighbor in $graph[$current]) {
            $inDegree[$neighbor]--
            if ($inDegree[$neighbor] -eq 0) {
                $queue.Enqueue($neighbor)
            }
        }
    }

    # Check for cycles
    if ($result.Count -ne $graph.Count) {
        Write-Host "WARNING: Circular dependencies detected! Cannot determine merge order." -ForegroundColor Yellow
        return $null
    }

    # Map back to PR objects
    $orderedPRs = @()
    foreach ($key in $result) {
        $pr = $AllPRs | Where-Object { "$($_.Repo)#$($_.Number)" -eq $key }
        if ($pr) {
            $orderedPRs += $pr
        }
    }

    return $orderedPRs
}

function Wait-ForCIChecks {
    param(
        [string]$RepoPath,
        [int]$PRNumber,
        [int]$MaxWaitMinutes = 10
    )

    Write-Host "  Waiting for CI checks to pass (max $MaxWaitMinutes minutes)..." -ForegroundColor DarkGray

    $startTime = Get-Date
    $checkInterval = 30  # seconds

    Push-Location $RepoPath
    try {
        while (((Get-Date) - $startTime).TotalMinutes -lt $MaxWaitMinutes) {
            $checks = gh pr checks $PRNumber --json state,conclusion | ConvertFrom-Json

            $allPassed = $true
            $pending = 0

            foreach ($check in $checks) {
                if ($check.state -eq "PENDING" -or $check.state -eq "IN_PROGRESS") {
                    $pending++
                    $allPassed = $false
                } elseif ($check.conclusion -ne "SUCCESS" -and $check.conclusion -ne "SKIPPED") {
                    Write-Host "  ✗ Check failed: $($check.name) - $($check.conclusion)" -ForegroundColor Red
                    return $false
                }
            }

            if ($allPassed -and $checks.Count -gt 0) {
                Write-Host "  ✓ All CI checks passed" -ForegroundColor Green
                return $true
            }

            Write-Host "  ⏳ Waiting for $pending checks... ($([math]::Round(((Get-Date) - $startTime).TotalMinutes, 1))m elapsed)" -ForegroundColor DarkGray
            Start-Sleep -Seconds $checkInterval
        }

        Write-Host "  ⚠ Timeout waiting for CI checks" -ForegroundColor Yellow
        return $false

    } finally {
        Pop-Location
    }
}

function Merge-PR {
    param(
        [hashtable]$PR,
        [bool]$WaitCI
    )

    $repoPath = $Repositories[$PR.Repo]
    if (-not $repoPath) {
        Write-Host "  ERROR: Repository path not found for $($PR.Repo)" -ForegroundColor Red
        return $false
    }

    Write-Host ""
    Write-Host "=== Merging PR: $($PR.Repo)#$($PR.Number) ===" -ForegroundColor Cyan
    Write-Host "  Title: $($PR.Title)" -ForegroundColor White
    Write-Host "  URL: $($PR.URL)" -ForegroundColor DarkGray

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would merge this PR" -ForegroundColor Yellow
        return $true
    }

    # Wait for CI if requested
    if ($WaitCI) {
        $ciPassed = Wait-ForCIChecks -RepoPath $repoPath -PRNumber $PR.Number
        if (-not $ciPassed) {
            Write-Host "  ✗ CI checks failed or timed out. Skipping merge." -ForegroundColor Red
            return $false
        }
    }

    # Merge the PR
    Push-Location $repoPath
    try {
        $mergeResult = gh pr merge $PR.Number --squash --delete-branch 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Merged successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ✗ Merge failed: $mergeResult" -ForegroundColor Red
            return $false
        }

    } finally {
        Pop-Location
    }
}

function Update-DependenciesFile {
    param([array]$MergedPRs)

    Write-Host ""
    Write-Host "=== Updating Dependencies File ===" -ForegroundColor Cyan

    $content = Get-Content $DependenciesFile -Raw

    foreach ($pr in $MergedPRs) {
        $key = "$($pr.Repo)#$($pr.Number)"

        # Update status from ⏳ Waiting → 🔀 Merged
        $content = $content -replace "(\| \[$key\][^\|]+\|[^\|]+\|)\s*⏳ Waiting\s*\|", "`$1 🔀 Merged |"
    }

    $content | Set-Content $DependenciesFile -Encoding UTF8
    Write-Host "  ✓ Updated $DependenciesFile" -ForegroundColor Green
}

# Main execution
Write-Host ""
Write-Host "=== PR Merge Sequencer ===" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN MODE - No actual merges will occur]" -ForegroundColor Yellow
    Write-Host ""
}

# Parse dependencies
Write-Host "Parsing dependencies from: $DependenciesFile" -ForegroundColor White
$dependencies = Parse-Dependencies

if ($dependencies.Count -eq 0) {
    Write-Host "No dependencies found in $DependenciesFile" -ForegroundColor Yellow
    Write-Host "This tool requires dependency tracking. Add entries to pr-dependencies.md first." -ForegroundColor Yellow
    exit 0
}

Write-Host "  Found $($dependencies.Count) dependencies" -ForegroundColor Green

# Get all open PRs
Write-Host "Fetching open PRs from repositories..." -ForegroundColor White
$allPRs = Get-AllOpenPRs -Repos $Repositories
Write-Host "  Found $($allPRs.Count) open PRs" -ForegroundColor Green

if ($allPRs.Count -eq 0) {
    Write-Host ""
    Write-Host "No open PRs found. Nothing to merge." -ForegroundColor Yellow
    exit 0
}

# Build merge order
Write-Host "Building merge order (topological sort)..." -ForegroundColor White
$mergeOrder = Build-MergeOrder -Dependencies $dependencies -AllPRs $allPRs

if (-not $mergeOrder) {
    Write-Host "ERROR: Could not determine merge order (circular dependencies?)" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ Merge order determined" -ForegroundColor Green
Write-Host ""
Write-Host "Merge Plan:" -ForegroundColor Cyan
for ($i = 0; $i -lt $mergeOrder.Count; $i++) {
    $pr = $mergeOrder[$i]
    Write-Host ("  {0}. {1}#{2} - {3}" -f ($i + 1), $pr.Repo, $pr.Number, $pr.Title) -ForegroundColor White
}
Write-Host ""

# Execute merges
$mergedPRs = @()
$failedPRs = @()

foreach ($pr in $mergeOrder) {
    $success = Merge-PR -PR $pr -WaitCI:$WaitForCI

    if ($success) {
        $mergedPRs += $pr
    } else {
        $failedPRs += $pr
        Write-Host ""
        Write-Host "STOPPING: Failed to merge $($pr.Repo)#$($pr.Number)" -ForegroundColor Red
        Write-Host "Remaining PRs will not be processed to avoid dependency violations." -ForegroundColor Yellow
        break
    }
}

# Summary
Write-Host ""
Write-Host "=== Merge Summary ===" -ForegroundColor Cyan
Write-Host "  Merged: $($mergedPRs.Count)" -ForegroundColor Green
Write-Host "  Failed: $($failedPRs.Count)" -ForegroundColor $(if ($failedPRs.Count -gt 0) { "Red" } else { "DarkGray" })
Write-Host "  Pending: $($mergeOrder.Count - $mergedPRs.Count - $failedPRs.Count)" -ForegroundColor Yellow
Write-Host ""

# Update dependencies file if requested
if ($AutoUpdate -and $mergedPRs.Count -gt 0 -and -not $DryRun) {
    Update-DependenciesFile -MergedPRs $mergedPRs
}

if ($failedPRs.Count -gt 0) {
    exit 1
}

exit 0
