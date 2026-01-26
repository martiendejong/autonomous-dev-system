# Sync C:\scripts to C:\Projects\claudescripts (public distribution repo)
# Excludes machine-specific files (_machine/), secrets, and temporary files

param(
    [switch]$DryRun,
    [switch]$NoPush,
    [string]$CommitMessage = "sync: Update from C:\scripts production system"
)

$ErrorActionPreference = "Stop"

$sourceDir = "C:\scripts"
$targetDir = "C:\Projects\claudescripts"

Write-Host "[SYNC] C:\scripts -> C:\Projects\claudescripts" -ForegroundColor Cyan
Write-Host ""

# Verify directories
if (-not (Test-Path $sourceDir)) {
    Write-Host "[ERROR] Source not found: $sourceDir" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $targetDir)) {
    Write-Host "[ERROR] Target not found: $targetDir" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "$targetDir\.git")) {
    Write-Host "[ERROR] Target is not a git repository" -ForegroundColor Red
    exit 1
}

# Sync with robocopy
Write-Host "[INFO] Syncing files..." -ForegroundColor Yellow

$params = @(
    $sourceDir
    $targetDir
    '/MIR'
    '/XD', '.git', '_machine', 'node_modules'
    '/XF', '*.log', '*.tmp', '*.secret', '*.key', 'tmpclaude-*', 'temp_clickup.json', 'temp_clickup_comment.txt', 'create-hazinastore-config.py', 'oauth-keys.json', 'credentials.json'
    '/NFL', '/NDL', '/NJH', '/NJS'
)

if ($DryRun) {
    $params += '/L'
    Write-Host "[DRY RUN] No files will be modified" -ForegroundColor Magenta
}

& robocopy @params | Out-Null
$exitCode = $LASTEXITCODE

if ($exitCode -ge 8) {
    Write-Host "[ERROR] Robocopy failed: $exitCode" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Files synced" -ForegroundColor Green
Write-Host ""

# Check for changes
Push-Location $targetDir
try {
    $gitStatus = git status --short
    $changedFiles = ($gitStatus | Measure-Object).Count

    if ($changedFiles -eq 0) {
        Write-Host "[INFO] No changes - repository up to date" -ForegroundColor Green
        exit 0
    }

    Write-Host "[INFO] Changed files: $changedFiles" -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host ""
        git status --short
        exit 0
    }

    # Commit
    Write-Host "[INFO] Committing changes..." -ForegroundColor Yellow
    git add -A
    git commit -m $CommitMessage

    Write-Host "[SUCCESS] Changes committed" -ForegroundColor Green

    # Push
    if (-not $NoPush) {
        Write-Host "[INFO] Pushing to remote..." -ForegroundColor Yellow
        git push origin master

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] Pushed to GitHub!" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Push failed" -ForegroundColor Red
            exit 1
        }
    }

} finally {
    Pop-Location
}

Write-Host ""
Write-Host "[COMPLETE] Sync finished successfully" -ForegroundColor Green
Write-Host "  Source: C:\scripts (machine_agents repo)"
Write-Host "  Target: C:\Projects\claudescripts (autonomous-dev-system repo)"
