# PR Description Enforcer - Template checker + auto-generator
# Wave 2 Tool #4 (Ratio: 9.0)

param(
    [Parameter(Mandatory=$false)]
    [string]$PRNumber,

    [Parameter(Mandatory=$false)]
    [ValidateSet('check', 'generate', 'fix')]
    [string]$Action = 'check'
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$RequiredSections = @(
    '## Summary',
    '## Test Plan',
    '## Checklist'
)

function Check-PRDescription {
    param([string]$PRNumber)

    if (-not $PRNumber) {
        # Get current branch PR
        $branch = git branch --show-current
        $prInfo = gh pr list --head $branch --json number,body 2>$null | ConvertFrom-Json
        if (-not $prInfo) {
            Write-Host "ERROR: No PR found for current branch" -ForegroundColor Red
            exit 1
        }
        $PRNumber = $prInfo[0].number
        $body = $prInfo[0].body
    } else {
        $prInfo = gh pr view $PRNumber --json body 2>$null | ConvertFrom-Json
        $body = $prInfo.body
    }

    Write-Host "Checking PR #$PRNumber description..." -ForegroundColor Cyan
    Write-Host ""

    $missing = @()
    foreach ($section in $RequiredSections) {
        if ($body -notmatch [regex]::Escape($section)) {
            $missing += $section
        }
    }

    if ($missing.Count -eq 0) {
        Write-Host "PASS: All required sections present" -ForegroundColor Green
        return $true
    } else {
        Write-Host "FAIL: Missing required sections:" -ForegroundColor Red
        $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
        Write-Host ""
        Write-Host "Run: .\pr-description-enforcer.ps1 -Action fix" -ForegroundColor Cyan
        return $false
    }
}

function Generate-PRDescription {
    # Get commit messages
    $commits = git log --oneline origin/develop..HEAD 2>$null

    # Get changed files
    $files = git diff --name-only origin/develop..HEAD 2>$null

    $template = @"
## Summary
$($commits -join "`n")

## Changes
- Modified $($files.Count) files
$(($files | Select-Object -First 10) -join "`n- ")

## Test Plan
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guide
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
- [ ] Migrations included (if needed)

Generated with Claude Code
"@

    return $template
}

switch ($Action) {
    'check' { Check-PRDescription -PRNumber $PRNumber }
    'generate' {
        $desc = Generate-PRDescription
        Write-Host $desc
        Write-Host ""
        Write-Host "Copy above to PR description" -ForegroundColor Cyan
    }
    'fix' {
        $desc = Generate-PRDescription
        Write-Host "Generated template:" -ForegroundColor Green
        Write-Host $desc
    }
}
