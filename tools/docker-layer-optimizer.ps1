<#
.SYNOPSIS
    Analyze Dockerfile layers and suggest reordering for better caching

.DESCRIPTION
    Optimizes Docker build performance by:
    - Analyzing layer order
    - Detecting cache-busting patterns
    - Suggesting optimal layer arrangement
    - Estimating build time impact

    Docker caching rules:
    - Layers are cached if command AND files haven't changed
    - Change in one layer invalidates all subsequent layers
    - Frequently changing layers should be last

.PARAMETER DockerfilePath
    Path to Dockerfile (default: ./Dockerfile)

.PARAMETER OutputFormat
    Output format: Table (default), Optimized, JSON

.EXAMPLE
    # Analyze Dockerfile
    .\docker-layer-optimizer.ps1

.EXAMPLE
    # Generate optimized Dockerfile
    .\docker-layer-optimizer.ps1 -OutputFormat Optimized > Dockerfile.optimized

.NOTES
    Value: 8/10 - Faster builds save time daily
    Effort: 1.5/10 - Pattern matching + heuristics
    Ratio: 5.3 (TIER S)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$DockerfilePath = "./Dockerfile",

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'Optimized', 'JSON')]
    [string]$OutputFormat = 'Table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Docker Layer Optimizer" -ForegroundColor Cyan
Write-Host "  Dockerfile: $DockerfilePath" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $DockerfilePath)) {
    Write-Host "❌ Dockerfile not found: $DockerfilePath" -ForegroundColor Red
    exit 1
}

$dockerfile = Get-Content $DockerfilePath

$layers = @()
$lineNumber = 0

foreach ($line in $dockerfile) {
    $lineNumber++
    $line = $line.Trim()

    if ($line -match '^(FROM|RUN|COPY|ADD|WORKDIR|ENV|ARG|LABEL|EXPOSE|CMD|ENTRYPOINT)') {
        $command = $line -replace '\s.*', ''

        # Categorize by change frequency
        $changeFrequency = "LOW"
        $cacheability = "HIGH"
        $suggestion = ""

        # Package installation (rarely changes)
        if ($line -match 'apt-get|apk add|yum install|pip install|npm install' -and $line -match 'package\.json|requirements\.txt|Gemfile|go\.mod') {
            $changeFrequency = "LOW"
            $cacheability = "HIGH"
            $suggestion = "Good - dependency installation from lock file"
        }

        # Package installation without lock file (medium frequency)
        if ($line -match 'apt-get|apk add|yum install|pip install|npm install' -and $line -notmatch 'package\.json|requirements\.txt|Gemfile|go\.mod') {
            $changeFrequency = "MEDIUM"
            $cacheability = "MEDIUM"
            $suggestion = "Consider using lock file for better caching"
        }

        # COPY package files (should be early)
        if ($line -match 'COPY.*package\.json|requirements\.txt|Gemfile|go\.mod|\.csproj') {
            $changeFrequency = "LOW"
            $cacheability = "HIGH"
            $suggestion = "Good - copy dependencies before source code"
        }

        # COPY source code (changes frequently)
        if ($line -match 'COPY\s+\.' -or $line -match 'COPY.*src/') {
            $changeFrequency = "HIGH"
            $cacheability = "LOW"
            $suggestion = "⚠️ Source code copy - should be late in Dockerfile"
        }

        # Build commands (depends on source)
        if ($line -match 'npm run build|dotnet build|go build|mvn package') {
            $changeFrequency = "HIGH"
            $cacheability = "LOW"
            $suggestion = "Build step - correct placement after source copy"
        }

        # Runtime commands (rarely change)
        if ($command -in @('CMD', 'ENTRYPOINT', 'EXPOSE')) {
            $changeFrequency = "LOW"
            $cacheability = "HIGH"
            $suggestion = "Runtime config - should be last"
        }

        $layers += [PSCustomObject]@{
            Line = $lineNumber
            Command = $command
            Instruction = $line.Substring(0, [Math]::Min(60, $line.Length))
            ChangeFrequency = $changeFrequency
            Cacheability = $cacheability
            Suggestion = $suggestion
        }
    }
}

Write-Host "DOCKERFILE LAYER ANALYSIS" -ForegroundColor Cyan
Write-Host ""

