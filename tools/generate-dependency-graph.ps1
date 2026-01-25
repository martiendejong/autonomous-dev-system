<#
.SYNOPSIS
    Generates interactive dependency graph for C# projects.

.DESCRIPTION
    Parses .csproj files to extract ProjectReference dependencies and generates
    an interactive visualization using Mermaid.js or D3.js.

    Supports:
    - Multi-repository analysis (Hazina + client-manager + other apps)
    - Circular dependency detection
    - Export to HTML, Mermaid, or JSON

.PARAMETER RootPath
    Root path to scan for .csproj files (default: C:\Projects)

.PARAMETER OutputFormat
    Output format: html, mermaid, json, or all (default: html)

.PARAMETER OutputFile
    Output file path (default: dependency-graph.html)

.PARAMETER IncludeNuGet
    Include NuGet package dependencies (warning: very large graph)

.PARAMETER MaxDepth
    Maximum dependency depth to traverse (default: 10)

.EXAMPLE
    .\generate-dependency-graph.ps1
    .\generate-dependency-graph.ps1 -RootPath "C:\Projects\hazina"
    .\generate-dependency-graph.ps1 -OutputFormat "mermaid" -OutputFile "graph.md"
#>

param(
    [string]$RootPath = "C:\Projects",
    [ValidateSet("html", "mermaid", "json", "all")

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
]
    [string]$OutputFormat = "html",
    [string]$OutputFile,
    [switch]$IncludeNuGet,
    [int]$MaxDepth = 10
)

function Find-CsProjFiles {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return @()
    }

    return Get-ChildItem $Path -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue
}

function Parse-ProjectReferences {
    param([string]$CsProjPath)

    [xml]$xml = Get-Content $CsProjPath

    $references = @()

    # ProjectReference
    $projectRefs = $xml.Project.ItemGroup.ProjectReference

    foreach ($ref in $projectRefs) {
        if ($ref.Include) {
            # Resolve relative path
            $refPath = Join-Path (Split-Path $CsProjPath) $ref.Include
            $refPath = [System.IO.Path]::GetFullPath($refPath)

            $references += @{
                "Type" = "Project"
                "Path" = $refPath
                "Name" = [System.IO.Path]::GetFileNameWithoutExtension($refPath)
            }
        }
    }

    # PackageReference (if requested)
    if ($IncludeNuGet) {
        $packageRefs = $xml.Project.ItemGroup.PackageReference

        foreach ($ref in $packageRefs) {
            if ($ref.Include) {
                $references += @{
                    "Type" = "Package"
                    "Name" = $ref.Include
                    "Version" = $ref.Version
                }
            }
        }
    }

    return $references
}

function Build-DependencyGraph {
    param([array]$Projects)

    $graph = @{}

    foreach ($project in $Projects) {
        $projectName = [System.IO.Path]::GetFileNameWithoutExtension($project.FullName)
        $references = Parse-ProjectReferences -CsProjPath $project.FullName

        $graph[$projectName] = @{
            "Path" = $project.FullName
            "Dependencies" = $references
            "Repository" = Get-RepositoryName -Path $project.FullName
        }
    }

    return $graph
}

function Get-RepositoryName {
    param([string]$Path)

    # Extract repo name from path (e.g., C:\Projects\hazina\... → hazina)
    if ($Path -match 'Projects\\([^\\]+)') {
        return $matches[1]
    }

    return "Unknown"
}

