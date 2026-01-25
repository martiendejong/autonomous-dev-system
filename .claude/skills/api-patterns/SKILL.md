---
name: api-patterns
description: Common API development patterns including OpenAI config initialization, API response enrichment, URL duplication, LLM integration, System.Text.Json dynamic handling, and JSON serialization issues. Use when working with APIs, fixing compilation/runtime errors, or debugging JSON issues.
allowed-tools: Read, Write, Edit, Grep, Bash
user-invocable: true
---

# API Development Patterns

**Purpose:** Document and apply proven patterns for API development to avoid common pitfalls.

## Pattern 1: OpenAIConfig Initialization Trap

### ❌ WRONG - Leads to Runtime Crash

```csharp
var config = new OpenAIConfig(apiKey);  // Model property remains empty!
var client = factory.CreateClient();     // ArgumentException: Model cannot be empty
```

### ✅ CORRECT - Always Set Model Property

```csharp
// Option 1: Use full constructor
var config = new OpenAIConfig(
    apiKey: apiKey,
    embeddingModel: "text-embedding-3-small",
    model: "gpt-4o-mini",
    maxTokens: 4000
);

// Option 2: Set Model after construction
var config = new OpenAIConfig(apiKey);
config.Model = "gpt-4o-mini";  // CRITICAL - Must set explicitly

var client = factory.CreateClient();
```

### Detection

**Error signature:**
```
System.ArgumentException: Value cannot be an empty string. (Parameter 'model')
at OpenAI.Chat.ChatClient.ChatClient(ClientPipeline pipeline, string model, ...)
```

**Search for vulnerable patterns:**
```bash
# Find all OpenAIConfig usage
grep -r "new OpenAIConfig" --include="*.cs"

# Check if Model is set
grep -A 3 "new OpenAIConfig(apiKey)" --include="*.cs"
```

### Files to Check

Common locations:
- Controllers (UploadedDocumentsController, WebsiteController, IntakeController)
- Services (SocialMediaGenerationService, DocumentProcessingService)

## Pattern 2: API Response Enrichment

### Problem

Backend queries multiple tables but API only returns partial data:
```csharp
// Controller returns basic user data
var users = await _userService.GetUsers();
return Ok(users);  // Missing related data!
```

Frontend expects token balance, but backend doesn't include it:
```typescript
interface User {
  id: string;
  email: string;
  tokenBalance: number;  // ❌ Always 0 because backend doesn't query it
}
```

### Solution - Enrich Response in Controller

```csharp
[HttpGet("users")]
public async Task<IActionResult> GetUsers()
{
    var users = await _userService.GetUsers();  // Basic user data

    // Enrich with related data
    var enrichedUsers = new List<object>();
    foreach (var user in users)
    {
        // Query related table
        var tokenBalance = await _dbContext.UserTokenBalances
            .FirstOrDefaultAsync(t => t.UserId == user.Id);

        enrichedUsers.Add(new
        {
            ...user,
            tokenBalance = tokenBalance?.CurrentBalance ?? 0,
            monthlyAllowance = tokenBalance?.MonthlyAllowance ?? 500,
            tokensUsedThisMonth = tokenBalance?.MonthlyUsage ?? 0,
            tokensRemainingThisMonth =
                (tokenBalance?.MonthlyAllowance ?? 500) -
                (tokenBalance?.MonthlyUsage ?? 0)
        });
    }

    return Ok(enrichedUsers);
}
```

### Benefits

✅ Frontend gets all data in single request
✅ No need for multiple API calls
✅ Single source of truth
✅ Consistent data structure

### Detection

**Symptoms:**
- Frontend displays 0, null, or default values for fields that should have data
- Data exists in database but doesn't appear in UI
- Console shows "undefined" for expected properties

**Investigation:**
```bash
# Find API endpoint
grep -r "GetUsers\(\)" --include="*.cs"

# Check what's returned
# Compare with frontend interface expectations

# Check database for actual data
# Verify data exists in related tables
```

## Pattern 3: Frontend API URL Duplication

### Problem