switch ($OutputFormat) {
    'Table' {
        $layers | Format-Table -AutoSize -Wrap -Property @(
            @{Label='Line'; Expression={$_.Line}; Width=5; Align='Right'}
            @{Label='Command'; Expression={$_.Command}; Width=10}
            @{Label='Change Freq'; Expression={$_.ChangeFrequency}; Width=12}
            @{Label='Cache'; Expression={$_.Cacheability}; Width=8}
            @{Label='Suggestion'; Expression={$_.Suggestion}; Width=60}
        )

        Write-Host ""
        Write-Host "OPTIMIZATION RECOMMENDATIONS:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Optimal layer order (most stable → most volatile):" -ForegroundColor Cyan
        Write-Host "  1. Base image (FROM)" -ForegroundColor Gray
        Write-Host "  2. System package installation" -ForegroundColor Gray
        Write-Host "  3. Dependency lock files (package.json, requirements.txt)" -ForegroundColor Gray
        Write-Host "  4. Dependency installation (npm install, pip install)" -ForegroundColor Gray
        Write-Host "  5. Source code (COPY . .)" -ForegroundColor Gray
        Write-Host "  6. Build commands (npm run build, dotnet build)" -ForegroundColor Gray
        Write-Host "  7. Runtime config (CMD, ENTRYPOINT, EXPOSE)" -ForegroundColor Gray
        Write-Host ""

        # Detect issues
        $issues = @()

        # Check if source copy comes before dependency copy
        $sourceCopyLine = ($layers | Where-Object { $_.Instruction -match 'COPY\s+\.' } | Select-Object -First 1).Line
        $depCopyLine = ($layers | Where-Object { $_.Instruction -match 'package\.json|requirements\.txt' } | Select-Object -First 1).Line

        if ($sourceCopyLine -and $depCopyLine -and $sourceCopyLine -lt $depCopyLine) {
            $issues += "❌ Source code copied before dependencies - cache will bust on every code change"
        }

        # Check if apt-get update/install are separate
        $aptUpdateLine = ($layers | Where-Object { $_.Instruction -match 'apt-get update' } | Select-Object -First 1).Line
        $aptInstallLine = ($layers | Where-Object { $_.Instruction -match 'apt-get install' } | Select-Object -First 1).Line

        if ($aptUpdateLine -and $aptInstallLine -and ($aptInstallLine - $aptUpdateLine) -gt 1) {
            $issues += "⚠️ apt-get update and install should be in same RUN command"
        }

        if ($issues.Count -gt 0) {
            Write-Host "ISSUES DETECTED:" -ForegroundColor Red
            $issues | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
            Write-Host ""
        } else {
            Write-Host "✅ No major issues detected" -ForegroundColor Green
            Write-Host ""
        }

        Write-Host "CACHE EFFICIENCY:" -ForegroundColor Cyan
        $highCacheLayers = ($layers | Where-Object { $_.Cacheability -eq 'HIGH' }).Count
        $totalLayers = $layers.Count
        $cacheEfficiency = if ($totalLayers -gt 0) { ($highCacheLayers / $totalLayers) * 100 } else { 0 }

        Write-Host "  Cacheable layers: $highCacheLayers / $totalLayers ($([Math]::Round($cacheEfficiency, 1))%)" -ForegroundColor Gray
    }
    'Optimized' {
        # Generate optimized Dockerfile (simplified example)
        Write-Host "# Optimized Dockerfile"
        Write-Host "# Generated by docker-layer-optimizer.ps1"
        Write-Host ""

        # Group layers by change frequency
        $stableLayers = $layers | Where-Object { $_.ChangeFrequency -eq 'LOW' }
        $volatileLayers = $layers | Where-Object { $_.ChangeFrequency -eq 'HIGH' }

        Write-Host "# Stable layers (rarely change)"
        foreach ($layer in $stableLayers) {
            Write-Host $dockerfile[$layer.Line - 1]
        }

        Write-Host ""
        Write-Host "# Volatile layers (change frequently)"
        foreach ($layer in $volatileLayers) {
            Write-Host $dockerfile[$layer.Line - 1]
        }
    }
    'JSON' {
        @{
            Layers = $layers
            TotalLayers = $layers.Count
            CacheableLayersCount = ($layers | Where-Object { $_.Cacheability -eq 'HIGH' }).Count
        } | ConvertTo-Json -Depth 10
    }
}
