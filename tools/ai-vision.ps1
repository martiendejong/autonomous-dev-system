<#
.SYNOPSIS
    Ask questions about images using AI vision models

.DESCRIPTION
    Analyze images and answer questions using multimodal AI models:
    - OpenAI (GPT-4 Vision, GPT-4 Turbo, GPT-4o)
    - Google (Gemini Vision Pro)
    - Anthropic (Claude 3 Opus/Sonnet/Haiku)
    - Azure OpenAI (GPT-4 Vision)

    Supports single or multiple images with text prompts.

.PARAMETER Provider
    AI provider: openai (default), google, anthropic, azure

.PARAMETER Images
    Array of image file paths to analyze

.PARAMETER Prompt
    Question or instruction about the image(s)

.PARAMETER Model
    Model name (provider-specific):
    - openai: gpt-4-vision-preview, gpt-4-turbo, gpt-4o (default)
    - google: gemini-pro-vision, gemini-1.5-pro
    - anthropic: claude-3-opus, claude-3-sonnet, claude-3-haiku
    - azure: gpt-4-vision

.PARAMETER ApiKey
    API key (optional, auto-loaded from appsettings if not provided)

.PARAMETER MaxTokens
    Maximum tokens in response (default: 1000)

.PARAMETER Temperature
    Creativity level 0-2 (default: 0.7)

.PARAMETER DetailLevel
    Image detail level (OpenAI only): low, high, auto (default: auto)

.PARAMETER OutputFormat
    Output format: text (default), json, markdown

.EXAMPLE
    # Simple question about one image
    .\ai-vision.ps1 -Images @("photo.png") -Prompt "What do you see in this image?"

.EXAMPLE
    # Multiple images comparison
    .\ai-vision.ps1 -Images @("before.png", "after.png") `
        -Prompt "What are the differences between these two images?"

.EXAMPLE
    # Google Gemini for Asian content
    .\ai-vision.ps1 -Provider google -Images @("sign.jpg") `
        -Prompt "Translate the text in this image"

.EXAMPLE
    # Detailed analysis with high detail
    .\ai-vision.ps1 -Images @("diagram.png") `
        -Prompt "Explain this architecture diagram in detail" `
        -DetailLevel high -MaxTokens 2000

.EXAMPLE
    # JSON structured output
    .\ai-vision.ps1 -Images @("receipt.jpg") `
        -Prompt "Extract items, prices, and total as JSON" `
        -OutputFormat json