Double `/api/` prefix in URLs:
```
❌ https://localhost:54501/api/api/v1/projects/123/documents
```

### Root Cause

`axiosConfig.ts` sets baseURL:
```typescript
const axiosConfig = {
  baseURL: 'https://localhost:54501/api/'  // Includes /api/
};
```

Service adds `/api/` again:
```typescript
const API_BASE = '/api/v1/projects';  // ❌ Duplicates /api/
```

Result: `baseURL + endpoint = /api/ + /api/v1/... = /api/api/v1/...`

### Solution

**Remove `/api/` from service base paths:**

```typescript
// ❌ WRONG
const API_BASE = '/api/v1/projects';

// ✅ CORRECT
const API_BASE = '/v1/projects';  // baseURL already has /api/
```

### Verification

**Check all service files:**
```bash
# Find potential duplications
grep -r "const API_BASE = '/api/" ClientManagerFrontend/src/services/

# Should be:
grep -r "const API_BASE = '/v" ClientManagerFrontend/src/services/
```

**Test in browser dev tools:**
```javascript
// Network tab should show:
// ✅ GET https://localhost:54501/api/v1/projects/123
// ❌ GET https://localhost:54501/api/api/v1/projects/123
```

### Prevention

**Checklist when creating new services:**
1. ✅ Read `axiosConfig.ts` to see current `baseURL`
2. ✅ Ensure service `API_BASE` doesn't repeat any part of `baseURL`
3. ✅ Test actual URL in browser dev tools
4. ✅ Search for similar services as reference

## Pattern 4: Hazina LLM Framework Integration

### Correct API Usage

```csharp
// ✅ CORRECT - IHazinaAIService (high-level)
private readonly IHazinaAIService _aiService;

public MyService(IHazinaAIService aiService)
{
    _aiService = aiService;
}

public async Task<string> GenerateText(string prompt)
{
    var response = await _aiService.GetResponseAsync(
        prompt,
        CancellationToken.None
    );

    return response.Content;
}
```

### Common Mistakes

```csharp
// ❌ WRONG - Non-existent interfaces
private readonly ILLMProviderFactory _factory;  // Doesn't exist
private readonly ILLMProvider _provider;        // Doesn't exist

// ❌ WRONG - Non-existent methods
await _provider.GenerateAsync(prompt);  // Method doesn't exist

// ❌ WRONG - Passing model name to CreateClient
var client = factory.CreateClient("haiku");  // Takes no parameters
```

### Correct Pattern

```csharp
// Dependency injection in Program.cs
builder.Services.AddSingleton<IHazinaAIService, HazinaAIService>();

// Service usage
private readonly IHazinaAIService _aiService;

public MyService(IHazinaAIService aiService)
{
    _aiService = aiService;
}

// Calling the AI
var response = await _aiService.GetResponseAsync(
    prompt: "Your prompt here",
    cancellationToken: CancellationToken.None
);

var text = response.Content;
```

## Pattern 5: LLM Tool Response URLs

### Problem

Tool returns relative URL, LLM can't convert to absolute:

```csharp
// Tool returns
return new { imageUrl = "/api/uploadeddocuments/file/123/image.png" };

// LLM tries to make absolute, fails
// Output: "![Image](https://localhost:54501/" (incomplete)
```

### Solution - Tools Return Absolute URLs

```csharp
// Add BaseUrl to request context
public static class CurrentRequestContext
{
    private static readonly AsyncLocal<string> _baseUrl = new AsyncLocal<string>();

    public static string BaseUrl
    {
        get => _baseUrl.Value ?? "https://localhost:54501";
        set => _baseUrl.Value = value;
    }
}

// Set in controller
var baseUrl = $"{Request.Scheme}://{Request.Host}";
CurrentRequestContext.BaseUrl = baseUrl;

// Tool converts relative to absolute
var imageUrl = BuildImageUrl(...);  // Returns /api/...
if (!string.IsNullOrEmpty(imageUrl) && imageUrl.StartsWith("/"))
{
    var baseUrl = CurrentRequestContext.BaseUrl;
    imageUrl = $"{baseUrl}{imageUrl}";  // Now absolute
}

return new { imageUrl = imageUrl };  // https://localhost:54501/api/...
```

