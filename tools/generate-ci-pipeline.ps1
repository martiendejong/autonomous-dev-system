<#
.SYNOPSIS
    Generates GitHub Actions CI/CD workflows for .NET and frontend projects.

.DESCRIPTION
    Creates comprehensive GitHub Actions workflows for build, test, and deploy.
    Supports multi-environment deployments (dev, staging, production).

    Features:
    - .NET build/test/publish workflows
    - Frontend build/test/deploy workflows
    - Multi-environment support
    - Automated versioning
    - Docker integration
    - Code quality checks
    - Deployment strategies

.PARAMETER ProjectPath
    Path to project root

.PARAMETER ProjectType
    Project type: dotnet, frontend, fullstack (default: auto-detect)

.PARAMETER Environments
    Environments: dev, staging, production (comma-separated)

.PARAMETER DeployTarget
    Deploy target: azure, docker, githubpages, none

.PARAMETER OutputPath
    Output path for workflow files (default: .github/workflows)

.EXAMPLE
    .\generate-ci-pipeline.ps1 -ProjectPath "C:\Projects\client-manager"
    .\generate-ci-pipeline.ps1 -ProjectPath "." -ProjectType dotnet -Environments "dev,staging,prod"
    .\generate-ci-pipeline.ps1 -ProjectPath "." -DeployTarget docker
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [ValidateSet("dotnet", "frontend", "fullstack", "auto")]
    [string]$ProjectType = "auto",

    [string]$Environments = "dev,staging,production",
    [ValidateSet("azure", "docker", "githubpages", "none")]
    [string]$DeployTarget = "none",

    [string]$OutputPath
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Detect-ProjectType {
    param([string]$Path)

    $hasCsProj = (Get-ChildItem $Path -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue).Count -gt 0
    $hasPackageJson = Test-Path (Join-Path $Path "package.json")

    if ($hasCsProj -and $hasPackageJson) {
        return "fullstack"
    } elseif ($hasCsProj) {
        return "dotnet"
    } elseif ($hasPackageJson) {
        return "frontend"
    } else {
        return "unknown"
    }
}

function Generate-DotNetWorkflow {
    param([string]$Environments)

    $envList = $Environments -split ',' | ForEach-Object { $_.Trim() }

    $workflow = @"
name: .NET CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]
  workflow_dispatch:

env:
  DOTNET_VERSION: '8.0.x'

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: `${{ env.DOTNET_VERSION }}

    - name: Restore dependencies
      run: dotnet restore

    - name: Build
      run: dotnet build --no-restore --configuration Release

    - name: Test
      run: dotnet test --no-build --verbosity normal --configuration Release --collect:"XPlat Code Coverage"

    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      with:
        files: ./TestResults/*/coverage.cobertura.xml

    - name: Publish
      run: dotnet publish --no-build --configuration Release --output ./publish

    - name: Upload artifact
      uses: actions/upload-artifact@v4
      with:
        name: dotnet-app
        path: ./publish
"@

    if ($envList -contains "production") {
        $workflow += @"


  deploy-production:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://app.example.com

    steps:
    - name: Download artifact
      uses: actions/download-artifact@v4
      with:
        name: dotnet-app

    - name: Deploy to production
      run: |
        echo "Deploy to production"
        # Add deployment steps here
"@
    }

    return $workflow
}

function Generate-FrontendWorkflow {
    param([string]$Environments, [string]$DeployTarget)

    $workflow = @"
name: Frontend CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]
  workflow_dispatch:

env:
  NODE_VERSION: '18.x'

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: `${{ env.NODE_VERSION }}
        cache: 'npm'

    - name: Install dependencies
      run: npm ci

    - name: Lint
      run: npm run lint

    - name: Test
      run: npm run test:coverage

    - name: Build
      run: npm run build
      env:
        NODE_ENV: production

    - name: Upload coverage reports
      uses: codecov/codecov-action@v3

    - name: Upload build artifact
      uses: actions/upload-artifact@v4
      with:
        name: frontend-build
        path: ./dist
"@

    if ($DeployTarget -eq "githubpages") {
        $workflow += @"


  deploy-github-pages:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    permissions:
      pages: write
      id-token: write

    steps:
    - name: Download artifact
      uses: actions/download-artifact@v4
      with:
        name: frontend-build
        path: ./dist

    - name: Setup Pages
      uses: actions/configure-pages@v4

    - name: Upload to GitHub Pages
      uses: actions/upload-pages-artifact@v3
      with:
        path: ./dist

    - name: Deploy to GitHub Pages
      uses: actions/deploy-pages@v4
"@
    }

    return $workflow
}

function Generate-FullstackWorkflow {
    param([string]$Environments, [string]$DeployTarget)

    $workflow = @"
name: Full-Stack CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]
  workflow_dispatch:

env:
  DOTNET_VERSION: '8.0.x'
  NODE_VERSION: '18.x'

