<#
.SYNOPSIS
    Sets up Lighthouse CI performance budgets for frontend projects.

.DESCRIPTION
    Creates configuration files for Lighthouse CI to enforce performance budgets.
    Generates lighthouse-budget.json and lighthouserc.js files.

    Can also create GitHub Actions workflow for automated testing.

.PARAMETER ProjectPath
    Path to frontend project (should contain package.json)

.PARAMETER CreateWorkflow
    Create GitHub Actions workflow file

.PARAMETER DevServer
    Development server URL (default: http://localhost:3000)

.PARAMETER Routes
    Comma-separated list of routes to test (default: /)

.EXAMPLE
    .\setup-performance-budget.ps1 -ProjectPath "C:\Projects\client-manager\ClientManagerFrontend"
    .\setup-performance-budget.ps1 -ProjectPath "." -CreateWorkflow -Routes "/,/dashboard,/reports"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [switch]$CreateWorkflow,
    [string]$DevServer = "http://localhost:3000",
    [string]$Routes = "/"
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Create-LighthouseBudget {
    param([string]$Path)

    $budget = @{
        "performance" = 90
        "accessibility" = 95
        "best-practices" = 90
        "seo" = 90
        "pwa" = 50
    }

    $budgetJson = $budget | ConvertTo-Json -Depth 10

    $budgetPath = Join-Path $Path "lighthouse-budget.json"
    $budgetJson | Set-Content $budgetPath -Encoding UTF8

    Write-Host "Created: $budgetPath" -ForegroundColor Green

    return $budgetPath
}

function Create-LighthouseRC {
    param([string]$Path, [string]$Server, [string]$RoutesList)

    $routes = ($RoutesList -split ',') | ForEach-Object { "`"$Server$_`"" }
    $routesFormatted = $routes -join ",`n      "

    $config = @"
module.exports = {
  ci: {
    collect: {
      url: [
      $routesFormatted
      ],
      numberOfRuns: 3,
      settings: {
        preset: 'desktop',
        throttling: {
          rttMs: 40,
          throughputKbps: 10240,
          cpuSlowdownMultiplier: 1
        },
        screenEmulation: {
          mobile: false,
          width: 1350,
          height: 940,
          deviceScaleFactor: 1,
          disabled: false
        }
      }
    },
    assert: {
      preset: 'lighthouse:recommended',
      assertions: {
        'categories:performance': ['error', { minScore: 0.9 }],
        'categories:accessibility': ['warn', { minScore: 0.95 }],
        'categories:best-practices': ['warn', { minScore: 0.9 }],
        'categories:seo': ['warn', { minScore: 0.9 }],
        'first-contentful-paint': ['error', { maxNumericValue: 2000 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
        'total-blocking-time': ['error', { maxNumericValue: 300 }]
      }
    },
    upload: {
      target: 'temporary-public-storage'
    }
  }
};
"@

    $rcPath = Join-Path $Path "lighthouserc.js"
    $config | Set-Content $rcPath -Encoding UTF8

    Write-Host "Created: $rcPath" -ForegroundColor Green

    return $rcPath
}

function Create-GitHubWorkflow {
    param([string]$Path)

    $workflow = @"
name: Lighthouse CI

on:
  pull_request:
    branches: [develop, main]
    paths:
      - 'ClientManagerFrontend/**'
      - '.github/workflows/lighthouse-ci.yml'
  push:
    branches: [develop]
    paths:
      - 'ClientManagerFrontend/**'

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: ClientManagerFrontend/package-lock.json

      - name: Install dependencies
        working-directory: ClientManagerFrontend
        run: npm ci

      - name: Build application
        working-directory: ClientManagerFrontend
        run: npm run build

      - name: Start server
        working-directory: ClientManagerFrontend
        run: |
          npm run preview &
          npx wait-on http://localhost:4173 --timeout 60000

      - name: Run Lighthouse CI
        uses: treosh/lighthouse-ci-action@v11
        with:
          configPath: './ClientManagerFrontend/lighthouserc.js'
          uploadArtifacts: true
          temporaryPublicStorage: true

      - name: Comment PR with Lighthouse results
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          script: |
            const fs = require('fs');
            const results = JSON.parse(fs.readFileSync('.lighthouseci/manifest.json'));
            const summary = results.map(r => \`
            **\${r.url}**
            - Performance: \${r.summary.performance}
            - Accessibility: \${r.summary.accessibility}
            - Best Practices: \${r.summary['best-practices']}
            - SEO: \${r.summary.seo}
            \`).join('\\n');

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.name,
              body: \`## 🔦 Lighthouse CI Results\\n\${summary}\`
            });
"@

    $workflowsDir = Join-Path $Path ".github\workflows"
    if (-not (Test-Path $workflowsDir)) {
        New-Item -ItemType Directory -Path $workflowsDir -Force | Out-Null
    }

    $workflowPath = Join-Path $workflowsDir "lighthouse-ci.yml"
    $workflow | Set-Content $workflowPath -Encoding UTF8

    Write-Host "Created: $workflowPath" -ForegroundColor Green

    return $workflowPath
}

function Install-LighthouseCIDeps {
    param([string]$Path)

    if (-not (Test-Path (Join-Path $Path "package.json"))) {
        Write-Host "WARNING: No package.json found, skipping npm install" -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Installing Lighthouse CI..." -ForegroundColor Cyan

    Push-Location $Path
    try {
        npm install --save-dev @lhci/cli wait-on 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Installed @lhci/cli and wait-on" -ForegroundColor Green
        } else {
            Write-Host "WARNING: npm install failed, install manually:" -ForegroundColor Yellow
            Write-Host "  npm install --save-dev @lhci/cli wait-on" -ForegroundColor DarkGray
        }

    } finally {
        Pop-Location
    }
}

# Main execution
Write-Host ""
Write-Host "=== Performance Budget Setup ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

Write-Host "Setting up performance budgets for: $ProjectPath" -ForegroundColor White
Write-Host ""

# Create configuration files
$budgetPath = Create-LighthouseBudget -Path $ProjectPath
$rcPath = Create-LighthouseRC -Path $ProjectPath -Server $DevServer -RoutesList $Routes

# Install dependencies
Install-LighthouseCIDeps -Path $ProjectPath

# Create GitHub workflow if requested
if ($CreateWorkflow) {
    Write-Host ""
    $workflowPath = Create-GitHubWorkflow -Path $ProjectPath
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Files created:" -ForegroundColor White
Write-Host "  - $budgetPath" -ForegroundColor DarkGray
Write-Host "  - $rcPath" -ForegroundColor DarkGray

if ($CreateWorkflow) {
    Write-Host "  - $workflowPath" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Review and adjust budgets in lighthouse-budget.json" -ForegroundColor White
Write-Host "  2. Test locally: npx lhci autorun" -ForegroundColor White
Write-Host "  3. Commit configuration files" -ForegroundColor White

if ($CreateWorkflow) {
    Write-Host "  4. GitHub Actions will run Lighthouse on PRs automatically" -ForegroundColor White
}

Write-Host ""

exit 0
