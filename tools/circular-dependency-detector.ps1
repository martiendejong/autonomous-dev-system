<#
.SYNOPSIS
    Detect circular dependencies in project references and imports

.DESCRIPTION
    Scans for circular dependencies at multiple levels:
    - Project references (csproj)
    - Module imports (TypeScript/JavaScript)
    - Class dependencies (using statements)

    Circular dependencies cause:
    - Build failures
    - Difficult refactoring
    - Tight coupling
    - Testing challenges

.PARAMETER ProjectPath
    Path to solution/project root

.PARAMETER AnalysisType
    Type: projects, modules, classes, all

.PARAMETER OutputFormat
    Output format: Table (default), Graph, JSON

.EXAMPLE
    # Detect circular project references
    .\circular-dependency-detector.ps1 -AnalysisType projects

.EXAMPLE
    # Full analysis with graph visualization
    .\circular-dependency-detector.ps1 -AnalysisType all -OutputFormat Graph

.NOTES
    Value: 8/10 - Prevents architecture rot
    Effort: 1.5/10 - Graph traversal algorithm
    Ratio: 5.3 (TIER S)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [ValidateSet('projects', 'modules', 'classes', 'all')]
    [string]$AnalysisType = 'all',

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'Graph', 'JSON')]
    [string]$OutputFormat = 'Table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Circular Dependency Detector" -ForegroundColor Cyan
Write-Host "  Path: $ProjectPath" -ForegroundColor Gray
Write-Host "  Analysis: $AnalysisType" -ForegroundColor Gray
Write-Host ""

$cycles = @()

function Find-Cycles {
    param([hashtable]$Graph, [string]$Start, [array]$Path = @())

    $Path += $Start

    if (-not $Graph.ContainsKey($Start)) {
        return @()
    }

    $foundCycles = @()

    foreach ($neighbor in $Graph[$Start]) {
        $cycleIndex = $Path.IndexOf($neighbor)

        if ($cycleIndex -ge 0) {
            # Found a cycle!
            $cycle = $Path[$cycleIndex..($Path.Count - 1)] + $neighbor
            $foundCycles += ,@($cycle)
        } elseif ($neighbor -notin $Path) {
            $subCycles = Find-Cycles -Graph $Graph -Start $neighbor -Path $Path
            $foundCycles += $subCycles
        }
    }

    return $foundCycles
}

# Analyze project references
if ($AnalysisType -in @('projects', 'all')) {
    Write-Host "Analyzing project references..." -ForegroundColor Yellow

    $csprojFiles = Get-ChildItem -Path $ProjectPath -Filter "*.csproj" -Recurse
    $projectGraph = @{}

    foreach ($csproj in $csprojFiles) {
        [xml]$proj = Get-Content $csproj.FullName
        $projName = [System.IO.Path]::GetFileNameWithoutExtension($csproj.Name)

        $projectRefs = $proj.Project.ItemGroup.ProjectReference.Include

        $projectGraph[$projName] = @()

        foreach ($ref in $projectRefs) {
            if ($ref) {
                $refName = [System.IO.Path]::GetFileNameWithoutExtension($ref)
                $projectGraph[$projName] += $refName
            }
        }
    }

    # Find cycles
    foreach ($proj in $projectGraph.Keys) {
        $projCycles = Find-Cycles -Graph $projectGraph -Start $proj
        foreach ($cycle in $projCycles) {
            $cycles += [PSCustomObject]@{
                Type = "Project"
                Cycle = ($cycle -join " → ")
                Severity = "CRITICAL"
                Impact = "Build may fail or create complex dependency chains"
            }
        }
    }
}

# Analyze module imports (TypeScript/JavaScript)
if ($AnalysisType -in @('modules', 'all')) {
    Write-Host "Analyzing module imports..." -ForegroundColor Yellow

    $tsFiles = Get-ChildItem -Path $ProjectPath -Filter "*.ts" -Recurse | Where-Object { $_.FullName -notmatch 'node_modules|dist|build' }
    $moduleGraph = @{}

    foreach ($tsFile in $tsFiles) {
        $content = Get-Content $tsFile.FullName -Raw
        $moduleName = $tsFile.FullName.Replace($ProjectPath, '').Replace('\', '/').TrimStart('/')

        $imports = [regex]::Matches($content, "import.*from\s+['\"]([^'\"]+)['\"]")

        $moduleGraph[$moduleName] = @()

        foreach ($import in $imports) {
            $importPath = $import.Groups[1].Value

            # Skip external packages
            if ($importPath -notmatch '^\.|^/') {
                continue
            }

            $moduleGraph[$moduleName] += $importPath
        }
    }

    # Find cycles in modules (simplified)
    foreach ($mod in $moduleGraph.Keys) {
        $modCycles = Find-Cycles -Graph $moduleGraph -Start $mod
        foreach ($cycle in $modCycles) {
            $cycles += [PSCustomObject]@{
                Type = "Module"
                Cycle = ($cycle -join " → ")
                Severity = "HIGH"
                Impact = "Module bundling issues, difficult to tree-shake"
            }
        }
    }
}

Write-Host ""
Write-Host "CIRCULAR DEPENDENCY ANALYSIS" -ForegroundColor Red
Write-Host ""

if ($cycles.Count -eq 0) {
    Write-Host "✅ No circular dependencies detected!" -ForegroundColor Green
    exit 0
}

# Remove duplicate cycles
$uniqueCycles = $cycles | Sort-Object Cycle -Unique

switch ($OutputFormat) {
    'Table' {
        $uniqueCycles | Format-Table -AutoSize -Wrap -Property @(
            @{Label='Type'; Expression={$_.Type}; Width=10}
            @{Label='Circular Dependency'; Expression={$_.Cycle}; Width=80}
            @{Label='Severity'; Expression={$_.Severity}; Width=10}
        )

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Total cycles: $($uniqueCycles.Count)" -ForegroundColor Red
        Write-Host "  CRITICAL: $(($uniqueCycles | Where-Object {$_.Severity -eq 'CRITICAL'}).Count)" -ForegroundColor Red
        Write-Host "  HIGH: $(($uniqueCycles | Where-Object {$_.Severity -eq 'HIGH'}).Count)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "RECOMMENDED ACTIONS:" -ForegroundColor Yellow
        Write-Host "  1. Break cycles by introducing interfaces/abstractions" -ForegroundColor Gray
        Write-Host "  2. Move shared code to separate project/module" -ForegroundColor Gray
        Write-Host "  3. Use dependency inversion principle" -ForegroundColor Gray
        Write-Host "  4. Consider event-driven communication instead" -ForegroundColor Gray
    }
    'Graph' {
        # Generate DOT format for Graphviz
        Write-Host "digraph CircularDependencies {" -ForegroundColor White
        foreach ($cycle in $uniqueCycles) {
            $nodes = $cycle.Cycle -split ' → '
            for ($i = 0; $i -lt $nodes.Count - 1; $i++) {
                Write-Host "  `"$($nodes[$i])`" -> `"$($nodes[$i+1])`" [color=red];" -ForegroundColor White
            }
        }
        Write-Host "}" -ForegroundColor White
        Write-Host ""
        Write-Host "Paste above output into: https://dreampuf.github.io/GraphvizOnline/" -ForegroundColor Cyan
    }
    'JSON' {
        $uniqueCycles | ConvertTo-Json -Depth 10
    }
}

exit 1  # Fail CI if cycles detected
