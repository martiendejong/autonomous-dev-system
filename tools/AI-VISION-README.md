# AI Vision - Ask Questions About Images

## Overview

Universal AI vision system for analyzing images and answering questions using multimodal AI models.

### 🔍 Supported Providers

| Provider | Models | Strengths |
|----------|--------|-----------|
| **OpenAI** | GPT-4o, GPT-4 Vision, GPT-4 Turbo | Best accuracy, detailed descriptions |
| **Google** | Gemini 1.5 Pro, Gemini Pro Vision | Fast, multilingual, OCR |
| **Anthropic** | Claude 3 Opus/Sonnet/Haiku | Thoughtful analysis, context |
| **Azure OpenAI** | GPT-4 Vision | Enterprise, compliance |

---

## Quick Start

### Single Image Analysis

```powershell
.\ai-vision.ps1 -Images @("photo.jpg") `
    -Prompt "What do you see in this image?"
```

### Multiple Images Comparison

```powershell
.\ai-vision.ps1 -Images @("before.png", "after.png") `
    -Prompt "What are the differences between these images?"
```

---

## Common Use Cases

### 1. Image Description

```powershell
.\ai-vision.ps1 -Images @("product.jpg") `
    -Prompt "Describe this product in detail for a product listing"
```

### 2. Text Extraction (OCR)

```powershell
.\ai-vision.ps1 -Images @("document.png") `
    -Prompt "Extract all text from this document"
```

### 3. Code Analysis from Screenshots

```powershell
.\ai-vision.ps1 -Images @("code-screenshot.png") `
    -Prompt "What does this code do? Are there any bugs?"
```

### 4. Error Debugging

```powershell
.\ai-vision.ps1 -Images @("error-screen1.png", "error-screen2.png") `
    -Prompt "Based on these error screenshots, what's the root cause?"
```

### 5. Design Feedback

```powershell
.\ai-vision.ps1 -Images @("mockup.png") `
    -Prompt "Review this UI design. What improvements would you suggest?"
```

### 6. Translation

```powershell
.\ai-vision.ps1 -Provider google -Images @("sign.jpg") `
    -Prompt "Translate all text in this image to English"
```

### 7. Data Extraction

```powershell
.\ai-vision.ps1 -Images @("receipt.jpg") `
    -Prompt "Extract items, quantities, and prices as JSON" `
    -OutputFormat json
```

### 8. Comparison Analysis

```powershell
.\ai-vision.ps1 -Images @("version1.png", "version2.png", "version3.png") `
    -Prompt "Compare these 3 design versions. Which is best and why?"
```

### 9. Architecture Diagram Explanation

```powershell
.\ai-vision.ps1 -Images @("architecture.png") `
    -Prompt "Explain this system architecture diagram in detail" `
    -MaxTokens 2000
```

### 10. Accessibility Check

```powershell
.\ai-vision.ps1 -Images @("website-screenshot.png") `
    -Prompt "Analyze this webpage for accessibility issues"
```

---

## Advanced Examples

### High Detail Analysis

```powershell
.\ai-vision.ps1 -Images @("complex-diagram.png") `
    -Prompt "Analyze every detail in this diagram" `
    -DetailLevel high -MaxTokens 3000
```

### JSON Structured Output

```powershell
.\ai-vision.ps1 -Images @("form.png") `
    -Prompt "Extract all form fields and values as JSON" `
    -OutputFormat json
```

### Multiple Error Screenshots Analysis

```powershell
$errorImages = @(
    "error-frontend.png",
    "error-backend.png",
    "logs.png",
    "code-snippet.png"
)

.\ai-vision.ps1 -Images $errorImages `
    -Prompt "Based on these screenshots, identify the bug and suggest a fix" `
    -MaxTokens 2000
```

### Provider-Specific

```powershell
# Google Gemini for multilingual OCR
.\ai-vision.ps1 -Provider google -Images @("chinese-text.jpg") `
    -Prompt "Translate this Chinese text to English"

# Claude for thoughtful analysis
.\ai-vision.ps1 -Provider anthropic -Model claude-3-opus-20240229 `
    -Images @("artwork.jpg") `
    -Prompt "Provide a deep art critique of this piece"

