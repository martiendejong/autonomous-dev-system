# Cleanup public repository - remove all personal/machine-specific references
# Run this on C:\Projects\claudescripts before pushing

param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$targetDir = "C:\Projects\claudescripts"

Write-Host "[CLEANUP] Removing personal/project-specific references from public repo" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $targetDir)) {
    Write-Host "[ERROR] Target not found: $targetDir" -ForegroundColor Red
    exit 1
}

Push-Location $targetDir
try {
    # Files to delete entirely (contain hardcoded credentials or project-specific info)
    $filesToDelete = @(
        "analysis-50-expert-panel-brand2boost.md"
        "analysis-50-expert-panel-workflow-processes.md"
        "tools/backup-brand2boost.ps1"
        "tools/check-database.py"
        "tools/fix-database.py"
        "tools/full-backend-reset.py"
        "tools/ssh-check-backend.py"
        "tools/upload-config.py"
        "tools/check-bugatti-vps.ps1"
        "tools/check-vps-setup.ps1"
        "tools/add-prod-page.ps1"
        "tools/create-project-kb.ps1"
        "tools/update-getting-started.ps1"
        ".claude/skills/clickhub-coding-agent/scripts/clickhub-analyze-task.ps1"
    )

    Write-Host "[INFO] Deleting files with hardcoded credentials/project info..." -ForegroundColor Yellow
    $deletedCount = 0
    foreach ($file in $filesToDelete) {
        if (Test-Path $file) {
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would delete: $file" -ForegroundColor Magenta
            } else {
                Remove-Item $file -Force
                Write-Host "  Deleted: $file" -ForegroundColor Red
                $deletedCount++
            }
        }
    }
    Write-Host "[INFO] Deleted $deletedCount files" -ForegroundColor Green
    Write-Host ""

    # Update gitignore to prevent re-adding
    Write-Host "[INFO] Updating .gitignore..." -ForegroundColor Yellow
    $gitignoreAdditions = @"

# Project-specific files (exclude from public repo)
analysis-*-brand2boost.md
tools/backup-brand2boost.ps1
tools/*database*.py
tools/ssh-*.py
tools/*-vps*.ps1
tools/upload-config.py
tools/create-project-kb.ps1
"@

    if ($DryRun) {
        Write-Host "[DRY RUN] Would add to .gitignore:" -ForegroundColor Magenta
        Write-Host $gitignoreAdditions
    } else {
        Add-Content -Path ".gitignore" -Value $gitignoreAdditions
        Write-Host "[SUCCESS] Updated .gitignore" -ForegroundColor Green
    }
    Write-Host ""

    # Files to update (replace project references with generic examples)
    Write-Host "[INFO] Replacing project-specific references with generic examples..." -ForegroundColor Yellow

    # Skill files - replace with generic project names
    $skillFiles = Get-ChildItem -Path ".claude/skills" -Filter "*.md" -Recurse

    $replacements = @{
        "client-manager" = "myproject"
        "brand2boost" = "myapp"
        "hazina" = "myframework"
        "wreckingball" = "admin"
        "Th1s1sSp4rt4!" = "YourSecurePassword"
        "85.215.217.154" = "your-server-ip"
        "3WsXcFr`$7YhNmKi\*" = "YourServerPassword"
        "C:/Projects/client-manager" = "C:/Projects/myproject"
        "C:/Projects/hazina" = "C:/Projects/myframework"
        "C:\\Projects\\client-manager" = "C:\\Projects\\myproject"
        "C:\\Projects\\hazina" = "C:\\Projects\\myframework"
        "martiendejong" = "yourname"
    }

    $updatedCount = 0
    foreach ($file in $skillFiles) {
        $content = Get-Content $file.FullName -Raw
        $originalContent = $content

        foreach ($key in $replacements.Keys) {
            $content = $content -replace [regex]::Escape($key), $replacements[$key]
        }

        if ($content -ne $originalContent) {
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would update: $($file.FullName)" -ForegroundColor Magenta
            } else {
                Set-Content -Path $file.FullName -Value $content -NoNewline
                Write-Host "  Updated: $($file.Name)" -ForegroundColor Yellow
                $updatedCount++
            }
        }
    }

    # Update other markdown files
    $mdFiles = Get-ChildItem -Path "." -Filter "*.md" -File | Where-Object { $_.Name -notlike "analysis-*" }
    foreach ($file in $mdFiles) {
        $content = Get-Content $file.FullName -Raw
        $originalContent = $content

        foreach ($key in $replacements.Keys) {
            $content = $content -replace [regex]::Escape($key), $replacements[$key]
        }

        if ($content -ne $originalContent) {
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would update: $($file.Name)" -ForegroundColor Magenta
            } else {
                Set-Content -Path $file.FullName -Value $content -NoNewline
                Write-Host "  Updated: $($file.Name)" -ForegroundColor Yellow
                $updatedCount++
            }
        }
    }

    Write-Host "[INFO] Updated $updatedCount files" -ForegroundColor Green
    Write-Host ""

    if ($DryRun) {
        Write-Host "[DRY RUN] No changes made. Run without -DryRun to apply changes." -ForegroundColor Magenta
    } else {
        Write-Host "[SUCCESS] Cleanup complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "[INFO] Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Review changes: git status" -ForegroundColor White
        Write-Host "  2. Commit: git add -A && git commit -m 'chore: Remove personal/project references'" -ForegroundColor White
        Write-Host "  3. Push: git push origin master" -ForegroundColor White
    }

} finally {
    Pop-Location
}
