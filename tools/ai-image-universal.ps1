<#
.SYNOPSIS
    Universal AI image generation supporting multiple providers

.DESCRIPTION
    Unified interface for image generation across multiple AI providers:
    - OpenAI (DALL-E 2, DALL-E 3)
    - Google (Imagen 2, Imagen 3)
    - Stability AI (Stable Diffusion XL, SD 3)
    - Azure OpenAI (DALL-E via Azure)

    Supports all modes: generate, edit, variation, vision-enhanced

.PARAMETER Provider
    AI provider: openai, google, stability, azure
    Default: openai (auto-loads from appsettings.Secrets.json)

.PARAMETER Mode
    Operation mode: generate, edit, variation, vision-enhanced

.PARAMETER Prompt
    Text description of the image

.PARAMETER OutputPath
    File path for output image

.PARAMETER Model
    Model name (provider-specific):
    - openai: dall-e-2, dall-e-3
    - google: imagen-2, imagen-3
    - stability: sd-xl, sd-3
    - azure: dall-e-2, dall-e-3

.PARAMETER ApiKey
    API key (optional, auto-loaded from appsettings if not provided)

.PARAMETER Size
    Image size (format varies by provider)

.PARAMETER Quality
    Quality setting (provider-specific)

.PARAMETER Style
    Style setting (provider-specific)

.PARAMETER SourceImage
    Source image for edit/variation modes

.PARAMETER MaskImage
    Mask image for edit mode

.PARAMETER ReferenceImages
    Reference images for vision-enhanced mode

.PARAMETER ReferenceDescriptions
    Descriptions for each reference image

.PARAMETER NegativePrompt
    What NOT to include (Stability AI, Google Imagen)

.PARAMETER GuidanceScale
    How closely to follow prompt (1-20, default 7)

.PARAMETER Steps
    Number of diffusion steps (Stability AI)

.PARAMETER Seed
    Random seed for reproducibility

.EXAMPLE
    # OpenAI DALL-E 3
    .\ai-image-universal.ps1 -Provider openai -Prompt "Mountain sunset" -OutputPath "sunset.png"

.EXAMPLE
    # Google Imagen with negative prompt
    .\ai-image-universal.ps1 -Provider google -Model imagen-3 `
        -Prompt "A cat" -NegativePrompt "dog, blurry" -OutputPath "cat.png"

.EXAMPLE
    # Stability AI with guidance scale
    .\ai-image-universal.ps1 -Provider stability -Model sd-xl `
        -Prompt "Cyberpunk city" -GuidanceScale 12 -Steps 50 -OutputPath "city.png"