# Azure for enterprise
.\ai-vision.ps1 -Provider azure -Images @("document.png") `
    -Prompt "Extract and classify PII from this document"
```

---

## Complete Parameter Reference

### Universal Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `Provider` | string | openai, google, anthropic, azure | openai |
| `Images` | array | Paths to images (required) | - |
| `Prompt` | string | Question/instruction (required) | - |
| `Model` | string | Provider-specific model | Auto-selected |
| `ApiKey` | string | API key (auto-loaded if empty) | - |
| `MaxTokens` | int | Maximum response length | 1000 |
| `Temperature` | double | Creativity 0-2 | 0.7 |

### OpenAI/Azure Specific

| Parameter | Values | Description |
|-----------|--------|-------------|
| `DetailLevel` | low, high, auto | Image detail level |

### Output Options

| Parameter | Values | Description |
|-----------|--------|-------------|
| `OutputFormat` | text, json, markdown | Response format |

---

## Model Selection Guide

### OpenAI Models

```powershell
# GPT-4o (default, recommended)
-Model gpt-4o

# GPT-4 Vision (original)
-Model gpt-4-vision-preview

# GPT-4 Turbo
-Model gpt-4-turbo
```

### Google Models

```powershell
# Gemini 1.5 Pro (default, best)
-Model gemini-1.5-pro

# Gemini Pro Vision (legacy)
-Model gemini-pro-vision
```

### Anthropic Models

```powershell
# Claude 3 Opus (most capable)
-Model claude-3-opus-20240229

# Claude 3 Sonnet (balanced, default)
-Model claude-3-sonnet-20240229

# Claude 3 Haiku (fast, cheap)
-Model claude-3-haiku-20240307
```

---

## Provider Selection Guide

### When to use OpenAI GPT-4o:
✅ Best overall accuracy
✅ Detailed descriptions
✅ Code analysis
✅ General purpose
✅ English content

### When to use Google Gemini:
✅ Multilingual OCR
✅ Asian languages
✅ Fast processing
✅ Document analysis
✅ Translation

### When to use Anthropic Claude:
✅ Thoughtful analysis
✅ Long context
✅ Creative interpretation
✅ Art critique
✅ Ethical considerations

### When to use Azure OpenAI:
✅ Enterprise requirements
✅ Data residency
✅ Compliance needs
✅ SLA guarantees

---

## Tips & Best Practices

### Image Quality

**For best results:**
- High resolution images (min 512x512)
- Clear, well-lit photos
- Avoid blurry or pixelated images
- PNG or JPEG format

### Prompts

**Be specific:**
```
❌ "What is this?"
✅ "Describe the architectural style of this building, including materials, design elements, and historical period"
```

**For structured data:**
```
✅ "Extract all text as JSON with fields: title, subtitle, body, date"
```

**For comparisons:**
```
✅ "Compare these images focusing on: color scheme, composition, style, mood"
```

### Multiple Images

**Best practices:**
- Group related images (max 4-6 for clarity)
- Specify which image is which if order matters
- Use for: comparisons, sequences, different angles
- More images = more tokens used

### Token Management

**Estimate tokens:**
- Simple description: 200-500 tokens
- Detailed analysis: 500-1500 tokens
- JSON extraction: 300-1000 tokens
- Multiple images: +500 tokens per image

**Adjust MaxTokens:**
```powershell
# Quick answer
-MaxTokens 500

# Detailed analysis
-MaxTokens 2000

# Comprehensive report
-MaxTokens 3000
```

### Temperature Settings

```powershell
# Factual, precise (OCR, data extraction)
-Temperature 0.0

# Balanced (default, descriptions)
-Temperature 0.7

# Creative (art critique, storytelling)
-Temperature 1.2
```

---

## Real-World Workflows

### Bug Debugging Workflow

```powershell
# Step 1: Analyze error screenshots
$result = .\ai-vision.ps1 `
    -Images @("error1.png", "error2.png", "stacktrace.png") `
    -Prompt "Identify the error and probable cause"

# Step 2: Review code
$codeReview = .\ai-vision.ps1 `
    -Images @("code-screenshot.png") `
    -Prompt "Based on the error: $($result.Answer), review this code for the bug"

# Step 3: Get fix suggestion
Write-Host "Suggested fix: $($codeReview.Answer)"
```

