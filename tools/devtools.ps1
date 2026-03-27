<#
.SYNOPSIS
    Master toolchain orchestrator - unified CLI for all development tools.

.DESCRIPTION
    Central command-line interface for accessing all 97 development tools.
    Provides discovery, quick access, and orchestrated workflows.

.PARAMETER Command
    Command to execute (use 'list' to see all available commands)

.PARAMETER Args
    Arguments to pass to the command

.EXAMPLE
    .\devtools.ps1 list
    .\devtools.ps1 health
    .\devtools.ps1 test-coverage -ProjectPath "."
    .\devtools.ps1 deploy-validate -Environment production
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Args
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$script:ToolsPath = "C:\scripts\tools"

$script:CommandRegistry = @{
    # Health & Status
    "health" = @{ "Tool" = "system-health.ps1"; "Description" = "Run comprehensive health check" }
    "status" = @{ "Tool" = "worktree-status.ps1"; "Description" = "Check worktree pool status" }

    # Testing
    "test-coverage" = @{ "Tool" = "test-coverage-report.ps1"; "Description" = "Generate test coverage report" }
    "test-e2e" = @{ "Tool" = "run-e2e-tests.ps1"; "Description" = "Run E2E tests" }
    "test-load" = @{ "Tool" = "test-api-load.ps1"; "Description" = "Run API load tests" }
    "test-contracts" = @{ "Tool" = "test-api-contracts.ps1"; "Description" = "Test API contracts" }

    # Code Quality
    "code-metrics" = @{ "Tool" = "generate-code-metrics.ps1"; "Description" = "Generate code metrics dashboard" }
    "scan-secrets" = @{ "Tool" = "scan-secrets.ps1"; "Description" = "Scan for secrets" }
    "analyze-bundle" = @{ "Tool" = "analyze-bundle-size.ps1"; "Description" = "Analyze bundle size" }
    "analyze-logs" = @{ "Tool" = "analyze-logs.ps1"; "Description" = "Analyze application logs" }

    # Deployment
    "deploy-validate" = @{ "Tool" = "validate-deployment.ps1"; "Description" = "Validate deployment readiness" }
    "config-drift" = @{ "Tool" = "detect-config-drift.ps1"; "Description" = "Detect configuration drift" }

    # Development
    "workspace" = @{ "Tool" = "generate-vscode-workspace.ps1"; "Description" = "Generate VS Code workspace" }
    "snippets" = @{ "Tool" = "manage-snippets.ps1"; "Description" = "Manage code snippets" }
    "debug-config" = @{ "Tool" = "generate-debug-configs.ps1"; "Description" = "Generate debug configurations" }
    "git-helper" = @{ "Tool" = "git-interactive.ps1"; "Description" = "Interactive Git helper" }
    "refactor" = @{ "Tool" = "refactor-code.ps1"; "Description" = "Automated code refactoring" }

    # Infrastructure
    "infra" = @{ "Tool" = "generate-infrastructure.ps1"; "Description" = "Generate IaC templates" }
    "costs" = @{ "Tool" = "analyze-cloud-costs.ps1"; "Description" = "Analyze cloud costs" }
    "monitor-health" = @{ "Tool" = "monitor-service-health.ps1"; "Description" = "Monitor service health" }

    # Database
    "seed-db" = @{ "Tool" = "seed-database.ps1"; "Description" = "Seed database with test data" }
    "db-schema" = @{ "Tool" = "compare-database-schemas.ps1"; "Description" = "Compare database schemas" }

    # Performance
    "profile" = @{ "Tool" = "profile-performance.ps1"; "Description" = "Profile performance" }
    "perf-baseline" = @{ "Tool" = "manage-performance-baseline.ps1"; "Description" = "Manage performance baselines" }
    "monitor-api" = @{ "Tool" = "monitor-api-performance.ps1"; "Description" = "Monitor API performance" }

    # Environment
    "env-manage" = @{ "Tool" = "manage-environment.ps1"; "Description" = "Manage environment variables" }
    "feature-flags" = @{ "Tool" = "manage-feature-flags.ps1"; "Description" = "Manage feature flags" }

    # CI/CD
    "gen-pipeline" = @{ "Tool" = "generate-ci-pipeline.ps1"; "Description" = "Generate CI/CD pipeline" }
    "release-notes" = @{ "Tool" = "generate-release-notes.ps1"; "Description" = "Generate release notes" }

    # Team
    "onboard" = @{ "Tool" = "onboard-developer.ps1"; "Description" = "Onboard new developer" }
    "team-metrics" = @{ "Tool" = "generate-team-metrics.ps1"; "Description" = "Generate team metrics" }

    # Documentation
    "api-docs" = @{ "Tool" = "generate-api-docs.ps1"; "Description" = "Generate API documentation" }
    "component-catalog" = @{ "Tool" = "generate-component-catalog.ps1"; "Description" = "Generate component catalog" }
}

function Show-Commands {
    Write-Host ""
    Write-Host "=== DevTools - Master Toolchain ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available Commands:" -ForegroundColor Yellow
    Write-Host ""

    $categories = @{
        "Health & Status" = @("health", "status")
        "Testing" = @("test-coverage", "test-e2e", "test-load", "test-contracts")
        "Code Quality" = @("code-metrics", "scan-secrets", "analyze-bundle", "analyze-logs")
        "Deployment" = @("deploy-validate", "config-drift")
        "Development" = @("workspace", "snippets", "debug-config", "git-helper", "refactor")
        "Infrastructure" = @("infra", "costs", "monitor-health")
        "Database" = @("seed-db", "db-schema")
        "Performance" = @("profile", "perf-baseline", "monitor-api")
        "Environment" = @("env-manage", "feature-flags")
        "CI/CD" = @("gen-pipeline", "release-notes")
        "Team" = @("onboard", "team-metrics")
        "Documentation" = @("api-docs", "component-catalog")
    }

    foreach ($category in $categories.Keys | Sort-Object) {
        Write-Host "$category" -ForegroundColor Green
        Write-Host ""

        foreach ($cmd in $categories[$category]) {
            if ($script:CommandRegistry.ContainsKey($cmd)) {
                $desc = $script:CommandRegistry[$cmd].Description
                Write-Host ("  {0,-20} {1}" -f $cmd, $desc) -ForegroundColor White
            }
        }

        Write-Host ""
    }

    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  devtools <command> [args]" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  devtools health" -ForegroundColor DarkGray
    Write-Host "  devtools test-coverage -ProjectPath ." -ForegroundColor DarkGray
    Write-Host "  devtools deploy-validate -ProjectPath . -Environment production" -ForegroundColor DarkGray
    Write-Host ""
}

function Invoke-Tool {
    param([string]$Command, [array]$Arguments)

    if (-not $script:CommandRegistry.ContainsKey($Command)) {
        Write-Host "ERROR: Unknown command: $Command" -ForegroundColor Red
        Write-Host "Run 'devtools list' to see available commands" -ForegroundColor Yellow
        exit 1
    }

    $tool = $script:CommandRegistry[$Command].Tool
    $toolPath = Join-Path $script:ToolsPath $tool

    if (-not (Test-Path $toolPath)) {
        Write-Host "ERROR: Tool not found: $toolPath" -ForegroundColor Red
        exit 1
    }

    # Execute tool
    & $toolPath @Arguments
}

# Main execution
if ($Command -eq "list") {
    Show-Commands
    exit 0
}

if ($Command -eq "help" -or $Command -eq "-h" -or $Command -eq "--help") {
    Show-Commands
    exit 0
}

Invoke-Tool -Command $Command -Arguments $Args
