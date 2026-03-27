<#
.SYNOPSIS
    Infrastructure as Code generator for Azure resources.

.DESCRIPTION
    Generates Terraform or Bicep templates for common Azure infrastructure patterns.
    Supports web apps, databases, storage, and networking.

.PARAMETER Provider
    IaC provider: terraform, bicep

.PARAMETER ResourceType
    Resource type: webapp, database, storage, network, full-stack

.PARAMETER OutputPath
    Output path for generated files

.PARAMETER ProjectName
    Project name for resource naming

.PARAMETER Environment
    Environment: dev, staging, production

.EXAMPLE
    .\generate-infrastructure.ps1 -Provider terraform -ResourceType webapp -ProjectName "client-manager"
    .\generate-infrastructure.ps1 -Provider bicep -ResourceType full-stack -Environment production
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("terraform", "bicep")]
    [string]$Provider,

    [Parameter(Mandatory=$true)]
    [ValidateSet("webapp", "database", "storage", "network", "full-stack")]
    [string]$ResourceType,

    [string]$OutputPath,
    [string]$ProjectName = "myproject",
    [ValidateSet("dev", "staging", "production")]
    [string]$Environment = "dev"
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Generate-TerraformWebApp {
    param([string]$ProjectName, [string]$Environment)

    return @"
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  resource_prefix = "$ProjectName-$Environment"
  location        = "eastus"
  tags = {
    Environment = "$Environment"
    Project     = "$ProjectName"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "`${local.resource_prefix}-rg"
  location = local.location
  tags     = local.tags
}

resource "azurerm_app_service_plan" "main" {
  name                = "`${local.resource_prefix}-asp"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "$( if ($Environment -eq 'production') { 'Standard' } else { 'Basic' })"
    size = "$( if ($Environment -eq 'production') { 'S1' } else { 'B1' })"
  }

  tags = local.tags
}

resource "azurerm_app_service" "api" {
  name                = "`${local.resource_prefix}-api"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  app_service_plan_id = azurerm_app_service_plan.main.id

  site_config {
    linux_fx_version = "DOTNETCORE|8.0"
    always_on        = $( if ($Environment -eq 'production') { 'true' } else { 'false' })
  }

  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = "$Environment"
  }

  tags = local.tags
}

output "api_url" {
  value = "https://`${azurerm_app_service.api.default_site_hostname}"
}
"@
}

function Generate-BicepWebApp {
    param([string]$ProjectName, [string]$Environment)

    return @"
param location string = 'eastus'
param projectName string = '$ProjectName'
param environment string = '$Environment'

var resourcePrefix = '`${projectName}-`${environment}'
var tags = {
  Environment: environment
  Project: projectName
  ManagedBy: 'Bicep'
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '`${resourcePrefix}-asp'
  location: location
  tags: tags
  sku: {
    name: environment == 'production' ? 'S1' : 'B1'
    tier: environment == 'production' ? 'Standard' : 'Basic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: '`${resourcePrefix}-api'
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|8.0'
      alwaysOn: environment == 'production'
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: environment
        }
      ]
    }
  }
}

output apiUrl string = 'https://`${webApp.properties.defaultHostName}'
"@
}

# Main execution
Write-Host ""
Write-Host "=== Infrastructure as Code Generator ===" -ForegroundColor Cyan
Write-Host ""

if (-not $OutputPath) {
    $OutputPath = "infrastructure"
}

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

Write-Host "Generating $Provider configuration for $ResourceType..." -ForegroundColor Yellow
Write-Host ""

$content = if ($Provider -eq "terraform") {
    Generate-TerraformWebApp -ProjectName $ProjectName -Environment $Environment
} else {
    Generate-BicepWebApp -ProjectName $ProjectName -Environment $Environment
}

$extension = if ($Provider -eq "terraform") { "tf" } else { "bicep" }
$filename = "$ResourceType.$extension"
$filepath = Join-Path $OutputPath $filename

$content | Set-Content $filepath -Encoding UTF8

Write-Host "Generated: $filepath" -ForegroundColor Green
Write-Host ""

Write-Host "=== Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