.EXAMPLE
    # Vision-enhanced with reference images
    .\ai-image-universal.ps1 -Mode vision-enhanced `
        -ReferenceImages @("style.png", "colors.png") `
        -ReferenceDescriptions @("Use this art style", "Use this color palette") `
        -Prompt "A forest scene" -OutputPath "forest.png"

.NOTES
    Created: 2026-01-25
    API keys auto-loaded from: C:\Projects\client-manager\ClientManagerAPI\appsettings.Secrets.json
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("openai", "google", "stability", "azure")]
    [string]$Provider = "openai",

    [Parameter(Mandatory=$false)]
    [ValidateSet("generate", "edit", "variation", "vision-enhanced")]
    [string]$Mode = "generate",

    [Parameter(Mandatory=$false)]
    [string]$Prompt = "",

    [Parameter(Mandatory=$true)]
    [string]$OutputPath,

    [Parameter(Mandatory=$false)]
    [string]$Model = "",

    [Parameter(Mandatory=$false)]
    [string]$ApiKey = "",

    [Parameter(Mandatory=$false)]
    [string]$Size = "",

    [Parameter(Mandatory=$false)]
    [string]$Quality = "standard",

    [Parameter(Mandatory=$false)]
    [string]$Style = "vivid",

    [Parameter(Mandatory=$false)]
    [string]$SourceImage = "",

    [Parameter(Mandatory=$false)]
    [string]$MaskImage = "",

    [Parameter(Mandatory=$false)]
    [string[]]$ReferenceImages = @(),

    [Parameter(Mandatory=$false)]
    [string[]]$ReferenceDescriptions = @(),

    [Parameter(Mandatory=$false)]
    [string]$NegativePrompt = "",

    [Parameter(Mandatory=$false)]
    [int]$GuidanceScale = 7,

    [Parameter(Mandatory=$false)]
    [int]$Steps = 30,

    [Parameter(Mandatory=$false)]
    [int]$Seed = -1
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ErrorActionPreference = "Stop"

# Auto-load API keys from appsettings.Secrets.json if not provided
if (-not $ApiKey) {
    $secretsPath = "C:\Projects\client-manager\ClientManagerAPI\appsettings.Secrets.json"

    if (Test-Path $secretsPath) {
        try {
            $secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json

            switch ($Provider) {
                "openai" {
                    $ApiKey = $secrets.ApiSettings.OpenApiKey
                    if (-not $ApiKey) {
                        Write-Error "OpenAI API key not found in secrets file (ApiSettings.OpenApiKey)"
                        exit 1
                    }
                    Write-Host "[*] Loaded OpenAI API key from secrets" -ForegroundColor Gray
                }
                "google" {
                    $ApiKey = $secrets.ApiSettings.GoogleImagenKey
                    if (-not $ApiKey) {
                        Write-Error "Google API key not found in secrets file (ApiSettings.GoogleImagenKey)"
                        exit 1
                    }
                    Write-Host "[*] Loaded Google API key from secrets" -ForegroundColor Gray
                }
                "stability" {
                    $ApiKey = $secrets.ApiSettings.StabilityAiKey
                    if (-not $ApiKey) {
                        Write-Error "Stability AI key not found in secrets file (ApiSettings.StabilityAiKey)"
                        exit 1
                    }
                    Write-Host "[*] Loaded Stability AI key from secrets" -ForegroundColor Gray
                }
                "azure" {
                    $ApiKey = $secrets.ApiSettings.AzureOpenAiKey
                    if (-not $ApiKey) {
                        Write-Error "Azure OpenAI key not found in secrets file (ApiSettings.AzureOpenAiKey)"
                        exit 1
                    }
                    Write-Host "[*] Loaded Azure OpenAI key from secrets" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Error "Failed to load API key from secrets: $_"
            exit 1
        }
    } else {
        Write-Error "API key required. Either provide -ApiKey parameter or ensure appsettings.Secrets.json exists at $secretsPath"
        exit 1
    }
}

# Auto-select model based on provider if not specified
if (-not $Model) {
    switch ($Provider) {
        "openai" { $Model = "dall-e-3" }
        "google" { $Model = "imagen-3" }
        "stability" { $Model = "sd-xl" }
        "azure" { $Model = "dall-e-3" }
    }
}

# Auto-select size based on provider and model if not specified
if (-not $Size) {
    switch ($Provider) {
        "openai" {
            if ($Model -eq "dall-e-3") { $Size = "1024x1024" }
            else { $Size = "1024x1024" }
        }
        "google" { $Size = "1024x1024" }
        "stability" { $Size = "1024x1024" }
        "azure" { $Size = "1024x1024" }
    }
}

# Ensure output directory exists
$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "[+] Created directory: $outputDir" -ForegroundColor Green
}

Write-Host "[*] Provider: $Provider" -ForegroundColor Cyan
Write-Host "    Model: $Model" -ForegroundColor Gray
Write-Host "    Mode: $Mode" -ForegroundColor Gray
Write-Host "    Size: $Size" -ForegroundColor Gray

# Delegate to provider-specific implementation
$scriptPath = $PSScriptRoot

switch ($Provider) {
    "openai" {
        # Delegate to generate-image-advanced.ps1
        $advancedScript = Join-Path $scriptPath "generate-image-advanced.ps1"

        if (-not (Test-Path $advancedScript)) {
            Write-Error "OpenAI implementation not found: $advancedScript"
            exit 1
        }

        $params = @{
            Mode = $Mode
            ApiKey = $ApiKey
            Prompt = $Prompt
            OutputPath = $OutputPath
            Model = $Model
            Size = $Size
            Quality = $Quality
            Style = $Style
        }

        if ($SourceImage) { $params.SourceImage = $SourceImage }
        if ($MaskImage) { $params.MaskImage = $MaskImage }
        if ($ReferenceImages.Count -gt 0) { $params.ReferenceImages = $ReferenceImages }
        if ($ReferenceDescriptions.Count -gt 0) { $params.ReferenceDescriptions = $ReferenceDescriptions }

        & $advancedScript @params
        exit $LASTEXITCODE
    }

    "google" {
        Write-Host "[*] Generating with Google Imagen..." -ForegroundColor Cyan

        # Google Vertex AI Imagen endpoint
        $projectId = $secrets.GoogleCloud.ProjectId
        $location = "us-central1"
        $apiUrl = "https://$location-aiplatform.googleapis.com/v1/projects/$projectId/locations/$location/publishers/google/models/$Model:predict"

        $headers = @{
            "Authorization" = "Bearer $ApiKey"
            "Content-Type" = "application/json"
        }

        $body = @{
            instances = @(
                @{
                    prompt = $Prompt
                }
            )
            parameters = @{
                sampleCount = 1
            }
        }

        if ($NegativePrompt) {
            $body.instances[0].negativePrompt = $NegativePrompt
        }

        if ($Size) {
            # Parse size (e.g., "1024x1024" -> width: 1024, height: 1024)
            if ($Size -match "(\d+)x(\d+)") {
                $body.parameters.width = [int]$matches[1]
                $body.parameters.height = [int]$matches[2]
            }
        }

        if ($GuidanceScale -ne 7) {
            $body.parameters.guidanceScale = $GuidanceScale
        }

        $jsonBody = $body | ConvertTo-Json -Depth 10

        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $jsonBody

            # Imagen returns base64-encoded images
            $base64Image = $response.predictions[0].bytesBase64Encoded
            $imageBytes = [Convert]::FromBase64String($base64Image)

            [System.IO.File]::WriteAllBytes($OutputPath, $imageBytes)

            $fileInfo = Get-Item $OutputPath
            Write-Host "[+] Image saved to: $OutputPath" -ForegroundColor Green
            Write-Host "    Size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray

            exit 0

        } catch {
            Write-Host "[!] Error generating image with Google Imagen:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }

    "stability" {
        Write-Host "[*] Generating with Stability AI..." -ForegroundColor Cyan

        # Stability AI API endpoint
        $apiUrl = if ($Model -eq "sd-3") {
            "https://api.stability.ai/v2beta/stable-image/generate/sd3"
        } else {
            "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image"
        }

        $headers = @{
            "Authorization" = "Bearer $ApiKey"
            "Content-Type" = "application/json"
        }

        $body = @{
            text_prompts = @(
                @{
                    text = $Prompt
                    weight = 1
                }
            )
            cfg_scale = $GuidanceScale
            steps = $Steps
            samples = 1
        }

        if ($NegativePrompt) {
            $body.text_prompts += @{
                text = $NegativePrompt
                weight = -1
            }
        }

        if ($Size -match "(\d+)x(\d+)") {
            $body.width = [int]$matches[1]
            $body.height = [int]$matches[2]
        }

        if ($Seed -ne -1) {
            $body.seed = $Seed
        }

        $jsonBody = $body | ConvertTo-Json -Depth 10

        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $jsonBody

            # Stability returns base64-encoded images
            $base64Image = $response.artifacts[0].base64
            $imageBytes = [Convert]::FromBase64String($base64Image)

            [System.IO.File]::WriteAllBytes($OutputPath, $imageBytes)

            $fileInfo = Get-Item $OutputPath
            Write-Host "[+] Image saved to: $OutputPath" -ForegroundColor Green
            Write-Host "    Size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray
            Write-Host "    Seed: $($response.artifacts[0].seed)" -ForegroundColor Gray

            exit 0

        } catch {
            Write-Host "[!] Error generating image with Stability AI:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }

    "azure" {
        Write-Host "[*] Generating with Azure OpenAI..." -ForegroundColor Cyan

        # Azure OpenAI endpoint (requires deployment name)
        $azureEndpoint = $secrets.AzureOpenAI.Endpoint
        $deploymentName = $secrets.AzureOpenAI.DalleDeployment
        $apiUrl = "$azureEndpoint/openai/deployments/$deploymentName/images/generations?api-version=2024-02-01"

        $headers = @{
            "api-key" = $ApiKey
            "Content-Type" = "application/json"
        }

        $body = @{
            prompt = $Prompt
            n = 1
            size = $Size
        }

        if ($Model -eq "dall-e-3") {
            $body.quality = $Quality
            $body.style = $Style
        }

        $jsonBody = $body | ConvertTo-Json

        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $jsonBody
            $imageUrl = $response.data[0].url

            Write-Host "[+] Image generated successfully" -ForegroundColor Green
            Write-Host "[*] Downloading image..." -ForegroundColor Cyan

            Invoke-WebRequest -Uri $imageUrl -OutFile $OutputPath

            $fileInfo = Get-Item $OutputPath
            Write-Host "[+] Image saved to: $OutputPath" -ForegroundColor Green
            Write-Host "    Size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray

            exit 0

        } catch {
            Write-Host "[!] Error generating image with Azure OpenAI:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }
}
