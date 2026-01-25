# Web Scraping as LLM Tool - Implementation Plan

**Date:** 2026-01-13
**Related PRs:**
- Hazina PR #69 (FireCrawl service) - ✅ MERGED
- client-manager PR #120 (UI implementation) - ⏳ OPEN

## Problem Statement

**Current State:** PR #120 implements web scraping as a **UI-driven manual workflow**:
- User clicks "Add Competitor" → Enters URL → System scrapes → Shows results
- LLM cannot autonomously invoke scraping during chat conversations

**Desired State:** Web scraping should be an **LLM-accessible tool**:
- User: "Analyze the branding of nike.com compared to our brand"
- LLM: *autonomously invokes scraping tool → receives branding data → continues conversation with analysis*

## Architecture Analysis

### ✅ What Exists (from Hazina PR #69)

**Service Layer** - `/c/Projects/hazina/src/Tools/Services/Hazina.Tools.Services.Web/`

```csharp
// IFireCrawlService interface with methods:
Task<FireCrawlExtractResult> ExtractBrandingAsync(string url)
Task<FireCrawlScreenshotResult> ScreenshotAsync(FireCrawlScreenshotRequest request)
Task<FireCrawlScrapeResult> ScrapeAsync(string url, bool includeHtml = false)
Task<FireCrawlCrawlResult> CrawlAsync(FireCrawlCrawlRequest request)
```

### ✅ Tool Pattern (from ToolExecutor.cs)

**Location:** `/c/Projects/hazina/src/Tools/Services/Hazina.Tools.Services.Chat/Tools/ToolExecutor.cs`

**Pattern discovered:**
1. Tools defined in `GetToolDefinitions()` - returns `List<IToolDefinition>`
2. Tools executed via switch statement in `ExecuteAsync(toolName, argumentsJson, context, cancellationToken)`
3. Tool arguments deserialized from JSON to strongly-typed classes
4. Tool results returned as `IToolResult` with success status and data

**Existing tools:**
- `gather_data` - Store structured data from conversation
- `analyze_field` - Generate brand analysis content
- `generate_image` - Create images via AI
- `rename_project` / `rename_chat` - Rename operations
- `show_guidance_card` - Interactive user questions
- `request_file_upload` - Request file from user
- `show_system_status` - Display status messages
- `show_artifact` - Show generated artifacts

### ❌ What's Missing

1. **No tool definition for web scraping** in `ToolExecutor.GetToolDefinitions()`
2. **No execution handler** in `ToolExecutor.ExecuteAsync()` switch statement
3. **No integration** between `BrandImportService` (client-manager) and `FireCrawlService` (Hazina)

## Implementation Plan

### Phase 1: Add LLM Tool to Hazina Framework ✅

**File:** `/c/Projects/hazina/src/Tools/Services/Hazina.Tools.Services.Chat/Tools/ToolExecutor.cs`

#### Step 1.1: Add Tool Definition

In `GetToolDefinitions()` method, add:

```csharp
new ToolDefinition
{
    Name = "scrape_website_branding",
    Description = "Extract branding elements (colors, fonts, logo, typography) from any website URL. Use this when the user asks about competitor branding, wants to analyze a website's design, or needs to import competitor brand data. This tool autonomously scrapes the website and returns structured branding information.",
    Parameters = JsonSerializer.Deserialize<JsonElement>(@"{
        ""type"": ""object"",
        ""properties"": {
            ""url"": {
                ""type"": ""string"",
                ""format"": ""uri"",
                ""description"": ""The website URL to scrape (e.g., 'https://nike.com')""
            },
            ""capture_screenshot"": {
                ""type"": ""boolean"",
                ""description"": ""Whether to capture a full-page screenshot (default: true)"",
                ""default"": true
            },
            ""save_to_database"": {
                ""type"": ""boolean"",
                ""description"": ""Whether to save as competitor brand in database (default: false for chat-only analysis)"",
                ""default"": false
            }
        },
        ""required"": [""url""]
    }")
}
```

#### Step 1.2: Add Constructor Dependency

Add `IFireCrawlService` to constructor:

```csharp
private readonly IFireCrawlService _fireCrawlService;

public ToolExecutor(
    ILogger<ToolExecutor> logger,
    Func<IDataGatheringService> dataGatheringServiceFactory,
    Func<IAnalysisFieldService> analysisFieldServiceFactory,
    Func<ChatService> chatServiceFactory,
    Func<ProjectsRepository> projectsRepositoryFactory = null,
    Func<ProjectChatRepository> chatRepositoryFactory = null,
    IProjectChatNotifier notifier = null,
    IFireCrawlService fireCrawlService = null) // ADD THIS
{
    // ... existing code ...
    _fireCrawlService = fireCrawlService;
}
```

