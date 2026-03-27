<#
.SYNOPSIS
    Generates a daily activity summary across all agent sessions.

.DESCRIPTION
    Creates a digest of:
    - Worktree allocations/releases
    - PRs created
    - Reflection entries added
    - Git activity across repos
    - Tool usage patterns

.PARAMETER Date
    Date to generate summary for (default: today)

.PARAMETER Output
    Output format: text, markdown, or json (default: text)

.EXAMPLE
    .\daily-summary.ps1
    .\daily-summary.ps1 -Date "2026-01-14"
    .\daily-summary.ps1 -Output markdown
#>

param(
    [string]$Date = (Get-Date -Format "yyyy-MM-dd")

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
,
    [ValidateSet("text", "markdown", "json")]
    [string]$Output = "text"
)

$ActivityPath = "C:\scripts\_machine\worktrees.activity.md"
$ReflectionPath = "C:\scripts\_machine\reflection.log.md"
$BaseRepos = @("C:\Projects\client-manager", "C:\Projects\hazina")

function Get-WorktreeActivity {
    param([string]$TargetDate)

    $activities = @()
    if (Test-Path $ActivityPath) {
        $content = Get-Content $ActivityPath
        foreach ($line in $content) {
            if ($line -match "^\| $TargetDate") {
                if ($line -match "\| ($TargetDate \d{2}:\d{2}:\d{2}?) \| (agent-\d+) \| (\w+) \| ([^|]*) \| ([^|]*) \|") {
                    $activities += @{
                        time = $matches[1]
                        seat = $matches[2]
                        action = $matches[3]
                        repo = $matches[4].Trim()
                        branch = $matches[5].Trim()
                    }
                }
            }
        }
    }
    return $activities
}

function Get-ReflectionEntries {
    param([string]$TargetDate)

    $entries = @()
    if (Test-Path $ReflectionPath) {
        $content = Get-Content $ReflectionPath -Raw
        $pattern = "## $TargetDate \[([^\]]+)\][^\n]*\n\n\*\*Pattern Type:\*\* ([^\n]+)"
        $matches = [regex]::Matches($content, $pattern)

        foreach ($match in $matches) {
            $entries += @{
                tag = $match.Groups[1].Value
                type = $match.Groups[2].Value
            }
        }
    }
    return $entries
}

function Get-GitActivity {
    param([string]$TargetDate)

    $commits = @()
    foreach ($repo in $BaseRepos) {
        if (Test-Path $repo) {
            $repoName = Split-Path $repo -Leaf
            $log = git -C $repo log --since="$TargetDate 00:00:00" --until="$TargetDate 23:59:59" --format="%h|%s|%an" 2>$null

            if ($log) {
                foreach ($entry in ($log -split "`n" | Where-Object { $_ })) {
                    $parts = $entry -split "\|"
                    if ($parts.Count -ge 3) {
                        $commits += @{
                            repo = $repoName
                            hash = $parts[0]
                            message = $parts[1]
                            author = $parts[2]
                        }
                    }
                }
            }
        }
    }
    return $commits
}

function Get-PRsCreated {
    param([string]$TargetDate)

    $prs = @()
    foreach ($repo in $BaseRepos) {
        if (Test-Path $repo) {
            $repoName = Split-Path $repo -Leaf

            # Get repo remote URL to determine owner/repo
            $remote = git -C $repo remote get-url origin 2>$null
            if ($remote -match "github\.com[:/]([^/]+)/([^/.]+)") {
                $owner = $matches[1]
                $repoSlug = $matches[2]

                try {
                    $prList = gh pr list --repo "$owner/$repoSlug" --state all --json number,title,createdAt,state 2>$null | ConvertFrom-Json
                    foreach ($pr in $prList) {
                        if ($pr.createdAt -match "^$TargetDate") {
                            $prs += @{
                                repo = $repoName
                                number = $pr.number
                                title = $pr.title
                                state = $pr.state
                            }
                        }
                    }
                } catch {}
            }
        }
    }
    return $prs
}

