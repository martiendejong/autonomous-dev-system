<#
.SYNOPSIS
    Generates interactive component catalog for React components.

.DESCRIPTION
    Auto-discovers React components and creates Storybook-style documentation.
    Generates interactive examples and exports to static HTML.

    Features:
    - Auto-discovers .tsx/.jsx components
    - Extracts props using TypeScript interfaces
    - Generates component previews
    - Creates interactive examples
    - Exports to static HTML for design team
    - Categorizes components by directory

.PARAMETER ProjectPath
    Path to frontend project (should contain src/ directory)

.PARAMETER OutputPath
    Output directory for catalog (default: component-catalog)

.PARAMETER Format
    Output format: html, markdown, json, or all (default: html)

.PARAMETER IncludeTests
    Include test files in component discovery

.PARAMETER Interactive
    Generate interactive examples (requires running dev server)

.EXAMPLE
    .\generate-component-catalog.ps1 -ProjectPath "C:\Projects\client-manager\ClientManagerFrontend"
    .\generate-component-catalog.ps1 -ProjectPath "." -Format all
    .\generate-component-catalog.ps1 -ProjectPath "." -Interactive
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [string]$OutputPath = "component-catalog",
    [ValidateSet("html", "markdown", "json", "all")]
    [string]$Format = "html",
    [switch]$IncludeTests,
    [switch]$Interactive
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Find-ReactComponents {
    param([string]$ProjectPath, [bool]$IncludeTests)

    $srcPath = Join-Path $ProjectPath "src"

    if (-not (Test-Path $srcPath)) {
        Write-Host "ERROR: src/ directory not found" -ForegroundColor Red
        return @()
    }

    # Find all .tsx and .jsx files
    $pattern = if ($IncludeTests) { "*.tsx", "*.jsx" } else { "*.tsx", "*.jsx" }
    $files = Get-ChildItem $srcPath -Include $pattern -Recurse -File

    if (-not $IncludeTests) {
        $files = $files | Where-Object { $_.Name -notmatch '\.(test|spec)\.(tsx|jsx)$' }
    }

    $components = @()

    foreach ($file in $files) {
        $component = Parse-Component -FilePath $file.FullName -ProjectPath $ProjectPath
        if ($component) {
            $components += $component
        }
    }

    return $components
}

function Parse-Component {
    param([string]$FilePath, [string]$ProjectPath)

    $content = Get-Content $FilePath -Raw

    # Check if file contains React component
    if ($content -notmatch 'function\s+(\w+)' -and $content -notmatch 'const\s+(\w+)\s*=.*=>' -and $content -notmatch 'export\s+(default\s+)?function') {
        return $null
    }

    # Extract component name
    $componentName = $null

    if ($content -match 'export\s+(?:default\s+)?function\s+(\w+)') {
        $componentName = $matches[1]
    } elseif ($content -match 'const\s+(\w+)\s*[:=].*React\.FC|FunctionComponent') {
        $componentName = $matches[1]
    } elseif ($content -match 'function\s+(\w+).*\{[^}]*return\s+\(?\s*<') {
        $componentName = $matches[1]
    }

    if (-not $componentName) {
        return $null
    }

    # Extract props interface
    $props = Extract-Props -Content $content -ComponentName $componentName

    # Extract imports
    $imports = Extract-Imports -Content $content

    # Get relative path
    $relativePath = $FilePath -replace [regex]::Escape($ProjectPath), '.'
    $relativePath = $relativePath -replace '\\', '/'

    # Categorize by directory
    $category = Get-ComponentCategory -FilePath $relativePath

    return @{
        "Name" = $componentName
        "Path" = $relativePath
        "Props" = $props
        "Imports" = $imports
        "Category" = $category
        "HasTests" = (Test-Path ($FilePath -replace '\.(tsx|jsx)$', '.test.$1'))
    }
}

function Extract-Props {
    param([string]$Content, [string]$ComponentName)

    $props = @()

    # Look for interface or type definition
    $interfacePattern = "interface\s+${ComponentName}Props\s*\{([^}]+)\}"
    $typePattern = "type\s+${ComponentName}Props\s*=\s*\{([^}]+)\}"

    $propsContent = $null

    if ($Content -match $interfacePattern) {
        $propsContent = $matches[1]
    } elseif ($Content -match $typePattern) {
        $propsContent = $matches[1]
    }

    if ($propsContent) {
        # Parse each prop
        $lines = $propsContent -split "`n"

        foreach ($line in $lines) {
            if ($line -match '^\s*(\w+)\??\s*:\s*(.+?)\s*(;|$)') {
                $propName = $matches[1]
                $propType = $matches[2].Trim()
                $isOptional = $line -match '\?'

                $props += @{
                    "Name" = $propName
                    "Type" = $propType
                    "Optional" = $isOptional
                }
            }
        }
    }

    return $props
}