function Detect-CircularDependencies {
    param([hashtable]$Graph)

    $cycles = @()

    function Visit-Node {
        param([string]$Node, [array]$Visited, [array]$Path)

        if ($Path -contains $Node) {
            # Circular dependency detected
            $cycleStart = [array]::IndexOf($Path, $Node)
            $cycle = $Path[$cycleStart..($Path.Count - 1)] + @($Node)
            return @($cycle)
        }

        if ($Visited -contains $Node) {
            return @()
        }

        $newVisited = $Visited + @($Node)
        $newPath = $Path + @($Node)

        $foundCycles = @()

        if ($Graph.ContainsKey($Node)) {
            foreach ($dep in $Graph[$Node].Dependencies | Where-Object { $_.Type -eq "Project" }) {
                $depCycles = Visit-Node -Node $dep.Name -Visited $newVisited -Path $newPath
                $foundCycles += $depCycles
            }
        }

        return $foundCycles
    }

    foreach ($node in $Graph.Keys) {
        $nodeCycles = Visit-Node -Node $node -Visited @() -Path @()
        $cycles += $nodeCycles
    }

    return $cycles | Select-Object -Unique
}

function Generate-MermaidDiagram {
    param([hashtable]$Graph)

    $mermaid = "graph TD`n"

    # Define styles
    $mermaid += "  classDef hazina fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff`n"
    $mermaid += "  classDef clientManager fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff`n"
    $mermaid += "  classDef other fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff`n"
    $mermaid += "`n"

    # Add nodes
    foreach ($project in $Graph.Keys) {
        $nodeId = $project -replace '[^a-zA-Z0-9]', '_'
        $repo = $Graph[$project].Repository

        $class = switch ($repo) {
            "hazina" { "hazina" }
            "client-manager" { "clientManager" }
            default { "other" }
        }

        $mermaid += "  $nodeId[`"$project`"]:::$class`n"
    }

    $mermaid += "`n"

    # Add edges
    foreach ($project in $Graph.Keys) {
        $nodeId = $project -replace '[^a-zA-Z0-9]', '_'

        foreach ($dep in $Graph[$project].Dependencies | Where-Object { $_.Type -eq "Project" }) {
            $depId = $dep.Name -replace '[^a-zA-Z0-9]', '_'
            $mermaid += "  $nodeId --> $depId`n"
        }
    }

    return $mermaid
}

function Generate-HTMLVisualization {
    param([hashtable]$Graph, [string]$MermaidCode)

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dependency Graph</title>
    <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true, theme: 'default' });
    </script>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #4a9eff;
            padding-bottom: 10px;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        .stat-card {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 6px;
            border-left: 4px solid #4a9eff;
        }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #4a9eff;
        }
        .stat-label {
            color: #666;
            font-size: 0.9em;
        }
        .mermaid {
            background: white;
            padding: 20px;
            border-radius: 6px;
            margin: 20px 0;
        }
        .legend {
            display: flex;
            gap: 20px;
            margin: 20px 0;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 6px;
        }
        .legend-item {
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .legend-color {
            width: 20px;
            height: 20px;
            border-radius: 3px;
        }
        .warning {
            background: #fff3cd;
            border: 1px solid #ffc107;
            border-radius: 6px;
            padding: 15px;
            margin: 20px 0;
        }
        .warning h3 {
            margin-top: 0;
            color: #856404;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔗 Project Dependency Graph</h1>

        <div class="stats">
            <div class="stat-card">
                <div class="stat-value">$($Graph.Count)</div>
                <div class="stat-label">Total Projects</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$(($Graph.Values.Repository | Select-Object -Unique).Count)</div>
                <div class="stat-label">Repositories</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$(($Graph.Values.Dependencies | Where-Object { $_.Type -eq 'Project' }).Count)</div>
                <div class="stat-label">Dependencies</div>
            </div>
        </div>

        <div class="legend">
            <div class="legend-item">
                <div class="legend-color" style="background: #4a9eff;"></div>
                <span>Hazina Framework</span>
            </div>
            <div class="legend-item">
                <div class="legend-color" style="background: #ff6b6b;"></div>
                <span>Client Manager</span>
            </div>
            <div class="legend-item">
                <div class="legend-color" style="background: #51cf66;"></div>
                <span>Other Projects</span>
            </div>
        </div>

        <div class="mermaid">
$MermaidCode
        </div>

        <p style="color: #666; font-size: 0.9em; margin-top: 30px;">
            Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Tool: generate-dependency-graph.ps1
        </p>
    </div>
</body>
</html>
"@

    return $html
}

# Main execution
Write-Host ""
Write-Host "=== Dependency Graph Generator ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $RootPath)) {
    Write-Host "ERROR: Root path not found: $RootPath" -ForegroundColor Red
    exit 1
}