### Benefits

✅ LLM receives ready-to-use URLs
✅ No incomplete markdown
✅ Works in dev and production
✅ Consistent across all tools

## Pattern 6: Flexible LLM Response Extraction

### Problem

Hardcoded regex breaks when LLM customizes output:

```csharp
// ❌ Too specific - breaks when LLM changes alt text
var match = Regex.Match(text, @"!\[Generated Image\]\((.*?)\)");

// LLM outputs: "![Eenvoudig huis](url)"  // ❌ No match!
```

### Solution - Flexible Patterns

```csharp
// ✅ Flexible - matches any alt text
var match = Regex.Match(text, @"!\[.*?\]\((.*?)\)");

// Matches:
// ![Generated Image](url) ✅
// ![Eenvoudig huis](url) ✅
// ![Any text here](url) ✅
```

### Guideline

When extracting structured data from LLM responses:
- ✅ Match patterns, not literal strings
- ✅ Use capture groups for data extraction
- ✅ Allow LLM to customize surrounding text
- ❌ Don't hardcode exact phrasing

**Examples:**
```csharp
// URLs from markdown
@"!\[.*?\]\((.*?)\)"        // ✅ Any image
@"https?://\S+"             // ✅ Any URL

// Code blocks
@"```(\w+)?\n(.*?)\n```"    // ✅ Any language

// Headers
@"#{1,6}\s+(.*)"            // ✅ Any header level

// Specific exact text
@"!\[Generated Image\]\((.*?)\)"  // ❌ Too rigid
```

## Pattern 7: System.Text.Json Dynamic Parameter Handling

### Problem

Using `dynamic` parameter with ASP.NET Core (System.Text.Json):

```csharp
// ❌ FAILS at runtime
public async Task<IActionResult> UpdateUser([FromBody] dynamic userData)
{
    string userId = userData?.Id?.ToString();  // RuntimeBinderException!
}
```

**Error:** `'System.Text.Json.JsonElement' does not contain a definition for 'Id'`

### Root Cause

**Newtonsoft.Json** → deserializes `dynamic` as `ExpandoObject` → property access works
**System.Text.Json** → deserializes `dynamic` as `JsonElement` → property access fails

### Solution - Use JsonElement with TryGetProperty

```csharp
// ✅ CORRECT - Explicit JsonElement type
public async Task<IActionResult> UpdateUser([FromBody] System.Text.Json.JsonElement userData)
{
    // Safe property access
    string? userId = userData.TryGetProperty("Id", out var idProp)
        ? idProp.GetString()
        : null;

    // With default value
    string email = userData.TryGetProperty("Email", out var emailProp)
        ? emailProp.GetString() ?? defaultEmail
        : defaultEmail;

    // For nullable check (property exists but value is null)
    bool avatarWasProvided = userData.TryGetProperty("Avatar", out _);

    // For numbers
    int count = userData.TryGetProperty("Count", out var countProp)
        ? countProp.GetInt32()
        : 0;
}
```

### Key Points

