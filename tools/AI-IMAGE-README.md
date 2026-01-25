# AI Image Generation - Complete Guide

## Overview

Universal AI image generation system supporting **all major providers** and **all operation modes**.

### 🎨 Supported Providers

| Provider | Models | Strengths |
|----------|--------|-----------|
| **OpenAI** | DALL-E 2, DALL-E 3 | Best prompt understanding, highest quality |
| **Google** | Imagen 2, Imagen 3 | Fast, photorealistic, good Asian content |
| **Stability AI** | SD-XL, SD-3 | Open source, fine control, reproducible |
| **Azure OpenAI** | DALL-E 2, DALL-E 3 | Enterprise, compliance, private deployment |

### 🛠️ Supported Modes

| Mode | Description | Providers |
|------|-------------|-----------|
| **generate** | Text-to-image | All providers |
| **edit** | Inpainting (edit masked areas) | OpenAI DALL-E 2 |
| **variation** | Create variations of image | OpenAI DALL-E 2 |
| **vision-enhanced** | Analyze references → generate | All providers |

---

## Quick Start

### Simple Generation (Default: OpenAI DALL-E 3)

```powershell
.\ai-image.ps1 -Prompt "A sunset over mountains" -OutputPath "sunset.png"
```

### With Provider Selection

```powershell
# Google Imagen
.\ai-image.ps1 -Provider google -Prompt "A cat in Tokyo" -OutputPath "cat.png"

# Stability AI
.\ai-image.ps1 -Provider stability -Prompt "Cyberpunk city" -OutputPath "city.png"

# Azure OpenAI
.\ai-image.ps1 -Provider azure -Prompt "Abstract art" -OutputPath "art.png"
```

---

## Advanced Usage

### 1. Vision-Enhanced Generation

**Use reference images to guide generation:**

```powershell
.\ai-image.ps1 -Mode vision-enhanced `
    -ReferenceImages @("style-reference.png", "color-palette.png", "composition.png") `
    -ReferenceDescriptions @(
        "Match this artistic style and brush technique",
        "Use this exact color palette",
        "Follow this composition and framing"
    ) `
    -Prompt "A mountain landscape at sunrise" `
    -OutputPath "landscape.png"
```

**How it works:**
1. GPT-4 Vision analyzes each reference image with your description
2. Generates detailed, comprehensive prompt incorporating all references
3. Passes enhanced prompt to image generation model
4. Result: Image matching style, colors, and composition of references

### 2. Image Editing (Inpainting)

**Edit specific areas of an existing image:**

```powershell
.\ai-image.ps1 -Mode edit `
    -SourceImage "room.png" `
    -MaskImage "mask.png" `
    -Prompt "A red sofa in the masked area" `
    -OutputPath "room-edited.png"
```

**Requirements:**
- Source image: Original photo (PNG, square size)
- Mask image: Same size, transparent where you want changes, opaque elsewhere
- Provider: OpenAI DALL-E 2 only

### 3. Image Variations

**Create variations of an existing image:**

```powershell
.\ai-image.ps1 -Mode variation `
    -SourceImage "logo.png" `
    -OutputPath "logo-variation.png"
```

**Use cases:**
- Logo variations
- Alternative compositions
- Style experiments
- A/B testing visuals

### 4. Provider-Specific Features

#### Google Imagen - Negative Prompts

```powershell
.\ai-image.ps1 -Provider google `
    -Prompt "A beautiful garden" `
    -NegativePrompt "people, buildings, cars, urban" `
    -OutputPath "garden.png"
```

#### Stability AI - Fine Control

```powershell
.\ai-image.ps1 -Provider stability `
    -Prompt "A dragon in flight" `
    -NegativePrompt "blurry, low quality, distorted" `
    -GuidanceScale 15 `
    -Steps 50 `
    -Seed 42 `
    -OutputPath "dragon.png"
```

**Parameters:**
- `GuidanceScale` (1-20): How closely to follow prompt (higher = more accurate, default 7)
- `Steps` (10-150): Quality vs speed (higher = better quality, default 30)
- `Seed`: For reproducibility (same seed = same image)

#### OpenAI DALL-E 3 - Quality & Style

```powershell
.\ai-image.ps1 -Provider openai -Model dall-e-3 `
    -Prompt "A professional product photo" `
    -Quality hd `
    -Style natural `
    -Size 1792x1024 `
    -OutputPath "product.png"
```

