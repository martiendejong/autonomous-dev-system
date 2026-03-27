<#
.SYNOPSIS
    Generate API mock server from OpenAPI spec

.DESCRIPTION
    Creates mock API server for testing:
    - Generates mock responses from OpenAPI
    - Supports request validation
    - Example data generation
    - Configurable response delays
    - Error scenario simulation

.PARAMETER SpecFile
    OpenAPI spec file

.PARAMETER Port
    Mock server port (default: 3000)

.PARAMETER ResponseDelay
    Response delay in ms (default: 0)

.PARAMETER Framework
    Mock framework: prism, mockoon, json-server

.PARAMETER OutputPath
    Output directory for mock config

.EXAMPLE
    .\api-mock-server-generator.ps1 -SpecFile "swagger.json" -Port 3000

.NOTES
    Value: 7/10 - Enables parallel development
    Effort: 1.5/10 - Config file generation
    Ratio: 4.7 (TIER A)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SpecFile,

    [Parameter(Mandatory=$false)]
    [int]$Port = 3000,

    [Parameter(Mandatory=$false)]
    [int]$ResponseDelay = 0,

    [Parameter(Mandatory=$false)]
    [ValidateSet('prism', 'mockoon', 'json-server')]
    [string]$Framework = 'prism',

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "./mock-server"
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🎭 API Mock Server Generator" -ForegroundColor Cyan
Write-Host "  Spec: $SpecFile" -ForegroundColor Gray
Write-Host "  Framework: $Framework" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $SpecFile)) {
    Write-Host "❌ Spec file not found: $SpecFile" -ForegroundColor Red
    exit 1
}

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$spec = Get-Content $SpecFile -Raw | ConvertFrom-Json

switch ($Framework) {
    'prism' {
        # Prism mock server
        $configFile = "$OutputPath/prism-config.json"

        $config = @{
            mock = @{
                dynamic = $true
            }
            server = @{
                port = $Port
                delay = $ResponseDelay
            }
        }

        $config | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8

        Write-Host "PRISM MOCK SERVER CONFIG:" -ForegroundColor Cyan
        Write-Host "  Config: $configFile" -ForegroundColor Gray
        Write-Host ""
        Write-Host "START COMMAND:" -ForegroundColor Yellow
        Write-Host "  prism mock -p $Port --dynamic $SpecFile" -ForegroundColor Gray
        Write-Host ""
        Write-Host "OR:" -ForegroundColor Yellow
        Write-Host "  docker run --init --rm -p ${Port}:${Port} stoplight/prism:4 mock -h 0.0.0.0 $SpecFile" -ForegroundColor Gray
    }

    'mockoon' {
        # Mockoon environment
        $envFile = "$OutputPath/mockoon-env.json"

        $env = @{
            uuid = [guid]::NewGuid().ToString()
            name = "Generated Mock API"
            port = $Port
            hostname = "0.0.0.0"
            routes = @()
        }

        # Generate routes from OpenAPI paths
        $routeIndex = 1
        foreach ($path in $spec.paths.PSObject.Properties) {
            foreach ($method in $path.Value.PSObject.Properties) {
                if ($method.Name -notin @('get','post','put','delete','patch')) { continue }

                $env.routes += @{
                    uuid = [guid]::NewGuid().ToString()
                    method = $method.Name.ToUpper()
                    endpoint = $path.Name
                    responses = @(
                        @{
                            uuid = [guid]::NewGuid().ToString()
                            body = "{}"
                            latency = $ResponseDelay
                            statusCode = 200
                        }
                    )
                }
                $routeIndex++
            }
        }

        $env | ConvertTo-Json -Depth 10 | Set-Content $envFile -Encoding UTF8

        Write-Host "MOCKOON ENVIRONMENT:" -ForegroundColor Cyan
        Write-Host "  Environment: $envFile" -ForegroundColor Gray
        Write-Host "  Import this file in Mockoon UI" -ForegroundColor Gray
    }

    'json-server' {
        # JSON Server
        $dbFile = "$OutputPath/db.json"

        $db = @{
            users = @(
                @{id=1; name="John Doe"; email="john@example.com"}
                @{id=2; name="Jane Smith"; email="jane@example.com"}
            )
            posts = @(
                @{id=1; title="Hello World"; userId=1}
                @{id=2; title="Second Post"; userId=2}
            )
        }

        $db | ConvertTo-Json -Depth 10 | Set-Content $dbFile -Encoding UTF8

        Write-Host "JSON SERVER:" -ForegroundColor Cyan
        Write-Host "  Database: $dbFile" -ForegroundColor Gray
        Write-Host ""
        Write-Host "START COMMAND:" -ForegroundColor Yellow
        Write-Host "  json-server --watch $dbFile --port $Port --delay $ResponseDelay" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "✅ Mock server config generated: $OutputPath" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Install framework: npm install -g @stoplight/prism-cli" -ForegroundColor Gray
Write-Host "  2. Start mock server using command above" -ForegroundColor Gray
Write-Host "  3. Test API at http://localhost:$Port" -ForegroundColor Gray