1. **Never use `dynamic`** with System.Text.Json - use `JsonElement`
2. **Use `TryGetProperty`** - returns `false` for missing properties (doesn't throw)
3. **Handle nulls** - `GetString()` returns `null` for JSON `null`
4. **Distinguish missing vs null** - `TryGetProperty` returns `false` only if property doesn't exist

### Critical: Null Comparison with Dynamic JsonElement

**Error signature:**
```
Microsoft.CSharp.RuntimeBinder.RuntimeBinderException:
Operator '!=' cannot be applied to operands of type 'System.Text.Json.JsonElement' and '<null>'
```

**Root cause:** When `dynamic` contains a `JsonElement`, you can't use `!= null` comparison.

```csharp
// ❌ WRONG - Causes RuntimeBinderException
dynamic obj = GetSomeDynamicData();
if (obj.Payload != null)  // CRASH!

// ✅ CORRECT - Proper null/undefined check
var isPayloadPresent = obj.Payload is not null &&
    !(obj.Payload is System.Text.Json.JsonElement je &&
      je.ValueKind == System.Text.Json.JsonValueKind.Undefined);

if (isPayloadPresent)
{
    // Safe to use obj.Payload
}
```

**Common locations for this bug:**
- Controllers extracting data from chat/AI responses
- Services processing LLM output with `Payload` properties
- Any code using `dynamic` with deserialized JSON

---

## Pattern 8: JSON Property Name Collision in Anonymous Types

### Problem

```csharp
// ❌ FAILS - Property name collision
var response = new
{
    Avatar = userAvatar,
    avatar = userAvatar  // Collision!
};
```

**Error:** `The JSON property name for 'avatar' collides with another property`

### Root Cause

ASP.NET Core's System.Text.Json uses **camelCase naming policy by default**:
- `Avatar` → serialized as `"avatar"`
- `avatar` → serialized as `"avatar"`

Both properties become the same JSON key.

### Solution

Remove duplicates - System.Text.Json handles casing automatically:

```csharp
// ✅ CORRECT - Single property, serializes as "avatar"
var response = new
{
    Avatar = userAvatar  // JSON: { "avatar": "..." }
};
```

### Prevention

**When creating anonymous types:**
1. ✅ Use PascalCase property names only
2. ✅ Don't add "lowercase for compatibility" duplicates
3. ✅ Trust the JSON serializer's naming policy

```csharp
// ❌ Don't do this
var response = new
{
    FirstName = user.FirstName,
    firstName = user.FirstName,  // Collision!
    lastName = user.LastName     // Collision with LastName!
};

// ✅ Do this
var response = new
{
    FirstName = user.FirstName,
    LastName = user.LastName
    // JSON output: { "firstName": "...", "lastName": "..." }
};
```

---

## Detection and Prevention

### Pre-Development Checklist

**Before writing API code:**
1. ✅ Check existing similar endpoints for patterns
2. ✅ Verify OpenAIConfig initialization in similar services
3. ✅ Check frontend expectations (TypeScript interfaces)
4. ✅ Review axiosConfig.ts for baseURL
5. ✅ Understand related database tables

### Post-Development Checklist

**Before creating PR:**
1. ✅ Search for `new OpenAIConfig(` and verify Model set
2. ✅ Test API endpoint returns all expected fields
3. ✅ Check browser Network tab for URL format
4. ✅ Verify no hardcoded regexes for LLM extraction
5. ✅ Test with actual data, not just mocks

### Quick Reference Commands

```bash
# Find OpenAIConfig without Model
grep -A 2 "new OpenAIConfig" --include="*.cs" | grep -v "Model"

# Find API_BASE with /api/
grep "const API_BASE = '/api/" ClientManagerFrontend/src/services/

# Find hardcoded markdown patterns
grep -r "!\\\[Generated Image\\\]" --include="*.cs"

# Check for ILLMProviderFactory (wrong interface)
grep -r "ILLMProviderFactory" --include="*.cs"

# Find dynamic parameters (potential System.Text.Json issues)
grep -r "\[FromBody\] dynamic" --include="*.cs"

# Find potential JSON property collisions (lowercase duplicates)
grep -rE "^\s+\w+ = .*,\s*$" --include="*.cs" -A 1 | grep -E "^\s+[a-z]\w+ = "
```

## Related Documentation

- Reflection log: `C:/scripts/_machine/reflection.log.md` (2026-01-12 entries)
- OpenAI integration: `C:/scripts/claude_info.txt`
- Frontend patterns: `ClientManagerFrontend/src/services/README.md` (if exists)

## When to Apply These Patterns

**Use this Skill when:**
- Creating new API endpoints
- Integrating OpenAI or Hazina AI services
- Fixing "ArgumentException: Model cannot be empty"
- Debugging missing data in frontend
- Seeing 404 errors with `/api/api/` in URLs
- Implementing LLM tool integrations
- Extracting data from LLM responses
- Getting `RuntimeBinderException` with `JsonElement`
- Getting `JSON property name collision` errors
- Using `[FromBody] dynamic` parameters
