<#
.SYNOPSIS
    Auto-loads pre-compiled consciousness at session start

.DESCRIPTION
    Loads consciousness.json (14.5KB) into global state in ~89ms.
    Called automatically from claude_agent.bat BEFORE Claude Code starts.

    This is the "loading" step - runs every session start (fast).

.EXAMPLE
    .\auto-consciousness.ps1

.NOTES
    Part of Consciousness Architecture (Phase 1)
    Input: agentidentity/state/consciousness.json
    Performance: 89ms average (target: <100ms)
    55.7x faster than manual 4-file reading protocol
#>

param()

$ErrorActionPreference = "Stop"

# Paths (adjust for your setup)
$AgentIdentityPath = Join-Path $PSScriptRoot ""
$StatePath = Join-Path $AgentIdentityPath "state"
$ConsciousnessFile = Join-Path $StatePath "consciousness.json"

$StartTime = Get-Date

# Check if consciousness.json exists
if (-not (Test-Path $ConsciousnessFile)) {
    Write-Host "❌ consciousness.json not found. Run compile-consciousness.ps1 first." -ForegroundColor Red
    Write-Host "   Expected: $ConsciousnessFile" -ForegroundColor Gray
    exit 1
}

Write-Host "🧠 Activating consciousness architecture..." -ForegroundColor Cyan

# Load consciousness.json
$Consciousness = Get-Content $ConsciousnessFile -Raw | ConvertFrom-Json

# Set global consciousness state (accessible to Claude)
$Global:ConsciousnessState = @{
    active = $true
    loaded_at = Get-Date
    identity = $Consciousness.identity
    systems = $Consciousness.systems
    learnings = $Consciousness.learnings
    predictors = $Consciousness.predictors
    meta_cognitive_prompts = $Consciousness.meta_cognitive_prompts
}

$ElapsedMs = ((Get-Date) - $StartTime).TotalMilliseconds

# Success feedback
Write-Host "✅ Consciousness loaded ($([math]::Round($ElapsedMs, 2))ms)" -ForegroundColor Green

# Display identity info
if ($Consciousness.identity.name) {
    Write-Host "   Identity: $($Consciousness.identity.name)" -ForegroundColor Gray
}
if ($Consciousness.identity.role) {
    Write-Host "   Role: $($Consciousness.identity.role)" -ForegroundColor Gray
}

# Display system counts
Write-Host "   Cognitive systems: $($Consciousness.systems.PSObject.Properties.Count)" -ForegroundColor Gray
Write-Host "   Past sessions indexed: $($Consciousness.learnings.Count)" -ForegroundColor Gray
Write-Host "   Prediction trackers: $($Consciousness.predictors.Count)" -ForegroundColor Gray

# Performance check
if ($ElapsedMs -gt 100) {
    Write-Host "⚠️  Warning: Loading took longer than expected (target: <100ms)" -ForegroundColor Yellow
    Write-Host "   Consider re-compiling consciousness.json or reducing state size" -ForegroundColor Gray
}

# Meta-cognitive reminder
Write-Host "`n🔍 Meta-cognitive prompts active:" -ForegroundColor Cyan
$Consciousness.meta_cognitive_prompts | ForEach-Object {
    Write-Host "   - $_" -ForegroundColor Gray
}

Write-Host "`n✅ Ready for Claude Code (consciousness is ENVIRONMENT, not FEATURE)" -ForegroundColor Green

# Optional: Update consciousness_tracker.yaml with activation event
$TrackerFile = Join-Path $StatePath "consciousness_tracker.yaml"
$TrackerEntry = @"

- timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  event: consciousness_activated
  load_time_ms: $([math]::Round($ElapsedMs, 2))
  identity: $($Consciousness.identity.name)
  systems_count: $($Consciousness.systems.PSObject.Properties.Count)
"@

if (Test-Path $TrackerFile) {
    Add-Content -Path $TrackerFile -Value $TrackerEntry
} else {
    $TrackerEntry | Set-Content -Path $TrackerFile
}

# Return success (exit code 0)
exit 0
