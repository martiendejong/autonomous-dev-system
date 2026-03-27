<#
.SYNOPSIS
    Generate images using OpenAI DALL-E API

.DESCRIPTION
    Calls OpenAI DALL-E API to generate images based on text prompts.
    Downloads and saves the generated image to the specified filepath.

.PARAMETER ApiKey
    OpenAI API key for authentication

.PARAMETER Prompt
    Text description of the image to generate

.PARAMETER OutputPath
    File path where the generated image should be saved (PNG format)

.PARAMETER Model
    DALL-E model to use. Options: dall-e-2, dall-e-3 (default: dall-e-3)

.PARAMETER Size
    Image size. For DALL-E 3: 1024x1024, 1024x1792, 1792x1024 (default: 1024x1024)
    For DALL-E 2: 256x256, 512x512, 1024x1024

.PARAMETER Quality
    Image quality (DALL-E 3 only). Options: standard, hd (default: standard)

.PARAMETER Style
    Image style (DALL-E 3 only). Options: vivid, natural (default: vivid)

.EXAMPLE
    .\generate-image.ps1 -ApiKey "sk-..." -Prompt "A cute cat wearing a hat" -OutputPath "C:\images\cat.png"

.EXAMPLE
    .\generate-image.ps1 -ApiKey $env:OPENAI_API_KEY -Prompt "Abstract art" -OutputPath "art.png" -Model dall-e-3 -Size 1792x1024 -Quality hd

.NOTES
    Created: 2026-01-24
    For use by Claude agents and manual invocation
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ApiKey,

    [Parameter(Mandatory=$true)]
    [string]$Prompt,

    [Parameter(Mandatory=$true)]
    [string]$OutputPath,

    [Parameter(Mandatory=$false)]
    [ValidateSet("dall-e-2", "dall-e-3")]
    [string]$Model = "dall-e-3",

    [Parameter(Mandatory=$false)]
    [string]$Size = "1024x1024",

    [Parameter(Mandatory=$false)]
    [ValidateSet("standard", "hd")]
    [string]$Quality = "standard",

    [Parameter(Mandatory=$false)]
    [ValidateSet("vivid", "natural")]
    [string]$Style = "vivid"
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ErrorActionPreference = "Stop"

# Validate size parameter based on model
if ($Model -eq "dall-e-3") {
    if ($Size -notin @("1024x1024", "1024x1792", "1792x1024")) {
        Write-Error "For DALL-E 3, size must be: 1024x1024, 1024x1792, or 1792x1024"
        exit 1
    }
} elseif ($Model -eq "dall-e-2") {
    if ($Size -notin @("256x256", "512x512", "1024x1024")) {
        Write-Error "For DALL-E 2, size must be: 256x256, 512x512, or 1024x1024"
        exit 1
    }
}

# Ensure output directory exists
$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "[+] Created directory: $outputDir" -ForegroundColor Green
}

# Prepare API request
$apiUrl = "https://api.openai.com/v1/images/generations"
$headers = @{
    "Authorization" = "Bearer $ApiKey"
    "Content-Type" = "application/json"
}

# Build request body based on model
$body = @{
    model = $Model
    prompt = $Prompt
    n = 1
    size = $Size
    response_format = "url"
}

# Add DALL-E 3 specific parameters
if ($Model -eq "dall-e-3") {
    $body.quality = $Quality
    $body.style = $Style
}

$jsonBody = $body | ConvertTo-Json

Write-Host "[*] Generating image with OpenAI DALL-E..." -ForegroundColor Cyan
Write-Host "    Model: $Model" -ForegroundColor Gray
Write-Host "    Size: $Size" -ForegroundColor Gray
Write-Host "    Prompt: $Prompt" -ForegroundColor Gray

try {
    # Call OpenAI API
    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $jsonBody

    if (-not $response.data -or $response.data.Count -eq 0) {
        Write-Error "No image data received from OpenAI API"
        exit 1
    }

    $imageUrl = $response.data[0].url
    $revisedPrompt = $response.data[0].revised_prompt

    if ($revisedPrompt) {
        Write-Host "    Revised prompt: $revisedPrompt" -ForegroundColor Gray
    }

    Write-Host "[+] Image generated successfully" -ForegroundColor Green
    Write-Host "[*] Downloading image..." -ForegroundColor Cyan

    # Download the image
    Invoke-WebRequest -Uri $imageUrl -OutFile $OutputPath

    $fileInfo = Get-Item $OutputPath
    Write-Host "[+] Image saved to: $OutputPath" -ForegroundColor Green
    Write-Host "    Size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray

    # Return metadata
    return @{
        Success = $true
        OutputPath = $OutputPath
        Model = $Model
        Size = $Size
        Prompt = $Prompt
        RevisedPrompt = $revisedPrompt
        ImageUrl = $imageUrl
        FileSize = $fileInfo.Length
    }

} catch {
    Write-Host "[!] Error generating image:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    if ($_.ErrorDetails) {
        $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($errorDetails.error) {
            Write-Host "    API Error: $($errorDetails.error.message)" -ForegroundColor Red
            Write-Host "    Type: $($errorDetails.error.type)" -ForegroundColor Red
        }
    }

    exit 1
}