.EXAMPLE
    # Multiple images with context
    .\ai-vision.ps1 -Images @("error1.png", "error2.png", "code.png") `
        -Prompt "Based on these error screenshots and code, what's the bug?"

.NOTES
    Created: 2026-01-25
    API keys auto-loaded from appsettings.Secrets.json
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("openai", "google", "anthropic", "azure")]
    [string]$Provider = "openai",

    [Parameter(Mandatory=$true)]
    [string[]]$Images,

    [Parameter(Mandatory=$true)]
    [string]$Prompt,

    [Parameter(Mandatory=$false)]
    [string]$Model = "",

    [Parameter(Mandatory=$false)]
    [string]$ApiKey = "",

    [Parameter(Mandatory=$false)]
    [int]$MaxTokens = 1000,

    [Parameter(Mandatory=$false)]
    [double]$Temperature = 0.7,

    [Parameter(Mandatory=$false)]
    [ValidateSet("low", "high", "auto")]
    [string]$DetailLevel = "auto",

    [Parameter(Mandatory=$false)]
    [ValidateSet("text", "json", "markdown")]
    [string]$OutputFormat = "text"
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
                        Write-Error "OpenAI API key not found in secrets file"
                        exit 1
                    }
                    Write-Host "[*] Loaded OpenAI API key from secrets" -ForegroundColor Gray
                }
                "google" {
                    $ApiKey = $secrets.ApiSettings.GoogleGeminiKey
                    if (-not $ApiKey) {
                        Write-Error "Google Gemini key not found in secrets file"
                        exit 1
                    }
                    Write-Host "[*] Loaded Google API key from secrets" -ForegroundColor Gray
                }
                "anthropic" {
                    $ApiKey = $secrets.ApiSettings.AnthropicKey
                    if (-not $ApiKey) {
                        Write-Error "Anthropic key not found in secrets file"
                        exit 1
                    }
                    Write-Host "[*] Loaded Anthropic API key from secrets" -ForegroundColor Gray
                }
                "azure" {
                    $ApiKey = $secrets.ApiSettings.AzureOpenAiKey
                    if (-not $ApiKey) {
                        Write-Error "Azure OpenAI key not found in secrets file"
                        exit 1
                    }
                    Write-Host "[*] Loaded Azure OpenAI key from secrets" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Error "Failed to load API key: $_"
            exit 1
        }
    } else {
        Write-Error "API key required. Provide -ApiKey parameter or ensure appsettings.Secrets.json exists"
        exit 1
    }
}

# Auto-select model based on provider if not specified
if (-not $Model) {
    switch ($Provider) {
        "openai" { $Model = "gpt-4o" }
        "google" { $Model = "gemini-1.5-pro" }
        "anthropic" { $Model = "claude-3-sonnet-20240229" }
        "azure" { $Model = "gpt-4-vision" }
    }
}

# Validate images exist
foreach ($imagePath in $Images) {
    if (-not (Test-Path $imagePath)) {
        Write-Error "Image not found: $imagePath"
        exit 1
    }
}

Write-Host "[*] Provider: $Provider" -ForegroundColor Cyan
Write-Host "    Model: $Model" -ForegroundColor Gray
Write-Host "    Images: $($Images.Count)" -ForegroundColor Gray
Write-Host "    Prompt: $Prompt" -ForegroundColor Gray

# Helper function: Convert image to base64
function ConvertTo-Base64Image {
    param([string]$ImagePath)

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

# Provider-specific implementation
switch ($Provider) {
    "openai" {
        Write-Host "[*] Analyzing with OpenAI Vision..." -ForegroundColor Cyan

        $apiUrl = "https://api.openai.com/v1/chat/completions"
        $headers = @{
            "Authorization" = "Bearer $ApiKey"
            "Content-Type" = "application/json"
        }

        # Build messages with images
        $content = @()

        # Add text prompt
        $content += @{
            type = "text"
            text = $Prompt
        }

        # Add images
        foreach ($imagePath in $Images) {
            Write-Host "    Processing: $imagePath" -ForegroundColor Gray
            $imageData = ConvertTo-Base64Image -ImagePath $imagePath

            $content += @{
                type = "image_url"
                image_url = @{
                    url = $imageData.DataUrl
                    detail = $DetailLevel
                }
            }
        }

        $body = @{
            model = $Model
            messages = @(
                @{
                    role = "user"
                    content = $content
                }
            )
            max_tokens = $MaxTokens
            temperature = $Temperature
        }

        if ($OutputFormat -eq "json") {
            $body.response_format = @{ type = "json_object" }
        }

        $jsonBody = $body | ConvertTo-Json -Depth 10

        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $jsonBody

            $answer = $response.choices[0].message.content

            Write-Host "`n[+] Analysis complete:" -ForegroundColor Green
            Write-Host $answer
            Write-Host "`n[*] Tokens used: $($response.usage.total_tokens)" -ForegroundColor Gray

            # Return structured output
            return @{
                Answer = $answer
                Provider = $Provider
                Model = $Model
                TokensUsed = $response.usage.total_tokens
                ImagesAnalyzed = $Images.Count
            }

        } catch {
            Write-Host "[!] Error analyzing images:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }

    "google" {
        Write-Host "[*] Analyzing with Google Gemini Vision..." -ForegroundColor Cyan

        $apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/$($Model):generateContent?key=$ApiKey"
        $headers = @{
            "Content-Type" = "application/json"
        }

        # Build parts with images and text
        $parts = @()

        # Add text prompt
        $parts += @{
            text = $Prompt
        }

        # Add images
        foreach ($imagePath in $Images) {
            Write-Host "    Processing: $imagePath" -ForegroundColor Gray
            $imageData = ConvertTo-Base64Image -ImagePath $imagePath

            $parts += @{
                inline_data = @{
                    mime_type = $imageData.MimeType
                    data = $imageData.Base64
                }
            }
        }

        $body = @{
            contents = @(
                @{
                    parts = $parts
                }
            )
            generationConfig = @{
                temperature = $Temperature
                maxOutputTokens = $MaxTokens
            }
        }

        $jsonBody = $body | ConvertTo-Json -Depth 10

        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $jsonBody

            $answer = $response.candidates[0].content.parts[0].text

            Write-Host "`n[+] Analysis complete:" -ForegroundColor Green
            Write-Host $answer

            return @{
                Answer = $answer
                Provider = $Provider
                Model = $Model
                ImagesAnalyzed = $Images.Count
            }

        } catch {
            Write-Host "[!] Error analyzing images:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }

    "anthropic" {
        Write-Host "[*] Analyzing with Anthropic Claude Vision..." -ForegroundColor Cyan

        $apiUrl = "https://api.anthropic.com/v1/messages"
        $headers = @{
            "x-api-key" = $ApiKey
            "anthropic-version" = "2023-06-01"
            "Content-Type" = "application/json"
        }

        # Build content with images
        $content = @()

        # Add images first (Claude convention)
        foreach ($imagePath in $Images) {
            Write-Host "    Processing: $imagePath" -ForegroundColor Gray
            $imageData = ConvertTo-Base64Image -ImagePath $imagePath

            $content += @{
                type = "image"
                source = @{
                    type = "base64"
                    media_type = $imageData.MimeType
                    data = $imageData.Base64
                }
            }
        }

        # Add text prompt
        $content += @{
            type = "text"
            text = $Prompt
        }

        $body = @{
            model = $Model
            max_tokens = $MaxTokens
            temperature = $Temperature
            messages = @(
                @{
                    role = "user"
                    content = $content
                }
            )
        }

        $jsonBody = $body | ConvertTo-Json -Depth 10

        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $jsonBody

            $answer = $response.content[0].text

            Write-Host "`n[+] Analysis complete:" -ForegroundColor Green
            Write-Host $answer
            Write-Host "`n[*] Tokens used: Input: $($response.usage.input_tokens), Output: $($response.usage.output_tokens)" -ForegroundColor Gray

            return @{
                Answer = $answer
                Provider = $Provider
                Model = $Model
                TokensUsed = $response.usage.input_tokens + $response.usage.output_tokens
                ImagesAnalyzed = $Images.Count
            }

        } catch {
            Write-Host "[!] Error analyzing images:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }

    "azure" {
        Write-Host "[*] Analyzing with Azure OpenAI Vision..." -ForegroundColor Cyan

        # Azure OpenAI endpoint
        $azureEndpoint = $secrets.AzureOpenAI.Endpoint
        $deploymentName = $secrets.AzureOpenAI.VisionDeployment
        $apiUrl = "$azureEndpoint/openai/deployments/$deploymentName/chat/completions?api-version=2024-02-01"

        $headers = @{
            "api-key" = $ApiKey
            "Content-Type" = "application/json"
        }

        # Build messages (same as OpenAI)
        $content = @()

        $content += @{
            type = "text"
            text = $Prompt
        }

        foreach ($imagePath in $Images) {
            Write-Host "    Processing: $imagePath" -ForegroundColor Gray
            $imageData = ConvertTo-Base64Image -ImagePath $imagePath

            $content += @{
                type = "image_url"
                image_url = @{
                    url = $imageData.DataUrl
                }
            }
        }

        $body = @{
            messages = @(
                @{
                    role = "user"
                    content = $content
                }
            )
            max_tokens = $MaxTokens
            temperature = $Temperature
        }

        $jsonBody = $body | ConvertTo-Json -Depth 10

        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $jsonBody

            $answer = $response.choices[0].message.content

            Write-Host "`n[+] Analysis complete:" -ForegroundColor Green
            Write-Host $answer

            return @{
                Answer = $answer
                Provider = $Provider
                Model = $Model
                TokensUsed = $response.usage.total_tokens
                ImagesAnalyzed = $Images.Count
            }

        } catch {
            Write-Host "[!] Error analyzing images:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }
}
