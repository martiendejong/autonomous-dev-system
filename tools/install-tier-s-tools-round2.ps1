# Install All Tier S CLI Tools - Round 2 (Tools 101-119)
# Generated: 2026-01-25
# CORRECTED: 19 tools, ~1.35 MB (ollama removed - 1-7 GB per model)
# User has limited disk space - extreme caution with large tools


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "CLI Tools Installation - Round 2" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
$prerequisites = @{
    "cargo" = "Rustlang.Rustup"
    "go" = "GoLang.Go"
    "choco" = "Chocolatey.Chocolatey"
    "npm" = "OpenJS.NodeJS"
}

Write-Host "Checking prerequisites..." -ForegroundColor Yellow
$missingPrereqs = @()

foreach ($cmd in $prerequisites.Keys) {
    if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "  ✗ $cmd not found" -ForegroundColor Red
        $missingPrereqs += $prerequisites[$cmd]
    } else {
        Write-Host "  ✓ $cmd found" -ForegroundColor Green
    }
}

if ($missingPrereqs.Count -gt 0) {
    Write-Host "`n⚠ Missing prerequisites. Installing..." -ForegroundColor Yellow
    foreach ($pkg in $missingPrereqs) {
        Write-Host "  Installing $pkg..." -ForegroundColor Yellow
        winget install $pkg --silent --accept-source-agreements --accept-package-agreements
    }
    Write-Host "`n✓ Prerequisites installed. Please restart terminal and run this script again." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "⚠️  DISK SPACE NOTICE:" -ForegroundColor Yellow
Write-Host "    Ollama NOT included (1-7 GB per model)" -ForegroundColor Gray
Write-Host "    Use aichat + OpenAI API instead (0 disk space)" -ForegroundColor Gray
Write-Host ""
Write-Host "Installing Tier S Round 2 Tools (19 tools, ~1.35 MB total)..." -ForegroundColor Cyan
Write-Host ""

$installed = 0
$failed = 0
$skipped = 0

# Tier S Tools Round 2 (101-120)
$tools = @(
    @{Name="ack"; Command="winget install beyondgrep.ack --silent"; Check="ack --version"},
    @{Name="ag"; Command="winget install geoff-nixon.ag --silent"; Check="ag --version"},
    @{Name="parallel"; Command="choco install parallel -y"; Check="parallel --version"},
    @{Name="entr"; Command="choco install entr -y"; Check="entr --version"}, @{Name="direnv"; Command="choco install direnv -y"; Check="direnv version"},
    @{Name="z"; Command="choco install z -y"; Check="z --help"},
    @{Name="fcp"; Command="cargo install fcp"; Check="fcp --version"},
    @{Name="rmtrash"; Command="cargo install rmtrash"; Check="rmtrash --version"},
    @{Name="fx"; Command="npm install -g fx"; Check="fx --version"},
    @{Name="jo"; Command="choco install jo -y"; Check="jo --version"},
    @{Name="miller"; Command="choco install miller -y"; Check="mlr --version"},
    @{Name="dasel"; Command="go install github.com/tomwright/dasel/v2/cmd/dasel@latest"; Check="dasel --version"},
    @{Name="gron"; Command="go install github.com/tomnomnom/gron@latest"; Check="gron --version"},
    @{Name="jid"; Command="go install github.com/simeji/jid/cmd/jid@latest"; Check="jid --version"},
    @{Name="ccat"; Command="go install github.com/owenthereal/ccat@latest"; Check="ccat --version"},
    @{Name="diffsitter"; Command="cargo install diffsitter"; Check="diffsitter --version"},
    @{Name="noti"; Command="go install github.com/variadico/noti/cmd/noti@latest"; Check="noti --version"},
    @{Name="pv"; Command="choco install pv -y"; Check="pv --version"},
    @{Name="cloc"; Command="winget install AlDanial.Cloc --silent"; Check="cloc --version"}
)

foreach ($tool in $tools) {
    Write-Host "[$($installed + $failed + $skipped + 1)/$($tools.Count)] Installing $($tool.Name)..." -ForegroundColor Yellow

    # Check if already installed
    $checkResult = Invoke-Expression $tool.Check -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -eq 0 -or $checkResult) {
        Write-Host "  ✓ Already installed, skipping" -ForegroundColor Green
        $skipped++
        continue
    }

    # Install
    try {
        Write-Host "  Installing..." -ForegroundColor Gray
        $output = Invoke-Expression $tool.Command

        # Verify installation
        Start-Sleep -Seconds 1
        $verifyResult = Invoke-Expression $tool.Check -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -eq 0 -or $verifyResult) {
            Write-Host "  ✓ Installed successfully" -ForegroundColor Green
            $installed++
        } else {
            Write-Host "  ✗ Installation verification failed" -ForegroundColor Red
            $failed++
        }
    } catch {
        Write-Host "  ✗ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "`n⚠ Some installations failed. Common issues:" -ForegroundColor Yellow
    Write-Host "  - Check internet connection" -ForegroundColor Gray
    Write-Host "  - Run as Administrator if needed" -ForegroundColor Gray
    Write-Host "  - Ensure prerequisites are in PATH" -ForegroundColor Gray
}

# Highlight top tools
if ($installed -gt 0 -or $skipped -gt 0) {
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Try These First" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan

    Write-Host "`n1. Interactive JSON viewer (fx):" -ForegroundColor Yellow
    Write-Host "   fx appsettings.json" -ForegroundColor White

    Write-Host "`n2. Parallel job execution (parallel):" -ForegroundColor Yellow
    Write-Host "   parallel dotnet test ::: **/*.Tests.csproj" -ForegroundColor White

    Write-Host "`n3. CSV/JSON data processing (miller):" -ForegroundColor Yellow
    Write-Host "   mlr --csv sort -f age data.csv" -ForegroundColor White

    Write-Host "`n4. Find leaked secrets (check your repos!):" -ForegroundColor Yellow
    Write-Host "   # Will be in Tier A (ripsecrets)" -ForegroundColor Gray

    Write-Host "`n5. Update all tools at once:" -ForegroundColor Yellow
    Write-Host "   # Will be in Tier A (topgrade)" -ForegroundColor Gray
}

Write-Host "`n"