function Extract-Imports {
    param([string]$Content)

    $imports = @()

    $lines = $Content -split "`n"

    foreach ($line in $lines) {
        if ($line -match '^import\s+') {
            $imports += $line.Trim()
        }
    }

    return $imports
}

function Get-ComponentCategory {
    param([string]$FilePath)

    if ($FilePath -match '/components/(\w+)/') {
        return $matches[1]
    } elseif ($FilePath -match '/pages/') {
        return "Pages"
    } elseif ($FilePath -match '/layouts/') {
        return "Layouts"
    } elseif ($FilePath -match '/hooks/') {
        return "Hooks"
    } elseif ($FilePath -match '/ui/') {
        return "UI"
    } else {
        return "Other"
    }
}

function Generate-HTMLCatalog {
    param([array]$Components)

    # Group by category
    $grouped = $Components | Group-Object -Property Category

    $categoryHTML = ""

    foreach ($group in $grouped | Sort-Object Name) {
        $categoryHTML += "<div class='category'>`n"
        $categoryHTML += "  <h2>$($group.Name)</h2>`n"
        $categoryHTML += "  <div class='components'>`n"

        foreach ($component in $group.Group | Sort-Object Name) {
            $propsHTML = ""

            if ($component.Props.Count -gt 0) {
                $propsHTML = "<table class='props'>`n"
                $propsHTML += "<tr><th>Prop</th><th>Type</th><th>Required</th></tr>`n"

                foreach ($prop in $component.Props) {
                    $required = if ($prop.Optional) { "No" } else { "Yes" }
                    $propsHTML += "<tr><td>$($prop.Name)</td><td><code>$($prop.Type)</code></td><td>$required</td></tr>`n"
                }

                $propsHTML += "</table>`n"
            } else {
                $propsHTML = "<p class='no-props'>No props</p>`n"
            }

            $testBadge = if ($component.HasTests) {
                "<span class='badge test-badge'>Has Tests</span>"
            } else {
                "<span class='badge no-test-badge'>No Tests</span>"
            }

            $categoryHTML += @"
    <div class="component-card">
      <div class="component-header">
        <h3>$($component.Name)</h3>
        $testBadge
      </div>
      <p class="component-path">$($component.Path)</p>
      <div class="component-props">
        <h4>Props</h4>
        $propsHTML
      </div>
    </div>

"@
        }

        $categoryHTML += "  </div>`n"
        $categoryHTML += "</div>`n"
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Component Catalog</title>
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
            border-bottom: 3px solid #61dafb;
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
            border-left: 4px solid #61dafb;
        }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #61dafb;
        }
        .stat-label {
            color: #666;
            font-size: 0.9em;
        }
        .category {
            margin: 40px 0;
        }
        .category h2 {
            color: #61dafb;
            border-bottom: 2px solid #e9ecef;
            padding-bottom: 10px;
        }
        .components {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .component-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 6px;
            border: 1px solid #dee2e6;
        }
        .component-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }
        .component-card h3 {
            margin: 0;
            color: #333;
        }
        .component-path {
            color: #666;
            font-size: 0.85em;
            font-family: 'Courier New', monospace;
            margin: 5px 0 15px 0;
        }
        .component-props h4 {
            margin: 15px 0 10px 0;
            color: #555;
            font-size: 0.95em;
        }
        .props {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.9em;
        }
        .props th {
            background: #e9ecef;
            padding: 8px;
            text-align: left;
            font-weight: 600;
        }
        .props td {
            padding: 8px;
            border-bottom: 1px solid #dee2e6;
        }
        .props code {
            background: #fff;
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 0.85em;
            color: #e83e8c;
        }
        .no-props {
            color: #999;
            font-style: italic;
            font-size: 0.9em;
        }
        .badge {
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 0.75em;
            font-weight: bold;
        }
        .test-badge {
            background: #28a745;
            color: white;
        }
        .no-test-badge {
            background: #ffc107;
            color: #333;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚛️ React Component Catalog</h1>

        <div class="stats">
            <div class="stat-card">
                <div class="stat-value">$($Components.Count)</div>
                <div class="stat-label">Total Components</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$(($grouped | Measure-Object).Count)</div>
                <div class="stat-label">Categories</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$(($Components | Where-Object { $_.HasTests }).Count)</div>
                <div class="stat-label">With Tests</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$(($Components.Props | Measure-Object).Count)</div>
                <div class="stat-label">Total Props</div>
            </div>
        </div>

        $categoryHTML

        <p style="color: #666; font-size: 0.9em; margin-top: 40px;">
            Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Tool: generate-component-catalog.ps1
        </p>
    </div>
</body>
</html>
"@

    return $html
}