Write-Host "Scanning for .csproj files in: $RootPath" -ForegroundColor White
Write-Host ""

$projects = Find-CsProjFiles -Path $RootPath

if ($projects.Count -eq 0) {
    Write-Host "No .csproj files found" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($projects.Count) projects" -ForegroundColor Green
Write-Host ""

# Build dependency graph
Write-Host "Building dependency graph..." -ForegroundColor Cyan
$graph = Build-DependencyGraph -Projects $projects

# Detect circular dependencies
$cycles = Detect-CircularDependencies -Graph $graph

if ($cycles.Count -gt 0) {
    Write-Host ""
    Write-Host "=== WARNING: Circular Dependencies Detected ===" -ForegroundColor Red
    Write-Host ""
    foreach ($cycle in $cycles) {
        Write-Host ("  " + ($cycle -join ' -> ')) -ForegroundColor Yellow
    }
    Write-Host ""
}

# Generate Mermaid diagram
$mermaidCode = Generate-MermaidDiagram -Graph $graph

# Output based on format
$defaultOutputFile = if ($OutputFile) { $OutputFile } else {
    switch ($OutputFormat) {
        "html" { "dependency-graph.html" }
        "mermaid" { "dependency-graph.md" }
        "json" { "dependency-graph.json" }
        "all" { "dependency-graph" }
    }
}

switch ($OutputFormat) {
    "html" {
        $html = Generate-HTMLVisualization -Graph $graph -MermaidCode $mermaidCode
        $html | Set-Content $defaultOutputFile -Encoding UTF8
        Write-Host "Created: $defaultOutputFile" -ForegroundColor Green
    }
    "mermaid" {
        $mermaidCode | Set-Content $defaultOutputFile -Encoding UTF8
        Write-Host "Created: $defaultOutputFile" -ForegroundColor Green
    }
    "json" {
        $graph | ConvertTo-Json -Depth 10 | Set-Content $defaultOutputFile -Encoding UTF8
        Write-Host "Created: $defaultOutputFile" -ForegroundColor Green
    }
    "all" {
        $html = Generate-HTMLVisualization -Graph $graph -MermaidCode $mermaidCode
        $html | Set-Content "$defaultOutputFile.html" -Encoding UTF8
        $mermaidCode | Set-Content "$defaultOutputFile.md" -Encoding UTF8
        $graph | ConvertTo-Json -Depth 10 | Set-Content "$defaultOutputFile.json" -Encoding UTF8
        Write-Host "Created:" -ForegroundColor Green
        Write-Host "  - $defaultOutputFile.html" -ForegroundColor DarkGray
        Write-Host "  - $defaultOutputFile.md" -ForegroundColor DarkGray
        Write-Host "  - $defaultOutputFile.json" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "=== Graph Statistics ===" -ForegroundColor Cyan
Write-Host "  Total Projects: $($graph.Count)" -ForegroundColor White
Write-Host "  Project Dependencies: $(($graph.Values.Dependencies | Where-Object { $_.Type -eq 'Project' }).Count)" -ForegroundColor White

if ($IncludeNuGet) {
    Write-Host "  NuGet Dependencies: $(($graph.Values.Dependencies | Where-Object { $_.Type -eq 'Package' }).Count)" -ForegroundColor White
}

Write-Host "  Circular Dependencies: $($cycles.Count)" -ForegroundColor $(if ($cycles.Count -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($OutputFormat -eq "html") {
    Write-Host "Open $defaultOutputFile in a browser to view the interactive graph" -ForegroundColor Cyan
}

Write-Host ""

exit 0