### Document Processing Pipeline

```powershell
# Extract text
$text = .\ai-vision.ps1 -Images @("invoice.pdf") `
    -Prompt "Extract all text exactly as written" | Select-Object -ExpandProperty Answer

# Parse structured data
$data = .\ai-vision.ps1 -Images @("invoice.pdf") `
    -Prompt "Extract invoice data: invoice_number, date, total, items (name, qty, price)" `
    -OutputFormat json

# Validate
$validation = .\ai-vision.ps1 -Images @("invoice.pdf") `
    -Prompt "Check if this invoice is valid and complete. List any issues."
```

### UI/UX Review Process

```powershell
# Accessibility audit
$a11y = .\ai-vision.ps1 -Images @("page.png") `
    -Prompt "Audit this page for WCAG 2.1 AA compliance"

# Design critique
$design = .\ai-vision.ps1 -Provider anthropic `
    -Images @("page.png") `
    -Prompt "Critique the design: layout, colors, typography, spacing"

# Comparison with competitors
$compare = .\ai-vision.ps1 `
    -Images @("our-site.png", "competitor1.png", "competitor2.png") `
    -Prompt "Compare our design to competitors. What can we improve?"
```

---

## API Key Configuration

**Auto-loaded from:**
```
C:\Projects\client-manager\ClientManagerAPI\appsettings.Secrets.json
```

**Required structure:**

```json
{
  "ApiSettings": {
    "OpenApiKey": "sk-...",
    "GoogleGeminiKey": "AIza...",
    "AnthropicKey": "sk-ant-...",
    "AzureOpenAiKey": "..."
  },
  "AzureOpenAI": {
    "Endpoint": "https://your-resource.openai.azure.com/",
    "VisionDeployment": "gpt-4-vision"
  }
}
```

---

## Troubleshooting

### Error: "API key not found"
**Solution:** Add API key to appsettings.Secrets.json or pass via `-ApiKey` parameter

### Error: "Image too large"
**Solution:** Resize image to max 20MB (OpenAI), 4MB (Google)

### Error: "Invalid image format"
**Solution:** Use PNG, JPEG, GIF, or WEBP format

### Low quality responses
**Try:**
1. Higher quality images
2. More specific prompts
3. Higher MaxTokens
4. DetailLevel "high" (OpenAI)
5. Different provider

### Multiple images not compared
**Fix:** Explicitly mention "compare", "differences", "all images" in prompt

---

## Integration with Image Generation

**Combined workflow:**

```powershell
# Generate image
.\ai-image.ps1 -Prompt "A modern office interior" `
    -OutputPath "office.png" -Quality hd

# Analyze generated image
$analysis = .\ai-vision.ps1 -Images @("office.png") `
    -Prompt "Does this image match the prompt 'modern office interior'? What's missing?"

# Regenerate based on feedback
.\ai-image.ps1 -Prompt "A modern office interior. $($analysis.Answer)" `
    -OutputPath "office-v2.png" -Quality hd
```

---

## Performance

**Token usage estimates:**

| Task | Images | Typical Tokens |
|------|--------|----------------|
| Simple description | 1 | 200-400 |
| Detailed analysis | 1 | 500-1500 |
| OCR extraction | 1 | 300-800 |
| Multi-image compare | 2-3 | 800-2000 |
| Code review | 1-2 | 500-1200 |

**Cost estimates (OpenAI GPT-4o):**
- Input: ~$2.50 per 1M tokens
- Output: ~$10 per 1M tokens
- Image: ~$0.003 per image (low detail), ~$0.01 (high detail)

---

## Future Enhancements

**Planned features:**
- [ ] Video analysis (frame extraction)
- [ ] Batch processing (multiple image sets)
- [ ] Comparison reports (before/after)
- [ ] Automated bug reports from screenshots
- [ ] Integration with issue tracking
- [ ] Image quality scoring
- [ ] Automatic categorization

---

**Last Updated:** 2026-01-25
**Maintained By:** Claude Agent (Self-improving system)