#### Step 1.3: Add Switch Case

In `ExecuteAsync()` method switch statement:

```csharp
return toolName switch
{
    "gather_data" => await ExecuteGatherDataAsync(argumentsJson, context, cancellationToken),
    // ... existing cases ...
    "scrape_website_branding" => await ExecuteScrapeBrandingAsync(argumentsJson, context, cancellationToken), // ADD THIS
    _ => new ToolResult { Success = false, Error = $"Unknown tool: {toolName}", TokensUsed = 0 }
};
```

#### Step 1.4: Add Execution Method

At the end of the class (before the argument classes section):

```csharp
/// <summary>
/// Execute web scraping to extract branding from a website.
/// Uses Hazina FireCrawl service to autonomously scrape and analyze.
/// </summary>
private async Task<IToolResult> ExecuteScrapeBrandingAsync(
    string argumentsJson,
    string context,
    CancellationToken cancellationToken)
{
    var args = JsonSerializer.Deserialize<ScrapeBrandingArgs>(argumentsJson, new JsonSerializerOptions
    {
        PropertyNameCaseInsensitive = true
    });

    if (args == null || string.IsNullOrWhiteSpace(args.Url))
    {
        return new ToolResult
        {
            Success = false,
            Error = "Invalid arguments: url is required",
            TokensUsed = 0
        };
    }

    // Validate URL format
    if (!Uri.TryCreate(args.Url, UriKind.Absolute, out var uri))
    {
        return new ToolResult
        {
            Success = false,
            Error = $"Invalid URL format: {args.Url}",
            TokensUsed = 0
        };
    }

    try
    {
        _logger.LogInformation("Scraping branding from: {Url}", args.Url);

        // Check if FireCrawl service is available
        if (_fireCrawlService == null)
        {
            return new ToolResult
            {
                Success = false,
                Error = "FireCrawl service not available. Please configure FireCrawl API key.",
                TokensUsed = 0
            };
        }

        // Extract branding using FireCrawl
        var extractResult = await _fireCrawlService.ExtractBrandingAsync(args.Url);

        if (!extractResult.Success || extractResult.Branding == null)
        {
            return new ToolResult
            {
                Success = false,
                Error = extractResult.Error ?? "Failed to extract branding from website",
                TokensUsed = EstimateTokens(argumentsJson)
            };
        }

        var branding = extractResult.Branding;

        // Optionally capture screenshot
        string? screenshotBase64 = null;
        if (args.CaptureScreenshot)
        {
            var screenshotResult = await _fireCrawlService.ScreenshotAsync(
                new Hazina.Tools.Services.Web.Models.FireCrawlScreenshotRequest
                {
                    Url = args.Url,
                    FullPage = true,
                    Width = 1920,
                    Height = 1080
                });

            if (screenshotResult.Success && !string.IsNullOrEmpty(screenshotResult.Screenshot))
            {
                screenshotBase64 = screenshotResult.Screenshot;
            }
        }

        _logger.LogInformation(
            "Successfully extracted branding from {Url}: {ColorCount} colors, {FontCount} fonts",
            args.Url, branding.Colors?.Count ?? 0, branding.Fonts?.Count ?? 0);

        // Return structured branding data to LLM
        return new ToolResult
        {
            Success = true,
            Result = new
            {
                url = args.Url,
                domain = uri.Host,
                branding = new
                {
                    colors = branding.Colors ?? new List<string>(),
                    primaryColor = branding.PrimaryColor,
                    secondaryColor = branding.SecondaryColor,
                    fonts = branding.Fonts ?? new List<string>(),
                    logoUrl = branding.LogoUrl,
                    typography = branding.Typography ?? new Dictionary<string, string>()
                },
                screenshot = screenshotBase64 != null ? new
                {
                    available = true,
                    format = "base64_png",
                    size = screenshotBase64.Length
                } : null,
                summary = $"Extracted {branding.Colors?.Count ?? 0} colors, " +
                         $"{branding.Fonts?.Count ?? 0} fonts from {uri.Host}"
            },
            TokensUsed = EstimateTokens(argumentsJson) + EstimateTokens(extractResult.ToString())
        };
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error scraping branding from {Url}", args.Url);
        return new ToolResult
        {
            Success = false,
            Error = $"Scraping failed: {ex.Message}",
            TokensUsed = 0
        };
    }
}
```

#### Step 1.5: Add Argument Class

In the "Tool argument classes" section at the bottom:

```csharp
private class ScrapeBrandingArgs
{
    public string Url { get; set; }
    public bool CaptureScreenshot { get; set; } = true;
    public bool SaveToDatabase { get; set; } = false;
}
```

#### Step 1.6: Register Service in DI

