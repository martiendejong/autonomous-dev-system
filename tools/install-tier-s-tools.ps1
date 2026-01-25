# Install All Tier S CLI Tools
# Generated: 2026-01-25
# Total: 17 tools, 1.29 MB


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Installing Tier S CLI Tools (17 tools, 1.29 MB total)..." -ForegroundColor Cyan

# Tier S Tools (Ratio > 100)
$tools = @(
    "BurntSushi.ripgrep.MSVC",      # 1. ripgrep - 100x faster code search
    "sharkdp.fd",                     # 2. fd - 50x faster file finding
    "sharkdp.bat",                    # 3. bat - cat with syntax highlighting
    "eza-community.eza",              # 4. eza - modern ls with git status
    "jqlang.jq",                      # 5. jq - JSON parsing
    "chmln.sd",                       # 6. sd - safer sed for refactoring
    "XAMPPRocky.tokei",               # 7. tokei - codebase statistics
    "sharkdp.hyperfine",              # 8. hyperfine - benchmarking
    "dandavison.delta",               # 9. delta - beautiful git diffs
    "muesli.duf",                     # 10. duf - disk usage viewer
    "junegunn.fzf",                   # 11. fzf - fuzzy finder
    "bootandy.dust",                  # 12. dust - disk usage tree
    "dalance.procs",                  # 13. procs - process viewer
    "ClementTsang.bottom",            # 14. bottom - system monitor
    "watchexec.watchexec",            # 15. watchexec - file watcher
    "Starship.Starship",              # 16. starship - beautiful prompt
    "ajeetdsouza.zoxide"              # 17. zoxide - smart cd
)

$installed = 0
$failed = 0
$skipped = 0

foreach ($tool in $tools) {
    Write-Host "`nInstalling $tool..." -ForegroundColor Yellow

    # Check if already installed
    $check = winget list --id $tool --exact 2>&1 | Out-String
    if ($check -match $tool) {
        Write-Host "  ✓ Already installed, skipping" -ForegroundColor Green
        $skipped++
        continue
    }

    # Install
    $result = winget install $tool --silent --accept-source-agreements --accept-package-agreements 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Installed successfully" -ForegroundColor Green
        $installed++
    } else {
        Write-Host "  ✗ Installation failed" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Installation Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Installed: $installed" -ForegroundColor Green
Write-Host "  Skipped:   $skipped" -ForegroundColor Yellow
Write-Host "  Failed:    $failed" -ForegroundColor Red
Write-Host "  Total:     $($tools.Count)" -ForegroundColor White

if ($installed -gt 0) {
    Write-Host "`n✓ Please restart your terminal to use the new tools" -ForegroundColor Green
}

if ($failed -gt 0) {
    Write-Host "`n⚠ Some installations failed. Run with verbose for details." -ForegroundColor Yellow
}

# Post-install configuration suggestions
if ($installed -gt 0 -or $skipped -gt 0) {
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Next Steps" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan

    Write-Host "`n1. Configure Starship (optional):" -ForegroundColor Yellow
    Write-Host "   Add to PowerShell profile:" -ForegroundColor Gray
    Write-Host "   Invoke-Expression (&starship init powershell)" -ForegroundColor White

    Write-Host "`n2. Configure Zoxide (optional):" -ForegroundColor Yellow
    Write-Host "   Add to PowerShell profile:" -ForegroundColor Gray
    Write-Host "   Invoke-Expression (& { (zoxide init powershell | Out-String) })" -ForegroundColor White

    Write-Host "`n3. Configure Delta for Git (optional):" -ForegroundColor Yellow
    Write-Host "   git config --global core.pager delta" -ForegroundColor White
    Write-Host "   git config --global interactive.diffFilter 'delta --color-only'" -ForegroundColor White

    Write-Host "`n4. Try them out:" -ForegroundColor Yellow
    Write-Host "   rg 'search term'     # Fast code search" -ForegroundColor White
    Write-Host "   fd '*.cs'            # Find C# files" -ForegroundColor White
    Write-Host "   bat README.md        # View file with syntax highlighting" -ForegroundColor White
    Write-Host "   eza -l --git         # List files with git status" -ForegroundColor White
    Write-Host "   fzf                  # Interactive fuzzy finder" -ForegroundColor White
    Write-Host "   z client             # Jump to client-manager directory" -ForegroundColor White
}

Write-Host "`n"