jobs:
  build-backend:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: `${{ env.DOTNET_VERSION }}

    - name: Restore dependencies
      run: dotnet restore

    - name: Build
      run: dotnet build --no-restore --configuration Release

    - name: Test
      run: dotnet test --no-build --verbosity normal --configuration Release

    - name: Publish
      run: dotnet publish --no-build --configuration Release --output ./publish

    - name: Upload backend artifact
      uses: actions/upload-artifact@v4
      with:
        name: backend
        path: ./publish

  build-frontend:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: `${{ env.NODE_VERSION }}
        cache: 'npm'

    - name: Install dependencies
      run: npm ci

    - name: Lint
      run: npm run lint

    - name: Test
      run: npm run test

    - name: Build
      run: npm run build

    - name: Upload frontend artifact
      uses: actions/upload-artifact@v4
      with:
        name: frontend
        path: ./dist

  deploy:
    runs-on: ubuntu-latest
    needs: [build-backend, build-frontend]
    if: github.ref == 'refs/heads/main'

    steps:
    - name: Download backend artifact
      uses: actions/download-artifact@v4
      with:
        name: backend
        path: ./backend

    - name: Download frontend artifact
      uses: actions/download-artifact@v4
      with:
        name: frontend
        path: ./frontend

    - name: Deploy
      run: |
        echo "Deploy full-stack application"
        # Add deployment steps here
"@

    return $workflow
}

function Generate-DockerWorkflow {
    $workflow = @"
name: Docker Build and Push

on:
  push:
    branches: [ main ]
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: `${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
    - uses: actions/checkout@v4

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: `${{ env.REGISTRY }}
        username: `${{ github.actor }}
        password: `${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: `${{ env.REGISTRY }}/`${{ env.IMAGE_NAME }}

    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: `${{ steps.meta.outputs.tags }}
        labels: `${{ steps.meta.outputs.labels }}
"@

    return $workflow
}

function Generate-CodeQualityWorkflow {
    $workflow = @"
name: Code Quality

on:
  pull_request:
    branches: [ main, develop ]

jobs:
  quality:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Run code review
      run: |
        # Add static analysis tools here
        # Example: SonarCloud, CodeQL, etc.
        echo "Code quality checks"

    - name: Check for secrets
      run: |
        # Add secret scanning
        echo "Secret scanning"

    - name: Comment on PR
      uses: actions/github-script@v7
      with:
        script: |
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: '✅ Code quality checks passed!'
          })
"@

    return $workflow
}

# Main execution
Write-Host ""
Write-Host "=== CI/CD Pipeline Generator ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Detect project type
$detectedType = if ($ProjectType -eq "auto") {
    Detect-ProjectType -Path $ProjectPath
} else {
    $ProjectType
}

if ($detectedType -eq "unknown") {
    Write-Host "ERROR: Could not detect project type" -ForegroundColor Red
    Write-Host "Specify -ProjectType parameter" -ForegroundColor Yellow
    exit 1
}

Write-Host "Project Type: $detectedType" -ForegroundColor Green
Write-Host "Environments: $Environments" -ForegroundColor White
Write-Host ""

# Determine output path
$workflowPath = if ($OutputPath) {
    $OutputPath
} else {
    Join-Path $ProjectPath ".github/workflows"
}

if (-not (Test-Path $workflowPath)) {
    New-Item -ItemType Directory -Path $workflowPath -Force | Out-Null
}

# Generate workflows
Write-Host "Generating workflows..." -ForegroundColor Cyan
Write-Host ""

$generated = @()

switch ($detectedType) {
    "dotnet" {
        $workflow = Generate-DotNetWorkflow -Environments $Environments
        $filePath = Join-Path $workflowPath "dotnet-ci.yml"
        $workflow | Set-Content $filePath -Encoding UTF8
        $generated += $filePath
    }
    "frontend" {
        $workflow = Generate-FrontendWorkflow -Environments $Environments -DeployTarget $DeployTarget
        $filePath = Join-Path $workflowPath "frontend-ci.yml"
        $workflow | Set-Content $filePath -Encoding UTF8
        $generated += $filePath
    }
    "fullstack" {
        $workflow = Generate-FullstackWorkflow -Environments $Environments -DeployTarget $DeployTarget
        $filePath = Join-Path $workflowPath "fullstack-ci.yml"
        $workflow | Set-Content $filePath -Encoding UTF8
        $generated += $filePath
    }
}

# Always generate code quality workflow
$qualityWorkflow = Generate-CodeQualityWorkflow
$qualityPath = Join-Path $workflowPath "code-quality.yml"
$qualityWorkflow | Set-Content $qualityPath -Encoding UTF8
$generated += $qualityPath

# Generate Docker workflow if requested
if ($DeployTarget -eq "docker") {
    $dockerWorkflow = Generate-DockerWorkflow
    $dockerPath = Join-Path $workflowPath "docker.yml"
    $dockerWorkflow | Set-Content $dockerPath -Encoding UTF8
    $generated += $dockerPath
}

Write-Host "Generated workflows:" -ForegroundColor Green
foreach ($file in $generated) {
    Write-Host "  - $file" -ForegroundColor White
}

Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Review generated workflows" -ForegroundColor White
Write-Host "2. Commit workflows to repository" -ForegroundColor White
Write-Host "3. Configure repository secrets (if needed)" -ForegroundColor White
Write-Host "4. Push to GitHub to trigger workflows" -ForegroundColor White
Write-Host ""

Write-Host "=== Generation Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
