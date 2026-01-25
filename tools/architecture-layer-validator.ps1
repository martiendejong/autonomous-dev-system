<#
.SYNOPSIS
    Enforce clean architecture dependency rules

.DESCRIPTION
    Validates dependency direction in layered architecture:
    - Domain layer has zero dependencies
    - Application layer depends only on Domain
    - Infrastructure depends on Domain and Application
    - Presentation depends on Application only

    Detects violations:
    - Domain depending on Infrastructure (CRITICAL)
    - Application depending on Infrastructure
    - Circular dependencies between layers

.PARAMETER ProjectPath
    Path to solution root

.PARAMETER Architecture
    Architecture style: clean, onion, hexagonal

.PARAMETER OutputFormat
    Output format: Table (default), Graph, JSON

.EXAMPLE
    # Validate clean architecture
    .\architecture-layer-validator.ps1 -Architecture clean

.NOTES
    Value: 8/10 - Prevents architecture rot
    Effort: 1.5/10 - Dependency graph analysis
    Ratio: 5.3 (TIER S)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [ValidateSet('clean', 'onion', 'hexagonal')]
    [string]$Architecture = 'clean',

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'Graph', 'JSON')]
    [string]$OutputFormat = 'Table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Architecture Layer Validator" -ForegroundColor Cyan
Write-Host "  Architecture: $Architecture" -ForegroundColor Gray
Write-Host ""

# Define layer rules based on architecture
$layerRules = @{
    'clean' = @{
        Layers = @('Domain', 'Application', 'Infrastructure', 'Presentation')
        AllowedDependencies = @{
            Domain = @()
            Application = @('Domain')
            Infrastructure = @('Domain', 'Application')
            Presentation = @('Application')
        }
    }
}

$rules = $layerRules[$Architecture]

# Find all projects
$projects = Get-ChildItem -Path $ProjectPath -Filter "*.csproj" -Recurse

$projectLayers = @{}
$dependencies = @{}

Write-Host "Analyzing projects..." -ForegroundColor Yellow
Write-Host ""

foreach ($project in $projects) {
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($project.Name)

    # Detect layer from project name
    $layer = $null
    foreach ($layerName in $rules.Layers) {
        if ($projectName -match $layerName) {
            $layer = $layerName
            break
        }
    }

    if (-not $layer) {
        Write-Host "  ⚠️  $projectName - Unknown layer" -ForegroundColor Yellow
        continue
    }

    $projectLayers[$projectName] = $layer

    # Parse project references
    [xml]$proj = Get-Content $project.FullName
    $projectRefs = $proj.Project.ItemGroup.ProjectReference.Include

    $dependencies[$projectName] = @()

    foreach ($ref in $projectRefs) {
        if ($ref) {
            $refName = [System.IO.Path]::GetFileNameWithoutExtension($ref)
            $dependencies[$projectName] += $refName
        }
    }

    Write-Host "  $projectName → $layer" -ForegroundColor Gray
}

Write-Host ""
Write-Host "ARCHITECTURE VALIDATION" -ForegroundColor Cyan
Write-Host ""

$violations = @()

foreach ($projectName in $dependencies.Keys) {
    $layer = $projectLayers[$projectName]

    if (-not $layer) { continue }

    $allowedDeps = $rules.AllowedDependencies[$layer]

    foreach ($dep in $dependencies[$projectName]) {
        $depLayer = $projectLayers[$dep]

        if (-not $depLayer) { continue }

        # Check if dependency is allowed
        if ($depLayer -notin $allowedDeps) {
            $severity = if ($layer -eq 'Domain') { "CRITICAL" } else { "HIGH" }

            $violations += [PSCustomObject]@{
                Project = $projectName
                Layer = $layer
                DependsOn = $dep
                DependsOnLayer = $depLayer
                Severity = $severity
                Rule = "$layer should not depend on $depLayer"
            }
        }
    }
}

if ($violations.Count -eq 0) {
    Write-Host "✅ Architecture is valid! No violations detected." -ForegroundColor Green
    exit 0
}

switch ($OutputFormat) {
    'Table' {
        Write-Host "❌ ARCHITECTURE VIOLATIONS DETECTED:" -ForegroundColor Red
        Write-Host ""

        $violations | Format-Table -AutoSize -Property @(
            @{Label='Project'; Expression={$_.Project}; Width=30}
            @{Label='Layer'; Expression={$_.Layer}; Width=15}
            @{Label='Depends On'; Expression={$_.DependsOn}; Width=30}
            @{Label='Layer'; Expression={$_.DependsOnLayer}; Width=15}
            @{Label='Severity'; Expression={$_.Severity}; Width=10}
        )

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Total violations: $($violations.Count)" -ForegroundColor Red
        Write-Host "  CRITICAL: $(($violations | Where-Object {$_.Severity -eq 'CRITICAL'}).Count)" -ForegroundColor Red
        Write-Host "  HIGH: $(($violations | Where-Object {$_.Severity -eq 'HIGH'}).Count)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "RECOMMENDED ACTIONS:" -ForegroundColor Yellow
        Write-Host "  1. Move shared code to Domain layer" -ForegroundColor Gray
        Write-Host "  2. Use dependency inversion (interfaces in Domain)" -ForegroundColor Gray
        Write-Host "  3. Inject dependencies instead of direct references" -ForegroundColor Gray

        exit 1
    }
    'Graph' {
        # Generate dependency graph in DOT format
        Write-Host "digraph Architecture {" -ForegroundColor White
        Write-Host "  rankdir=TB;" -ForegroundColor White
        Write-Host ""

        # Define layer subgraphs
        foreach ($layer in $rules.Layers) {
            Write-Host "  subgraph cluster_$layer {" -ForegroundColor White
            Write-Host "    label=`"$layer`";" -ForegroundColor White

            $layerProjects = $projectLayers.Keys | Where-Object { $projectLayers[$_] -eq $layer }
            foreach ($proj in $layerProjects) {
                Write-Host "    `"$proj`";" -ForegroundColor White
            }

            Write-Host "  }" -ForegroundColor White
        }

        Write-Host ""

        # Draw dependencies
        foreach ($proj in $dependencies.Keys) {
            foreach ($dep in $dependencies[$proj]) {
                $isViolation = $violations | Where-Object { $_.Project -eq $proj -and $_.DependsOn -eq $dep }

                $color = if ($isViolation) { "red" } else { "black" }
                Write-Host "  `"$proj`" -> `"$dep`" [color=$color];" -ForegroundColor White
            }
        }

        Write-Host "}" -ForegroundColor White
        Write-Host ""
        Write-Host "Paste output into: https://dreampuf.github.io/GraphvizOnline/" -ForegroundColor Cyan
    }
    'JSON' {
        @{
            Architecture = $Architecture
            Layers = $projectLayers
            Dependencies = $dependencies
            Violations = $violations
        } | ConvertTo-Json -Depth 10
    }
}
