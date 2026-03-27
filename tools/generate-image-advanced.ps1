<#
.SYNOPSIS
    Advanced AI image generation with reference images and multiple modes

.DESCRIPTION
    Comprehensive image generation tool supporting:
    - DALL-E 3: Text-to-image (highest quality)
    - DALL-E 2: Text-to-image, Image edits (inpainting), Image variations
    - Vision-Enhanced: Analyze reference images with GPT-4 Vision, generate with DALL-E

.PARAMETER Mode
    Operation mode:
    - "generate" (default): Text-to-image generation
    - "edit": Image editing with mask (DALL-E 2 only, inpainting)
    - "variation": Create variations of existing image (DALL-E 2 only)
    - "vision-enhanced": Analyze reference images first, then generate

.PARAMETER ApiKey
    OpenAI API key for authentication

.PARAMETER Prompt
    Text description of the image to generate or edit

.PARAMETER OutputPath
    File path where the generated image should be saved (PNG format)

.PARAMETER Model
    DALL-E model: dall-e-2, dall-e-3 (default: dall-e-3 for generate, dall-e-2 for edit/variation)

.PARAMETER Size
    Image size (varies by model and mode)

.PARAMETER Quality
    Image quality (DALL-E 3 only): standard, hd

.PARAMETER Style
    Image style (DALL-E 3 only): vivid, natural

.PARAMETER SourceImage
    Path to source image (required for edit/variation/vision-enhanced modes)

.PARAMETER MaskImage
    Path to mask image (required for edit mode, transparent areas will be regenerated)

.PARAMETER ReferenceImages
    Array of reference image paths for vision-enhanced mode

.PARAMETER ReferenceDescriptions
    Array of descriptions explaining how each reference image relates to desired output

.EXAMPLE
    # Simple text-to-image (DALL-E 3)
    .\generate-image-advanced.ps1 -ApiKey "sk-..." -Prompt "A sunset" -OutputPath "sunset.png"

.EXAMPLE
    # Image editing (DALL-E 2 inpainting)
    .\generate-image-advanced.ps1 -Mode "edit" -ApiKey "sk-..." `
        -SourceImage "photo.png" -MaskImage "mask.png" `
        -Prompt "A red car in the transparent area" -OutputPath "edited.png"

.EXAMPLE
    # Image variations (DALL-E 2)
    .\generate-image-advanced.ps1 -Mode "variation" -ApiKey "sk-..." `
        -SourceImage "original.png" -OutputPath "variation.png"

.EXAMPLE
    # Vision-enhanced generation (analyze references, then generate)
    .\generate-image-advanced.ps1 -Mode "vision-enhanced" -ApiKey "sk-..." `
        -ReferenceImages @("style-ref.png", "color-ref.png") `
        -ReferenceDescriptions @("Use this art style", "Use this color palette") `
        -Prompt "A mountain landscape" -OutputPath "result.png"

.NOTES
    Created: 2026-01-25
    OpenAI API endpoints used:
    - /v1/images/generations (DALL-E 2 & 3)
    - /v1/images/edits (DALL-E 2 only)
    - /v1/images/variations (DALL-E 2 only)
    - /v1/chat/completions with vision (GPT-4 Vision)
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("generate", "edit", "variation", "vision-enhanced")]
    [string]$Mode = "generate",

    [Parameter(Mandatory=$true)]
    [string]$ApiKey,

    [Parameter(Mandatory=$false)]
    [string]$Prompt = "",

    [Parameter(Mandatory=$true)]
    [string]$OutputPath,

    [Parameter(Mandatory=$false)]
    [ValidateSet("dall-e-2", "dall-e-3")]
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
    [string[]]$ReferenceDescriptions = @()
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ErrorActionPreference = "Stop"

# Auto-select model based on mode if not specified
if (-not $Model) {
    if ($Mode -in @("edit", "variation")) {
        $Model = "dall-e-2"  # Only DALL-E 2 supports these modes
    } else {
        $Model = "dall-e-3"  # Default to best quality
    }
}

# Auto-select size based on model if not specified
if (-not $Size) {
    if ($Model -eq "dall-e-3") {
        $Size = "1024x1024"
    } else {
        $Size = "1024x1024"
    }
}