**Parameters:**
- `Quality`: standard (default, fast) | hd (production quality)
- `Style`: vivid (dramatic, colorful) | natural (realistic, subdued)
- `Size`: 1024x1024 (square) | 1024x1792 (portrait) | 1792x1024 (landscape)

---

## Complete Parameter Reference

### Universal Parameters (All Providers)

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `Provider` | string | openai, google, stability, azure | openai |
| `Mode` | string | generate, edit, variation, vision-enhanced | generate |
| `Prompt` | string | Text description (required for most modes) | - |
| `OutputPath` | string | Output file path (required) | - |
| `Model` | string | Provider-specific model name | Auto-selected |
| `Size` | string | Image dimensions (format varies by provider) | 1024x1024 |

### OpenAI / Azure Specific

| Parameter | Values | Description |
|-----------|--------|-------------|
| `Quality` | standard, hd | Image quality (DALL-E 3 only) |
| `Style` | vivid, natural | Image style (DALL-E 3 only) |

### Google / Stability Specific

| Parameter | Type | Range | Description |
|-----------|------|-------|-------------|
| `NegativePrompt` | string | - | What NOT to include |
| `GuidanceScale` | int | 1-20 | Prompt adherence (default 7) |

### Stability AI Specific

| Parameter | Type | Range | Description |
|-----------|------|-------|-------------|
| `Steps` | int | 10-150 | Diffusion steps (default 30) |
| `Seed` | int | any | Random seed for reproducibility |

### Vision-Enhanced Specific

| Parameter | Type | Description |
|-----------|------|-------------|
| `ReferenceImages` | array | Paths to reference images |
| `ReferenceDescriptions` | array | How each reference relates to output |

### Edit Mode Specific

| Parameter | Type | Description |
|-----------|------|-------------|
| `SourceImage` | string | Original image path |
| `MaskImage` | string | Mask image path (transparent = edit area) |

### Variation Mode Specific

| Parameter | Type | Description |
|-----------|------|-------------|
| `SourceImage` | string | Original image to vary |

---

## API Key Configuration

**API keys are automatically loaded from:**
```
C:\Projects\client-manager\ClientManagerAPI\appsettings.Secrets.json
```

**Required structure:**

```json
{
  "ApiSettings": {
    "OpenApiKey": "sk-...",
    "GoogleImagenKey": "ya29...",
    "StabilityAiKey": "sk-...",
    "AzureOpenAiKey": "..."
  },
  "GoogleCloud": {
    "ProjectId": "your-project-id"
  },
  "AzureOpenAI": {
    "Endpoint": "https://your-resource.openai.azure.com/",
    "DalleDeployment": "dalle3"
  }
}
```

**Manual API key override:**

```powershell
.\ai-image-universal.ps1 -Provider openai -ApiKey "sk-..." -Prompt "..." -OutputPath "..."
```

---

## Use Cases & Examples

### Marketing Materials

```powershell
# Blog header
.\ai-image.ps1 -Prompt "Professional tech blog header, modern, blue gradient" `
    -Size 1792x1024 -Quality hd -OutputPath "blog-header.png"

# Social media post
.\ai-image.ps1 -Provider google -Prompt "Product announcement, exciting, vibrant" `
    -Size 1024x1024 -OutputPath "social-post.png"
```

### UI/UX Design

```powershell
# Empty state illustration
.\ai-image.ps1 -Prompt "Friendly robot looking at empty folder, minimalist" `
    -Style natural -OutputPath "empty-state.png"

# Error illustration
.\ai-image.ps1 -Prompt "Broken connection visualization, simple, professional" `
    -OutputPath "error-404.png"
```

### Product Development

```powershell
# Feature mockup with reference style
.\ai-image.ps1 -Mode vision-enhanced `
    -ReferenceImages @("brand-guidelines.png") `
    -ReferenceDescriptions @("Match our brand colors and style") `
    -Prompt "Dashboard interface showing analytics" `
    -OutputPath "mockup.png"

# Multiple variations for A/B testing
for ($i = 1; $i -le 5; $i++) {
    .\ai-image.ps1 -Provider stability `
        -Prompt "Call to action button background" `
        -Seed $i -OutputPath "cta-variant-$i.png"
}
```

### Documentation

```powershell
# Architecture diagram
.\ai-image.ps1 -Prompt "Cloud architecture diagram, AWS, microservices" `
    -Quality hd -OutputPath "architecture.png"