function Generate-MarkdownCatalog {
    param([array]$Components)

    $md = "# React Component Catalog`n`n"
    $md += "Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"

    $md += "## Statistics`n`n"
    $md += "- **Total Components:** $($Components.Count)`n"
    $md += "- **With Tests:** $(($Components | Where-Object { $_.HasTests }).Count)`n`n"

    # Group by category
    $grouped = $Components | Group-Object -Property Category

    foreach ($group in $grouped | Sort-Object Name) {
        $md += "## $($group.Name)`n`n"

        foreach ($component in $group.Group | Sort-Object Name) {
            $md += "### $($component.Name)`n`n"
            $md += "**Path:** ``$($component.Path)```n`n"

            if ($component.Props.Count -gt 0) {
                $md += "**Props:**`n`n"
                $md += "| Name | Type | Required |`n"
                $md += "|------|------|----------|`n"

                foreach ($prop in $component.Props) {
                    $required = if ($prop.Optional) { "No" } else { "Yes" }
                    $md += "| $($prop.Name) | ``$($prop.Type)`` | $required |`n"
                }

                $md += "`n"
            } else {
                $md += "*No props*`n`n"
            }

            if ($component.HasTests) {
                $md += "✅ Has tests`n`n"
            } else {
                $md += "⚠️ No tests`n`n"
            }

            $md += "---`n`n"
        }
    }

    return $md
}

# Main execution
Write-Host ""
Write-Host "=== Component Catalog Generator ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Check for package.json
if (-not (Test-Path (Join-Path $ProjectPath "package.json"))) {
    Write-Host "ERROR: Not a Node.js project (no package.json)" -ForegroundColor Red
    exit 1
}

Write-Host "Scanning for React components..." -ForegroundColor Cyan

$components = Find-ReactComponents -ProjectPath $ProjectPath -IncludeTests:$IncludeTests

if ($components.Count -eq 0) {
    Write-Host "No React components found" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($components.Count) components" -ForegroundColor Green
Write-Host ""

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

# Generate catalog
Write-Host "=== Generating Catalog ===" -ForegroundColor Cyan
Write-Host ""

$generated = @()

switch ($Format) {
    "html" {
        $html = Generate-HTMLCatalog -Components $components
        $htmlPath = Join-Path $OutputPath "index.html"
        $html | Set-Content $htmlPath -Encoding UTF8
        $generated += $htmlPath
    }
    "markdown" {
        $md = Generate-MarkdownCatalog -Components $components
        $mdPath = Join-Path $OutputPath "COMPONENTS.md"
        $md | Set-Content $mdPath -Encoding UTF8
        $generated += $mdPath
    }
    "json" {
        $jsonPath = Join-Path $OutputPath "components.json"
        $components | ConvertTo-Json -Depth 10 | Set-Content $jsonPath -Encoding UTF8
        $generated += $jsonPath
    }
    "all" {
        $html = Generate-HTMLCatalog -Components $components
        $htmlPath = Join-Path $OutputPath "index.html"
        $html | Set-Content $htmlPath -Encoding UTF8
        $generated += $htmlPath

        $md = Generate-MarkdownCatalog -Components $components
        $mdPath = Join-Path $OutputPath "COMPONENTS.md"
        $md | Set-Content $mdPath -Encoding UTF8
        $generated += $mdPath

        $jsonPath = Join-Path $OutputPath "components.json"
        $components | ConvertTo-Json -Depth 10 | Set-Content $jsonPath -Encoding UTF8
        $generated += $jsonPath
    }
}

Write-Host "Generated:" -ForegroundColor Green
foreach ($file in $generated) {
    Write-Host "  - $file" -ForegroundColor DarkGray
}

Write-Host ""

if ($Format -eq "html" -or $Format -eq "all") {
    Write-Host "Open $(Join-Path $OutputPath 'index.html') in a browser to view the catalog" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "=== Catalog Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