# Validate mode-specific requirements
switch ($Mode) {
    "edit" {
        if (-not $SourceImage -or -not $MaskImage) {
            Write-Error "Mode 'edit' requires -SourceImage and -MaskImage parameters"
            exit 1
        }
        if ($Model -ne "dall-e-2") {
            Write-Error "Mode 'edit' only supports dall-e-2 model"
            exit 1
        }
        if (-not $Prompt) {
            Write-Error "Mode 'edit' requires -Prompt parameter"
            exit 1
        }
    }
    "variation" {
        if (-not $SourceImage) {
            Write-Error "Mode 'variation' requires -SourceImage parameter"
            exit 1
        }
        if ($Model -ne "dall-e-2") {
            Write-Error "Mode 'variation' only supports dall-e-2 model"
            exit 1
        }
    }
    "vision-enhanced" {
        if ($ReferenceImages.Count -eq 0) {
            Write-Error "Mode 'vision-enhanced' requires -ReferenceImages parameter"
            exit 1
        }
        if ($ReferenceDescriptions.Count -gt 0 -and $ReferenceDescriptions.Count -ne $ReferenceImages.Count) {
            Write-Error "Number of ReferenceDescriptions must match ReferenceImages (or be empty)"
            exit 1
        }
        if (-not $Prompt) {
            Write-Error "Mode 'vision-enhanced' requires -Prompt parameter"
            exit 1
        }
    }
    "generate" {
        if (-not $Prompt) {
            Write-Error "Mode 'generate' requires -Prompt parameter"
            exit 1
        }
    }
}

# Ensure output directory exists
$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "[+] Created directory: $outputDir" -ForegroundColor Green
}

# Helper function: Convert image to base64
function ConvertTo-Base64Image {
    param([string]$ImagePath)

    if (-not (Test-Path $ImagePath)) {
        throw "Image not found: $ImagePath"
    }

    $bytes = [System.IO.File]::ReadAllBytes($ImagePath)
    $base64 = [Convert]::ToBase64String($bytes)

    # Detect MIME type
    $ext = [System.IO.Path]::GetExtension($ImagePath).ToLower()
    $mimeType = switch ($ext) {
        ".png" { "image/png" }
        ".jpg" { "image/jpeg" }
        ".jpeg" { "image/jpeg" }
        ".gif" { "image/gif" }
        ".webp" { "image/webp" }
        default { "image/png" }
    }

    return @{
        Base64 = $base64
        MimeType = $mimeType
        DataUrl = "data:$mimeType;base64,$base64"
    }
}

Write-Host "[*] Mode: $Mode" -ForegroundColor Cyan
Write-Host "    Model: $Model" -ForegroundColor Gray
Write-Host "    Size: $Size" -ForegroundColor Gray