**File:** `/c/Projects/hazina/src/Tools/Services/Hazina.Tools.Services.Chat/` (or wherever services are registered)

```csharp
// In Program.cs or Startup.cs
services.AddSingleton<IFireCrawlService>(sp =>
{
    var config = new FireCrawlConfig
    {
        ApiKey = configuration["FireCrawl:ApiKey"],
        BaseUrl = configuration["FireCrawl:BaseUrl"] ?? "https://api.firecrawl.dev/v1"
    };

    var logger = sp.GetRequiredService<ILogger<FireCrawlService>>();

    return new FireCrawlService(
        config,
        httpClient: null,
        logInfo: msg => logger.LogInformation(msg),
        logError: (ex, msg) => logger.LogError(ex, msg)
    );
});
```

### Phase 2: Integrate with client-manager (Optional - for DB persistence)

**Only needed if you want LLM to save competitors to database**

If `save_to_database: true`, you'd need to:

1. Inject `BrandImportService` into `ToolExecutor`
2. Call `BrandImportService.ImportBrandAsync()` when `SaveToDatabase == true`
3. Return saved `CompetitorBrand` ID in tool result

**File:** `/c/Projects/client-manager/ClientManagerAPI/Controllers/WebScrapingController.cs`

Add new endpoint for tool invocation:

```csharp
/// <summary>
/// Execute web scraping as an LLM tool (used by chat background process)
/// </summary>
[HttpPost("tools/scrape-branding")]
public async Task<ActionResult<BrandingData>> ExecuteScrapingTool([FromBody] ScrapingToolRequest request)
{
    var clientId = User.FindFirst("ClientId")?.Value;
    if (string.IsNullOrEmpty(clientId))
        return Unauthorized(new { error = "Client ID not found" });

    var result = await _brandImport.ImportBrandAsync(clientId, new BrandImportRequest
    {
        Url = request.Url,
        CaptureScreenshot = request.CaptureScreenshot,
        // Don't save to DB unless explicitly requested
        ProjectId = request.SaveToDatabase ? request.ProjectId : null
    });

    if (!result.Success)
        return BadRequest(new { error = result.Error });

    return Ok(result.Branding);
}

public class ScrapingToolRequest
{
    public string Url { get; set; }
    public bool CaptureScreenshot { get; set; } = true;
    public bool SaveToDatabase { get; set; } = false;
    public string? ProjectId { get; set; }
}
```

### Phase 3: Configuration

**File:** `appsettings.json` (Hazina or client-manager)

```json
{
  "FireCrawl": {
    "ApiKey": "fc-your-api-key-here",
    "BaseUrl": "https://api.firecrawl.dev/v1"
  }
}
```

## Testing Plan

### Manual Chat Testing

1. **Basic scraping:**
   ```
   User: "Extract the branding from tesla.com"
   Expected: LLM invokes scrape_website_branding tool, returns colors/fonts
   ```

2. **Competitive analysis:**
   ```
   User: "Compare our branding with nike.com and adidas.com"
   Expected: LLM invokes tool twice, analyzes differences
   ```

3. **Multi-step workflow:**
   ```
   User: "Find 3 competitor websites in the athletic footwear space and analyze their color schemes"
   Expected: LLM researches URLs, scrapes each, summarizes findings
   ```

### Integration Testing

1. **Tool registration:** Verify tool appears in `GetToolDefinitions()` output
2. **Execution:** Mock FireCrawl service, verify tool execution path
3. **Error handling:** Test invalid URLs, API failures, missing config

### User Acceptance Testing

Before:
- User must manually click "Add Competitor" → enter URL → wait
- LLM cannot help with competitor research

After:
- User: "I'm curious about Stripe's branding"
- LLM: *autonomously scrapes stripe.com, provides instant analysis*

## Architecture Diagram

### Before (PR #120 - UI Only)

```
User → UI Wizard → WebScrapingController → BrandImportService → FireCrawl API
                                                                       ↓
                                                                  Branding Data
                                                                       ↓
                                                                   Database
```

### After (With LLM Tool)

```
User → Chat LLM ─┬→ Tool Registry → ToolExecutor → FireCrawlService → FireCrawl API
                 │                                                           ↓
                 │                                                      Branding Data
                 │                                                           ↓
                 └─ (Receives branding data, continues conversation with analysis)

User → UI Wizard → WebScrapingController → BrandImportService → FireCrawl API
                                                                       ↓
                                                                   Database
                                                             (Manual workflow still available)
```

## Files to Modify

### Hazina Framework (Core Tool Implementation)

1. ✅ **ToolExecutor.cs**
   - Location: `/c/Projects/hazina/src/Tools/Services/Hazina.Tools.Services.Chat/Tools/ToolExecutor.cs`
   - Changes:
     - Add `IFireCrawlService` dependency
     - Add `scrape_website_branding` tool definition
     - Add switch case for tool execution
     - Add `ExecuteScrapeBrandingAsync()` method
     - Add `ScrapeBrandingArgs` class