# Gather all data
$worktreeActivity = Get-WorktreeActivity -TargetDate $Date
$reflections = Get-ReflectionEntries -TargetDate $Date
$commits = Get-GitActivity -TargetDate $Date
$prs = Get-PRsCreated -TargetDate $Date

# Build summary object
$summary = @{
    date = $Date
    worktreeActivity = @{
        allocations = ($worktreeActivity | Where-Object { $_.action -eq "ALLOCATE" }).Count
        releases = ($worktreeActivity | Where-Object { $_.action -eq "RELEASE" }).Count
        details = $worktreeActivity
    }
    reflections = @{
        count = $reflections.Count
        entries = $reflections
    }
    git = @{
        commitCount = $commits.Count
        commits = $commits
    }
    pullRequests = @{
        created = $prs.Count
        prs = $prs
    }
}

# Output based on format
switch ($Output) {
    "json" {
        $summary | ConvertTo-Json -Depth 5
    }
    "markdown" {
        $md = @"
# Daily Summary: $Date

## Worktree Activity
- **Allocations:** $($summary.worktreeActivity.allocations)
- **Releases:** $($summary.worktreeActivity.releases)

## Reflections Added
- **Count:** $($summary.reflections.count)
$(if ($summary.reflections.entries) {
    $summary.reflections.entries | ForEach-Object { "- [$($_.tag)] $($_.type)" }
} else { "- (none)" })

## Git Commits
- **Total:** $($summary.git.commitCount)
$(if ($summary.git.commits) {
    $summary.git.commits | ForEach-Object { "- ``$($_.hash)`` $($_.repo): $($_.message)" }
} else { "- (none)" })

## Pull Requests
- **Created:** $($summary.pullRequests.created)
$(if ($summary.pullRequests.prs) {
    $summary.pullRequests.prs | ForEach-Object { "- #$($_.number) $($_.repo): $($_.title) [$($_.state)]" }
} else { "- (none)" })

---
*Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')*
"@
        Write-Output $md
    }
    "text" {
        Write-Host ""
        Write-Host "=== DAILY SUMMARY: $Date ===" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "WORKTREE ACTIVITY" -ForegroundColor Yellow
        Write-Host "  Allocations: $($summary.worktreeActivity.allocations)"
        Write-Host "  Releases: $($summary.worktreeActivity.releases)"
        if ($summary.worktreeActivity.details) {
            $summary.worktreeActivity.details | ForEach-Object {
                Write-Host "    $($_.time) $($_.seat) $($_.action) $($_.repo) $($_.branch)" -ForegroundColor DarkGray
            }
        }
        Write-Host ""

        Write-Host "REFLECTIONS" -ForegroundColor Yellow
        Write-Host "  Count: $($summary.reflections.count)"
        if ($summary.reflections.entries) {
            $summary.reflections.entries | ForEach-Object {
                Write-Host "    [$($_.tag)] $($_.type)" -ForegroundColor DarkCyan
            }
        }
        Write-Host ""

        Write-Host "GIT ACTIVITY" -ForegroundColor Yellow
        Write-Host "  Commits: $($summary.git.commitCount)"
        if ($summary.git.commits) {
            $summary.git.commits | Select-Object -First 10 | ForEach-Object {
                Write-Host "    $($_.hash) $($_.repo): $($_.message)" -ForegroundColor DarkGray
            }
            if ($summary.git.commits.Count -gt 10) {
                Write-Host "    ... and $($summary.git.commits.Count - 10) more" -ForegroundColor DarkGray
            }
        }
        Write-Host ""

        Write-Host "PULL REQUESTS" -ForegroundColor Yellow
        Write-Host "  Created: $($summary.pullRequests.created)"
        if ($summary.pullRequests.prs) {
            $summary.pullRequests.prs | ForEach-Object {
                $stateColor = if ($_.state -eq "MERGED") { "Green" } elseif ($_.state -eq "OPEN") { "Yellow" } else { "Red" }
                Write-Host "    #$($_.number) $($_.repo): $($_.title) " -NoNewline
                Write-Host "[$($_.state)]" -ForegroundColor $stateColor
            }
        }
        Write-Host ""
    }
}