# MODE 1: VISION-ENHANCED (Analyze references with GPT-4 Vision, then generate)
if ($Mode -eq "vision-enhanced") {
    Write-Host "[*] Analyzing reference images with GPT-4 Vision..." -ForegroundColor Cyan

    # Build vision messages
    $visionMessages = @(
        @{
            role = "user"
            content = @()
        }
    )

    # Add text instruction
    $visionMessages[0].content += @{
        type = "text"
        text = "I want to generate an image with this description: `"$Prompt`". I'm providing reference images to guide the generation. Please analyze these references and create a detailed, comprehensive prompt for DALL-E that incorporates the visual elements, style, composition, colors, and mood from these references. Be specific and descriptive."
    }

    # Add reference images
    for ($i = 0; $i -lt $ReferenceImages.Count; $i++) {
        $refPath = $ReferenceImages[$i]
        $refDesc = if ($i -lt $ReferenceDescriptions.Count) { $ReferenceDescriptions[$i] } else { "Reference image $($i+1)" }

        Write-Host "    Reference $($i+1): $refPath" -ForegroundColor Gray
        Write-Host "    Description: $refDesc" -ForegroundColor Gray

        $imageData = ConvertTo-Base64Image -ImagePath $refPath

        # Add description of this reference
        $visionMessages[0].content += @{
            type = "text"
            text = "`n`nReference Image $($i+1): $refDesc"
        }

        # Add the image
        $visionMessages[0].content += @{
            type = "image_url"
            image_url = @{
                url = $imageData.DataUrl
            }
        }
    }

    # Call GPT-4 Vision
    $visionBody = @{
        model = "gpt-4-vision-preview"
        messages = $visionMessages
        max_tokens = 1000
    } | ConvertTo-Json -Depth 10

    $visionHeaders = @{
        "Authorization" = "Bearer $ApiKey"
        "Content-Type" = "application/json"
    }

    try {
        $visionResponse = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" `
            -Method Post -Headers $visionHeaders -Body $visionBody

        $enhancedPrompt = $visionResponse.choices[0].message.content
        Write-Host "[+] Enhanced prompt generated:" -ForegroundColor Green
        Write-Host "    $enhancedPrompt" -ForegroundColor Gray

        # Use enhanced prompt for DALL-E generation
        $Prompt = $enhancedPrompt

    } catch {
        Write-Host "[!] Vision analysis failed, using original prompt" -ForegroundColor Yellow
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Continue to DALL-E generation with enhanced prompt
    $Mode = "generate"
}

# MODE 2: IMAGE EDITS (DALL-E 2 Inpainting)
if ($Mode -eq "edit") {
    Write-Host "[*] Generating image edit (inpainting)..." -ForegroundColor Cyan
    Write-Host "    Source: $SourceImage" -ForegroundColor Gray
    Write-Host "    Mask: $MaskImage" -ForegroundColor Gray
    Write-Host "    Prompt: $Prompt" -ForegroundColor Gray

    $apiUrl = "https://api.openai.com/v1/images/edits"

    # Prepare multipart form data
    $boundary = [System.Guid]::NewGuid().ToString()
    $headers = @{
        "Authorization" = "Bearer $ApiKey"
        "Content-Type" = "multipart/form-data; boundary=$boundary"
    }

    # Build multipart body
    $bodyLines = @()

    # Add image file
    $imageBytes = [System.IO.File]::ReadAllBytes($SourceImage)
    $imageFileName = [System.IO.Path]::GetFileName($SourceImage)
    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"image`"; filename=`"$imageFileName`""
    $bodyLines += "Content-Type: image/png"
    $bodyLines += ""
    $bodyLines += [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($imageBytes)

    # Add mask file
    $maskBytes = [System.IO.File]::ReadAllBytes($MaskImage)
    $maskFileName = [System.IO.Path]::GetFileName($MaskImage)
    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"mask`"; filename=`"$maskFileName`""
    $bodyLines += "Content-Type: image/png"
    $bodyLines += ""
    $bodyLines += [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($maskBytes)

    # Add prompt
    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"prompt`""
    $bodyLines += ""
    $bodyLines += $Prompt

    # Add n (number of images)
    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"n`""
    $bodyLines += ""
    $bodyLines += "1"

    # Add size
    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"size`""
    $bodyLines += ""
    $bodyLines += $Size

    # Add response_format
    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"response_format`""
    $bodyLines += ""
    $bodyLines += "url"

    $bodyLines += "--$boundary--"

    $body = [System.Text.Encoding]::GetEncoding("iso-8859-1").GetBytes(($bodyLines -join "`r`n"))

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $body
        $imageUrl = $response.data[0].url

        Write-Host "[+] Image edited successfully" -ForegroundColor Green
        Write-Host "[*] Downloading image..." -ForegroundColor Cyan

        Invoke-WebRequest -Uri $imageUrl -OutFile $OutputPath

        $fileInfo = Get-Item $OutputPath
        Write-Host "[+] Image saved to: $OutputPath" -ForegroundColor Green
        Write-Host "    Size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray

        exit 0

    } catch {
        Write-Host "[!] Error editing image:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

# MODE 3: IMAGE VARIATIONS (DALL-E 2)
if ($Mode -eq "variation") {
    Write-Host "[*] Generating image variation..." -ForegroundColor Cyan
    Write-Host "    Source: $SourceImage" -ForegroundColor Gray

    $apiUrl = "https://api.openai.com/v1/images/variations"

    # Prepare multipart form data (similar to edit mode but without mask/prompt)
    $boundary = [System.Guid]::NewGuid().ToString()
    $headers = @{
        "Authorization" = "Bearer $ApiKey"
        "Content-Type" = "multipart/form-data; boundary=$boundary"
    }

    $bodyLines = @()

    # Add image file
    $imageBytes = [System.IO.File]::ReadAllBytes($SourceImage)
    $imageFileName = [System.IO.Path]::GetFileName($SourceImage)
    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"image`"; filename=`"$imageFileName`""
    $bodyLines += "Content-Type: image/png"
    $bodyLines += ""
    $bodyLines += [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($imageBytes)

    # Add parameters
    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"n`""
    $bodyLines += ""
    $bodyLines += "1"

    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"size`""
    $bodyLines += ""
    $bodyLines += $Size

    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"response_format`""
    $bodyLines += ""
    $bodyLines += "url"

    $bodyLines += "--$boundary--"

    $body = [System.Text.Encoding]::GetEncoding("iso-8859-1").GetBytes(($bodyLines -join "`r`n"))

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $body
        $imageUrl = $response.data[0].url

        Write-Host "[+] Image variation generated successfully" -ForegroundColor Green
        Write-Host "[*] Downloading image..." -ForegroundColor Cyan

        Invoke-WebRequest -Uri $imageUrl -OutFile $OutputPath

        $fileInfo = Get-Item $OutputPath
        Write-Host "[+] Image saved to: $OutputPath" -ForegroundColor Green
        Write-Host "    Size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray

        exit 0

    } catch {
        Write-Host "[!] Error generating variation:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

# MODE 4: TEXT-TO-IMAGE GENERATION (DALL-E 2 or 3)
if ($Mode -eq "generate") {
    Write-Host "[*] Generating image from text..." -ForegroundColor Cyan
    Write-Host "    Prompt: $Prompt" -ForegroundColor Gray

    $apiUrl = "https://api.openai.com/v1/images/generations"
    $headers = @{
        "Authorization" = "Bearer $ApiKey"
        "Content-Type" = "application/json"
    }

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

    try {
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

        Invoke-WebRequest -Uri $imageUrl -OutFile $OutputPath

        $fileInfo = Get-Item $OutputPath
        Write-Host "[+] Image saved to: $OutputPath" -ForegroundColor Green
        Write-Host "    Size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray

        exit 0

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
}