2. ✅ **Service Registration**
   - Location: Program.cs or Startup.cs (wherever DI is configured)
   - Changes:
     - Register `IFireCrawlService` in DI container
     - Inject into `ToolExecutor` constructor

3. ✅ **Configuration**
   - Location: `appsettings.json`
   - Add FireCrawl API configuration

### client-manager (Optional - DB Persistence)

4. ⏳ **WebScrapingController.cs** (Optional)
   - Location: `/c/Projects/client-manager/ClientManagerAPI/Controllers/WebScrapingController.cs`
   - Add tool invocation endpoint

## Success Criteria

✅ **Tool appears in LLM tool list** - `GetToolDefinitions()` includes `scrape_website_branding`

✅ **LLM can autonomously scrape** - User asks about competitor → LLM invokes tool → receives data

✅ **Returns structured data** - Tool result includes colors, fonts, logo URL, screenshot

✅ **Error handling** - Graceful failures for invalid URLs, missing API key, API errors

✅ **No breaking changes** - Existing UI workflow (PR #120) continues to work

## Rollout Strategy

### Phase 1: Hazina Framework (Week 1)
- Add tool definition and execution logic
- Test with mock FireCrawl service
- Deploy to Hazina develop branch

### Phase 2: Integration Testing (Week 1)
- Test in client-manager chat
- Verify autonomous invocation
- Refine tool description for better LLM understanding

### Phase 3: Production Deployment (Week 2)
- Merge Hazina changes
- Update client-manager to use new Hazina version
- Monitor LLM tool usage in production

## Key Design Decisions

### 1. **Read-Only by Default**
- Tool does NOT save to database unless `save_to_database: true`
- Rationale: Chat analysis shouldn't pollute competitor database
- LLM can suggest "Would you like me to save this competitor?" if user wants persistence

### 2. **Synchronous Execution**
- Tool blocks until scraping completes (no async job queue)
- Rationale: LLM needs data immediately to continue conversation
- Typically completes in 5-15 seconds

### 3. **Minimal Tool Parameters**
- Only `url` required, optional `capture_screenshot` and `save_to_database`
- Rationale: Keep tool simple for LLM to invoke correctly

### 4. **Structured Data Return**
- Return JSON with colors, fonts, logo - not raw HTML
- Rationale: LLM needs clean structured data for analysis

### 5. **Separate from UI Workflow**
- UI wizard (PR #120) remains unchanged
- Rationale: Different use cases - manual vs autonomous

## Future Enhancements

### Phase 4: Advanced Features
- [ ] Bulk scraping (multiple URLs in one invocation)
- [ ] Competitor comparison mode (automatic side-by-side analysis)
- [ ] Caching (avoid re-scraping same URL within 24h)
- [ ] Screenshot analysis (LLM analyzes screenshot for layout patterns)

### Phase 5: AI-Powered Insights
- [ ] Automatic brand positioning analysis
- [ ] Industry trend detection
- [ ] Color scheme recommendations based on competitor analysis

## Questions for User

1. **Service Location:** Should `IFireCrawlService` be injected into `ToolExecutor` via constructor or via factory method?
   - Current pattern uses factories for most services
   - FireCrawl is stateless, so direct injection seems cleaner

2. **Database Persistence:** Do you want LLM to have permission to save competitors to database?
   - Option A: Read-only tool (analysis only)
   - Option B: LLM can save with user confirmation
   - Option C: Always save to database (simplest, but may pollute DB)

3. **Screenshot Handling:** Screenshots are large (base64 PNG). Should we:
   - Option A: Return full base64 in tool result (simple, but large token cost)
   - Option B: Save to disk, return URL (requires file storage)
   - Option C: Skip screenshots in tool mode (fastest, lowest cost)

4. **Error Handling:** If scraping fails (API error, invalid URL), should:
   - Option A: Return error to LLM, let it explain to user
   - Option B: Retry with fallback strategies
   - Option C: Fall back to manual UI wizard

## Next Steps

1. ✅ Review this implementation plan
2. ⏳ Get approval on design decisions (questions above)
3. ⏳ Implement Phase 1 (Hazina tool definition)
4. ⏳ Test with mock FireCrawl service
5. ⏳ Integration test with client-manager
6. ⏳ Production deployment

---

**Author:** Claude Sonnet 4.5
**Date:** 2026-01-13
**Related Documentation:**
- `C:\Projects\hazina\docs\FIRECRAWL_INTEGRATION.md`
- `C:\Users\HP\Desktop\FIRECRAWL_CLIENT_MANAGER_PROPOSAL.md`
