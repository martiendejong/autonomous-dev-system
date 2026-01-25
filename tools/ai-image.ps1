<#
.SYNOPSIS
    Universal AI image generation with automatic API key loading

.DESCRIPTION
    Simplified wrapper for ai-image-universal.ps1 with automatic API key loading.
    Supports multiple providers: OpenAI, Google Imagen, Stability AI, Azure OpenAI
    Supports all modes: generate, edit, variation, vision-enhanced

.PARAMETER Provider
    AI provider: openai (default), google, stability, azure

.PARAMETER Mode
    Operation mode: generate (default), edit, variation, vision-enhanced

.PARAMETER Prompt
    Text description of the image

.PARAMETER OutputPath
    File path for output image

.PARAMETER Model
    Model name (auto-selected if not specified)

.PARAMETER Size
    Image size (format varies by provider)

.PARAMETER Quality
    Quality setting (OpenAI/Azure only): standard, hd

.PARAMETER Style
    Style setting (OpenAI/Azure only): vivid, natural

.PARAMETER SourceImage
    Source image for edit/variation modes

.PARAMETER MaskImage
    Mask image for edit mode (transparent areas regenerated)

.PARAMETER ReferenceImages
    Reference images for vision-enhanced mode

.PARAMETER ReferenceDescriptions
    Descriptions for each reference image

.PARAMETER NegativePrompt
    What NOT to include (Google/Stability only)

.PARAMETER GuidanceScale
    How closely to follow prompt 1-20 (Google/Stability only)

.PARAMETER Steps
    Number of diffusion steps (Stability AI only)

.PARAMETER Seed
    Random seed for reproducibility (Stability AI only)

.EXAMPLE
    # Simple OpenAI DALL-E 3 generation
    .\ai-image.ps1 -Prompt "A sunset over mountains" -OutputPath "sunset.png"

.EXAMPLE
    # Google Imagen with negative prompt
    .\ai-image.ps1 -Provider google -Prompt "A cat" `
        -NegativePrompt "dog, blurry" -OutputPath "cat.png"

.EXAMPLE
    # Stability AI with high guidance
    .\ai-image.ps1 -Provider stability -Prompt "Cyberpunk city" `
        -GuidanceScale 15 -Steps 50 -OutputPath "city.png"

.EXAMPLE
    # Vision-enhanced with reference images
    .\ai-image.ps1 -Mode vision-enhanced `
        -ReferenceImages @("style-ref.png", "color-ref.png") `
        -ReferenceDescriptions @("Match this art style", "Use this color palette") `
        -Prompt "A forest landscape" -OutputPath "forest.png"

.EXAMPLE
    # Image editing (inpainting, DALL-E 2)
    .\ai-image.ps1 -Mode edit -SourceImage "photo.png" -MaskImage "mask.png" `
        -Prompt "A red car in the masked area" -OutputPath "edited.png"

.EXAMPLE
    # Image variations (DALL-E 2)
    .\ai-image.ps1 -Mode variation -SourceImage "original.png" -OutputPath "variation.png"

.NOTES
    Created: 2026-01-25
    API keys automatically loaded from appsettings.Secrets.json
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
    [string]$Size = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet("standard", "hd")]
    [string]$Quality = "standard",

    [Parameter(Mandatory=$false)]
    [ValidateSet("vivid", "natural")]
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

# Find the universal script
$universalScript = Join-Path $PSScriptRoot "ai-image-universal.ps1"

if (-not (Test-Path $universalScript)) {
    Write-Error "ai-image-universal.ps1 not found: $universalScript"
    exit 1
}

# Build parameters for universal script
$params = @{
    Provider = $Provider
    Mode = $Mode
    OutputPath = $OutputPath
}

if ($Prompt) { $params.Prompt = $Prompt }
if ($Model) { $params.Model = $Model }
if ($Size) { $params.Size = $Size }
if ($Quality -ne "standard") { $params.Quality = $Quality }
if ($Style -ne "vivid") { $params.Style = $Style }
if ($SourceImage) { $params.SourceImage = $SourceImage }
if ($MaskImage) { $params.MaskImage = $MaskImage }
if ($ReferenceImages.Count -gt 0) { $params.ReferenceImages = $ReferenceImages }
if ($ReferenceDescriptions.Count -gt 0) { $params.ReferenceDescriptions = $ReferenceDescriptions }
if ($NegativePrompt) { $params.NegativePrompt = $NegativePrompt }
if ($GuidanceScale -ne 7) { $params.GuidanceScale = $GuidanceScale }
if ($Steps -ne 30) { $params.Steps = $Steps }
if ($Seed -ne -1) { $params.Seed = $Seed }

# Call universal script (API key will be auto-loaded)
& $universalScript @params
exit $LASTEXITCODE