# Concept illustration
.\ai-image.ps1 -Prompt "Data flow illustration, simple, educational" `
    -OutputPath "concept.png"
```

---

## Provider Selection Guide

### When to use OpenAI DALL-E 3:
✅ Best overall quality
✅ Best prompt understanding
✅ Production-ready images
✅ Marketing materials
❌ Most expensive

### When to use Google Imagen:
✅ Photorealistic results
✅ Fast generation
✅ Asian content/faces
✅ Google Cloud integration
❌ Less artistic control

### When to use Stability AI:
✅ Fine-grained control
✅ Reproducible (seed)
✅ Open source models
✅ Budget-friendly
❌ Requires more tuning

### When to use Azure OpenAI:
✅ Enterprise compliance
✅ Private deployment
✅ Data residency
✅ SLA requirements
❌ Setup overhead

---

## Tips & Best Practices

### Prompt Engineering

**Be specific:**
```
❌ "A house"
✅ "A modern two-story house with large windows, white exterior, surrounded by oak trees, golden hour lighting"
```

**Use style keywords:**
```
- "photorealistic", "photo", "photograph"
- "illustration", "digital art", "painting"
- "3D render", "CGI", "octane render"
- "minimalist", "detailed", "intricate"
```

**Specify composition:**
```
- "close-up", "wide shot", "aerial view"
- "centered", "rule of thirds"
- "shallow depth of field", "bokeh background"
```

### Vision-Enhanced Mode

**Best practices:**
1. Use 2-4 reference images (more = diluted influence)
2. Be specific in descriptions ("Use this color palette" not "colors")
3. One reference per aspect (style, colors, composition)
4. High-quality references = high-quality output

### Image Editing (Inpainting)

**Mask preparation:**
1. Use PNG with transparency
2. Transparent = will be regenerated
3. Opaque = will be preserved
4. Semi-transparent = blended result

**Tips:**
- Larger masked area = more creative freedom
- Smaller masked area = more precise control
- Prompt should describe ONLY the masked content

### Quality Optimization

**For production use:**
- Use `Quality hd` (OpenAI)
- Use higher `Steps` (40-60, Stability AI)
- Use `GuidanceScale` 10-15 for accuracy
- Generate multiple variations, pick best

**For iteration/testing:**
- Use `Quality standard` (OpenAI)
- Use lower `Steps` (20-30, Stability AI)
- Default `GuidanceScale` (7)

---

## Troubleshooting

### Error: "API key not found"

**Solution:** Add API key to appsettings.Secrets.json or pass via `-ApiKey` parameter

### Error: "Image must be PNG"

**Solution:** Convert images to PNG format before using in edit/variation modes

### Error: "Invalid size"

**Solution:** Check provider-specific size constraints:
- OpenAI DALL-E 3: 1024x1024, 1024x1792, 1792x1024
- OpenAI DALL-E 2: 256x256, 512x512, 1024x1024
- Google/Stability: Various (check docs)

### Low quality results

**Try:**
1. More specific prompts
2. Higher quality settings
3. Reference images (vision-enhanced mode)
4. Different provider
5. Negative prompts (what NOT to include)

### Results don't match prompt

**Try:**
1. Increase `GuidanceScale` (Google/Stability)
2. Use more descriptive language
3. Add style keywords
4. Use vision-enhanced with reference images

---

## Architecture

```
ai-image.ps1 (wrapper - auto-loads API keys)
    ↓
ai-image-universal.ps1 (provider router)
    ↓
├─→ generate-image-advanced.ps1 (OpenAI implementation)
├─→ Google Imagen API (direct call)
├─→ Stability AI API (direct call)
└─→ Azure OpenAI API (direct call)
```

**Files:**
- `ai-image.ps1` - Simple wrapper (recommended for Claude agents)
- `ai-image-universal.ps1` - Multi-provider orchestrator
- `generate-image-advanced.ps1` - OpenAI-specific implementation
- `generate-image.ps1` - Original simple OpenAI-only tool (legacy)

---

## Future Enhancements

**Planned features:**
- [ ] Midjourney integration (when API available)
- [ ] Batch generation (multiple images from prompt list)
- [ ] Style presets (logo, photo, illustration, etc.)
- [ ] Automatic web optimization (resize, compress)
- [ ] Cost tracking per provider
- [ ] Image upscaling integration
- [ ] Background removal integration

---

**Last Updated:** 2026-01-25
**Maintained By:** Claude Agent (Self-improving system)
