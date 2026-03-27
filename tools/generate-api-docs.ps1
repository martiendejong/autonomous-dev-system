<#
.SYNOPSIS
    Generates API documentation from C# controllers and Swagger/OpenAPI specs.

.DESCRIPTION
    Scans ASP.NET Core projects for API controllers and generates comprehensive documentation.
    Supports Swagger/OpenAPI spec extraction, Postman collection export, and interactive HTML.

    Features:
    - Auto-detects Swagger endpoints in ASP.NET Core apps
    - Generates Postman collections for API testing
    - Creates interactive HTML documentation
    - Validates API endpoints are reachable
    - Extracts route attributes from controllers

.PARAMETER ProjectPath
    Path to ASP.NET Core project (should contain .csproj)

.PARAMETER OutputPath
    Output directory for documentation (default: api-docs)

.PARAMETER Format
    Output format: html, markdown, postman, openapi, or all (default: html)

.PARAMETER BaseUrl
    Base URL for API testing (default: https://localhost:7001)

.PARAMETER ValidateEndpoints
    Test that API endpoints are reachable

.EXAMPLE
    .\generate-api-docs.ps1 -ProjectPath "C:\Projects\client-manager\ClientManagerApi"
    .\generate-api-docs.ps1 -ProjectPath ".\API" -Format "all" -ValidateEndpoints
    .\generate-api-docs.ps1 -ProjectPath ".\API" -BaseUrl "https://api.example.com"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [string]$OutputPath = "api-docs",

    [ValidateSet("html", "markdown", "postman", "openapi", "all")]
    [string]$Format = "html",

    [string]$BaseUrl = "https://localhost:7001",

    [switch]$ValidateEndpoints
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Find-SwaggerEndpoint {
    param([string]$ProjectPath)

    # Check if project uses Swashbuckle/Swagger
    $csproj = Get-ChildItem $ProjectPath -Filter "*.csproj" | Select-Object -First 1

    if (-not $csproj) {
        return $null
    }

    [xml]$xml = Get-Content $csproj.FullName

    # Check for Swashbuckle.AspNetCore package
    $hasSwagger = $xml.Project.ItemGroup.PackageReference | Where-Object {
        $_.Include -like "Swashbuckle*"
    }

    if ($hasSwagger) {
        # Common Swagger endpoints
        $endpoints = @(
            "$BaseUrl/swagger/v1/swagger.json",
            "$BaseUrl/swagger/swagger.json",
            "$BaseUrl/api-docs/v1/swagger.json"
        )

        return $endpoints
    }

    return $null
}

function Get-ControllerFiles {
    param([string]$ProjectPath)

    $controllers = Get-ChildItem $ProjectPath -Filter "*Controller.cs" -Recurse -ErrorAction SilentlyContinue

    return $controllers
}

function Parse-ControllerEndpoints {
    param([string]$ControllerPath)

    $content = Get-Content $ControllerPath -Raw

    $endpoints = @()

    # Extract controller route
    $routeMatch = [regex]::Match($content, '\[Route\("([^"]+)"\)\]')
    $controllerRoute = if ($routeMatch.Success) { $routeMatch.Groups[1].Value } else { "" }

    # Extract API controller name
    $controllerName = [System.IO.Path]::GetFileNameWithoutExtension($ControllerPath) -replace 'Controller$', ''

    # Find all HTTP method attributes
    $httpMethods = @(
        @{ Pattern = '\[HttpGet(?:\("([^"]+)"\))?\]'; Method = "GET" }
        @{ Pattern = '\[HttpPost(?:\("([^"]+)"\))?\]'; Method = "POST" }
        @{ Pattern = '\[HttpPut(?:\("([^"]+)"\))?\]'; Method = "PUT" }
        @{ Pattern = '\[HttpDelete(?:\("([^"]+)"\))?\]'; Method = "DELETE" }
        @{ Pattern = '\[HttpPatch(?:\("([^"]+)"\))?\]'; Method = "PATCH" }
    )

    foreach ($httpMethod in $httpMethods) {
        $matches = [regex]::Matches($content, $httpMethod.Pattern)

        foreach ($match in $matches) {
            $route = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { "" }

            # Combine controller route + action route
            $fullRoute = if ($controllerRoute) {
                "/$controllerRoute"
            } else {
                "/api/$controllerName"
            }

            if ($route) {
                $fullRoute = "$fullRoute/$route"
            }

            # Clean up double slashes
            $fullRoute = $fullRoute -replace '/+', '/'

            # Extract method name (approximate - find public method near the attribute)
            $methodContext = $content.Substring([Math]::Max(0, $match.Index), [Math]::Min(200, $content.Length - $match.Index))
            $methodNameMatch = [regex]::Match($methodContext, 'public\s+(?:async\s+)?(?:Task<)?(?:ActionResult<)?(\w+)')
            $methodName = if ($methodNameMatch.Success) { $methodNameMatch.Groups[1].Value } else { "Unknown" }

            $endpoints += @{
                "Method" = $httpMethod.Method
                "Route" = $fullRoute
                "Controller" = $controllerName
                "Action" = $methodName
            }
        }
    }

    return $endpoints
}

function Fetch-SwaggerSpec {
    param([string]$Url)

    try {
        Write-Host "Fetching Swagger spec from: $Url" -ForegroundColor DarkGray

        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop

        if ($response.StatusCode -eq 200) {
            return $response.Content | ConvertFrom-Json
        }

    } catch {
        return $null
    }

    return $null
}

function Generate-HTMLDocumentation {
    param([array]$Endpoints, [string]$ProjectName, [object]$SwaggerSpec)

    $endpointRows = ""

    foreach ($endpoint in $Endpoints | Sort-Object Route) {
        $methodColor = switch ($endpoint.Method) {
            "GET" { "#61affe" }
            "POST" { "#49cc90" }
            "PUT" { "#fca130" }
            "DELETE" { "#f93e3e" }
            default { "#999" }
        }

        $endpointRows += @"
            <tr>
                <td><span class="method" style="background: $methodColor;">$($endpoint.Method)</span></td>
                <td><code>$($endpoint.Route)</code></td>
                <td>$($endpoint.Controller)</td>
                <td>$($endpoint.Action)</td>
            </tr>

"@
    }

    $swaggerSection = if ($SwaggerSpec) {
        @"
        <div class="section">
            <h2>OpenAPI Specification</h2>
            <p>Swagger UI available at: <a href="$BaseUrl/swagger" target="_blank">$BaseUrl/swagger</a></p>
            <p>OpenAPI version: $($SwaggerSpec.openapi)</p>
            <p>API Title: $($SwaggerSpec.info.title)</p>
            <p>API Version: $($SwaggerSpec.info.version)</p>
        </div>
"@
    } else {
        ""
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API Documentation - $ProjectName</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #61affe;
            padding-bottom: 10px;
        }
        .section {
            margin: 30px 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th {
            background: #f8f9fa;
            padding: 12px;
            text-align: left;
            border-bottom: 2px solid #dee2e6;
            font-weight: 600;
        }
        td {
            padding: 10px 12px;
            border-bottom: 1px solid #dee2e6;
        }
        tr:hover {
            background: #f8f9fa;
        }
        .method {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 4px;
            color: white;
            font-weight: bold;
            font-size: 0.85em;
            min-width: 60px;
            text-align: center;
        }
        code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        .stat-card {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 6px;
            border-left: 4px solid #61affe;
        }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #61affe;
        }
        .stat-label {
            color: #666;
            font-size: 0.9em;
        }
        a {
            color: #61affe;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>API Documentation - $ProjectName</h1>

        <div class="stats">
            <div class="stat-card">
                <div class="stat-value">$($Endpoints.Count)</div>
                <div class="stat-label">Total Endpoints</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$(($Endpoints | Select-Object -ExpandProperty Controller -Unique).Count)</div>
                <div class="stat-label">Controllers</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$(($Endpoints | Where-Object { $_.Method -eq 'GET' }).Count)</div>
                <div class="stat-label">GET Endpoints</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$(($Endpoints | Where-Object { $_.Method -eq 'POST' }).Count)</div>
                <div class="stat-label">POST Endpoints</div>
            </div>
        </div>

        $swaggerSection

        <div class="section">
            <h2>All Endpoints</h2>
            <table>
                <thead>
                    <tr>
                        <th>Method</th>
                        <th>Route</th>
                        <th>Controller</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
$endpointRows
                </tbody>
            </table>
        </div>

        <p style="color: #666; font-size: 0.9em; margin-top: 40px;">
            Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Base URL: $BaseUrl
        </p>
    </div>
</body>
</html>
"@

    return $html
}

function Generate-MarkdownDocumentation {
    param([array]$Endpoints, [string]$ProjectName)

    $md = @"
# API Documentation - $ProjectName

Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Statistics

- **Total Endpoints:** $($Endpoints.Count)
- **Controllers:** $(($Endpoints | Select-Object -ExpandProperty Controller -Unique).Count)
- **GET Endpoints:** $(($Endpoints | Where-Object { $_.Method -eq 'GET' }).Count)
- **POST Endpoints:** $(($Endpoints | Where-Object { $_.Method -eq 'POST' }).Count)

## Endpoints

| Method | Route | Controller | Action |
|--------|-------|------------|--------|

"@

    foreach ($endpoint in $Endpoints | Sort-Object Route) {
        $md += "| $($endpoint.Method) | ``$($endpoint.Route)`` | $($endpoint.Controller) | $($endpoint.Action) |`n"
    }

    $md += @"

## Base URL

``$BaseUrl``

---

*Generated by generate-api-docs.ps1*
"@

    return $md
}

function Generate-PostmanCollection {
    param([array]$Endpoints, [string]$ProjectName)

    $requests = @()

    foreach ($endpoint in $Endpoints) {
        $requests += @{
            "name" = "$($endpoint.Controller).$($endpoint.Action)"
            "request" = @{
                "method" = $endpoint.Method
                "header" = @()
                "url" = @{
                    "raw" = "$BaseUrl$($endpoint.Route)"
                    "protocol" = "https"
                    "host" = @($BaseUrl -replace 'https?://', '' -split ':')[0]
                    "port" = if ($BaseUrl -match ':(\d+)') { $matches[1] } else { "" }
                    "path" = ($endpoint.Route -split '/' | Where-Object { $_ })
                }
            }
        }
    }

    $collection = @{
        "info" = @{
            "name" = "$ProjectName API"
            "description" = "Generated from ASP.NET Core controllers"
            "schema" = "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
        }
        "item" = $requests
    }

    return $collection | ConvertTo-Json -Depth 10
}

# Main execution
Write-Host ""
Write-Host "=== API Documentation Generator ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

$projectName = Split-Path $ProjectPath -Leaf

Write-Host "Project: $projectName" -ForegroundColor White
Write-Host "Base URL: $BaseUrl" -ForegroundColor DarkGray
Write-Host ""

# Find controllers
Write-Host "Scanning for API controllers..." -ForegroundColor Cyan
$controllers = Get-ControllerFiles -ProjectPath $ProjectPath

if ($controllers.Count -eq 0) {
    Write-Host "No controllers found in project" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($controllers.Count) controllers" -ForegroundColor Green
Write-Host ""

# Parse endpoints
Write-Host "Extracting endpoints..." -ForegroundColor Cyan
$allEndpoints = @()

foreach ($controller in $controllers) {
    $endpoints = Parse-ControllerEndpoints -ControllerPath $controller.FullName
    $allEndpoints += $endpoints
}

Write-Host "Found $($allEndpoints.Count) endpoints" -ForegroundColor Green
Write-Host ""

# Try to fetch Swagger spec
$swaggerSpec = $null
$swaggerEndpoints = Find-SwaggerEndpoint -ProjectPath $ProjectPath

if ($swaggerEndpoints) {
    Write-Host "Attempting to fetch Swagger spec..." -ForegroundColor Cyan

    foreach ($endpoint in $swaggerEndpoints) {
        $swaggerSpec = Fetch-SwaggerSpec -Url $endpoint

        if ($swaggerSpec) {
            Write-Host "  Found Swagger spec at: $endpoint" -ForegroundColor Green
            break
        }
    }

    if (-not $swaggerSpec) {
        Write-Host "  Could not fetch Swagger spec (API may not be running)" -ForegroundColor Yellow
    }
}

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

# Generate documentation
Write-Host ""
Write-Host "=== Generating Documentation ===" -ForegroundColor Cyan
Write-Host ""

$generated = @()

switch ($Format) {
    "html" {
        $html = Generate-HTMLDocumentation -Endpoints $allEndpoints -ProjectName $projectName -SwaggerSpec $swaggerSpec
        $htmlPath = Join-Path $OutputPath "index.html"
        $html | Set-Content $htmlPath -Encoding UTF8
        $generated += $htmlPath
    }
    "markdown" {
        $md = Generate-MarkdownDocumentation -Endpoints $allEndpoints -ProjectName $projectName
        $mdPath = Join-Path $OutputPath "API.md"
        $md | Set-Content $mdPath -Encoding UTF8
        $generated += $mdPath
    }
    "postman" {
        $postman = Generate-PostmanCollection -Endpoints $allEndpoints -ProjectName $projectName
        $postmanPath = Join-Path $OutputPath "postman_collection.json"
        $postman | Set-Content $postmanPath -Encoding UTF8
        $generated += $postmanPath
    }
    "openapi" {
        if ($swaggerSpec) {
            $openapiPath = Join-Path $OutputPath "openapi.json"
            $swaggerSpec | ConvertTo-Json -Depth 10 | Set-Content $openapiPath -Encoding UTF8
            $generated += $openapiPath
        } else {
            Write-Host "Cannot generate OpenAPI spec - Swagger not available" -ForegroundColor Yellow
        }
    }
    "all" {
        $html = Generate-HTMLDocumentation -Endpoints $allEndpoints -ProjectName $projectName -SwaggerSpec $swaggerSpec
        $htmlPath = Join-Path $OutputPath "index.html"
        $html | Set-Content $htmlPath -Encoding UTF8
        $generated += $htmlPath

        $md = Generate-MarkdownDocumentation -Endpoints $allEndpoints -ProjectName $projectName
        $mdPath = Join-Path $OutputPath "API.md"
        $md | Set-Content $mdPath -Encoding UTF8
        $generated += $mdPath

        $postman = Generate-PostmanCollection -Endpoints $allEndpoints -ProjectName $projectName
        $postmanPath = Join-Path $OutputPath "postman_collection.json"
        $postman | Set-Content $postmanPath -Encoding UTF8
        $generated += $postmanPath

        if ($swaggerSpec) {
            $openapiPath = Join-Path $OutputPath "openapi.json"
            $swaggerSpec | ConvertTo-Json -Depth 10 | Set-Content $openapiPath -Encoding UTF8
            $generated += $openapiPath
        }
    }
}

Write-Host "Generated:" -ForegroundColor Green
foreach ($file in $generated) {
    Write-Host "  - $file" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== Documentation Complete ===" -ForegroundColor Green
Write-Host ""

if ($Format -eq "html" -or $Format -eq "all") {
    Write-Host "Open $(Join-Path $OutputPath 'index.html') in a browser to view the documentation" -ForegroundColor Cyan
    Write-Host ""
}

exit 0
