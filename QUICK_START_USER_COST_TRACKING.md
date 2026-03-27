# 🚀 QUICK START: Per-User Cost Tracking (15 Minutes)

**Goal:** Show users their total AI usage cost in your application's frontend

**Works with:** ArtRevisionist, myproject, or any myframework-based app

---

## ⚡ 3-STEP INTEGRATION

### STEP 1: Backend (5 minutes)

**A. Copy the service file:**
```bash
# Copy from C:\scripts\code-samples\ to your project
cp C:\scripts\code-samples\UserTokenCostService.cs YourApp/Services/
```

**B. Update namespace in `UserTokenCostService.cs`:**
```csharp
// Change this line:
namespace YourApp.Services

// To match your app:
namespace ClientManagerAPI.Services  // For myproject
// OR
namespace ArtRevisionistAPI.Services  // For ArtRevisionist
```

**C. Register in `Program.cs`:**
```csharp
// Add these lines (around line 30-50 where services are registered)
builder.Services.AddMemoryCache(); // If not already added
builder.Services.AddScoped<IUserTokenCostService, UserTokenCostService>();
```

**D. Copy the controller:**
```bash
cp C:\scripts\code-samples\UserTokenCostController.cs YourApp/Controllers/
```

**E. Update namespace in `UserTokenCostController.cs`:**
```csharp
// Change this line:
using YourApp.Services;

// To match your app:
using ClientManagerAPI.Services;  // For myproject
// OR
using ArtRevisionistAPI.Services;  // For ArtRevisionist
```

**F. Test the API:**
```bash
# Start your backend
dotnet run

# In another terminal, test the endpoint (you need a valid auth token)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/api/user-costs/my-summary

# Expected response:
# {"userId":"testuser","totalCost":1.2345,"totalTokens":50000,...}
```

---

### STEP 2: Frontend (5 minutes)

**A. Copy the component:**
```bash
cp C:\scripts\code-samples\UserCostDisplay.tsx YourApp/Frontend/src/components/
```

**B. Update imports (if needed):**
```typescript
// In UserCostDisplay.tsx, line 2:
import axios from 'axios'; // Or your configured axios instance

// If you have a custom axios config, change to:
import axiosInstance from '../services/axiosConfig';
// And replace all `axios.get` calls with `axiosInstance.get`
```

---

### STEP 3: Display in Your App (5 minutes)

**Option A: Show in navbar/header (simple inline display)**

```tsx
// In your Navbar.tsx or Header.tsx

import { SimpleUserCost } from '../components/UserCostDisplay';

export const Navbar = () => {
  return (
    <nav className="bg-gray-800 text-white p-4 flex justify-between">
      <div>My App</div>
      <div className="flex items-center space-x-4">
        <SimpleUserCost /> {/* ← Add this */}
        <span>User Menu</span>
      </div>
    </nav>
  );
};
```

**Option B: Show in settings/profile page (full details)**

```tsx
// In your Settings.tsx or Profile.tsx

import { UserCostDisplay } from '../components/UserCostDisplay';

export const SettingsPage = () => {
  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-6">Account Settings</h1>

      {/* Other settings sections... */}

      <div className="mt-6">
        <UserCostDisplay showDetails={true} />
      </div>
    </div>
  );
};
```

**Option C: Show in dashboard (ArtRevisionist example)**

```tsx
// ArtRevisionist/Frontend/src/pages/Dashboard.tsx

import { UserCostDisplay } from '../components/UserCostDisplay';

export const DashboardPage = () => {
  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-6 p-6">
      {/* Existing dashboard widgets */}
      <div>Total Documents: 42</div>
      <div>Active Topics: 5</div>

      {/* NEW: Cost widget */}
      <UserCostDisplay className="col-span-1" />
    </div>
  );
};
```

**Option D: Show in billing page (myproject example)**

```tsx
// ClientManager/Frontend/src/pages/Billing.tsx

import { UserCostDisplay } from '../components/UserCostDisplay';

export const BillingPage = () => {
  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-6">AI Usage & Billing</h1>
      <UserCostDisplay showDetails={true} />
    </div>
  );
};
```

---

## ✅ VERIFICATION

**Test that it works:**

1. **Start backend:**
   ```bash
   cd C:\Projects\myproject  # or artrevisionist
   dotnet run
   ```

2. **Start frontend:**
   ```bash
   cd ClientManagerFrontend  # or Frontend for artrevisionist
   npm run dev
   ```

3. **Login to your app**

4. **Navigate to where you added the component**

5. **You should see:**
   - Your total AI cost (e.g., $1.2345)
   - Total tokens used
   - Total API requests
   - (If showDetails=true) Cost by provider and model

6. **Verify real-time updates:**
   - Use an AI feature (generate content, chat, etc.)
   - Wait 5 minutes (cache TTL)
   - Refresh the page
   - Cost should have increased

---

## 🎨 CUSTOMIZATION

### Change cache duration (default: 5 minutes)

```csharp
// In UserTokenCostService.cs, line 61:
private const int CacheDurationMinutes = 5;  // ← Change this
```

### Update pricing

```csharp
// In UserTokenCostService.cs, CalculateOpenAICost() method:
"gpt-4o" =>
    (tokens.InputTokens / 1_000_000m * 2.50m) +   // ← Update input price
    (tokens.OutputTokens / 1_000_000m * 10.00m),  // ← Update output price
```

**Check latest pricing:**
- OpenAI: https://openai.com/pricing
- Anthropic: https://www.anthropic.com/pricing
- Google: https://ai.google.dev/pricing

### Add new model pricing

```csharp
// In CalculateOpenAICost(), add new case:
"gpt-5" =>  // ← New model
    (tokens.InputTokens / 1_000_000m * 5.00m) +
    (tokens.OutputTokens / 1_000_000m * 15.00m),
```

### Change styling (Tailwind CSS)

```tsx
// In UserCostDisplay.tsx, modify className attributes:
<div className="bg-white shadow rounded-lg p-6">  // ← Change colors here
```

---

## 📊 WHAT GETS TRACKED

**Automatically tracked for each user:**
- ✅ Total cost (all time)
- ✅ Total tokens used
- ✅ Number of API requests
- ✅ Cost breakdown by LLM provider (OpenAI, Anthropic, Ollama, Google)
- ✅ Cost breakdown by model (gpt-4o, claude-3.5-sonnet, etc.)
- ✅ First and last request timestamps

**Data source:**
- Uses existing `ILLMLogRepository` from myframework.Observability.LLMLogs
- If you're already using myframework's LLM logging, this works immediately
- No additional database tables or configuration needed

---

## 🔒 SECURITY NOTES

**Authentication:**
- Controller requires `[Authorize]` attribute
- Users can only see their own costs via `/api/user-costs/my-summary`
- Admin endpoints (`/api/user-costs/{userId}/summary`) require Admin role

**Adjust userId extraction:**
```csharp
// In UserTokenCostController.cs, GetMyCostSummary():
var userId = User.Identity?.Name;  // ← Works if username = userId

// If you use claims-based userId:
var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

// If you use custom claim:
var userId = User.FindFirst("sub")?.Value; // or "userId", etc.
```

---

## 🐛 TROUBLESHOOTING

### "User not authenticated" error
**Fix:** Ensure you're logged in and have a valid JWT token

### Cost shows as $0.00
**Possible causes:**
1. No LLM usage yet → Use a feature that calls LLMs
2. Pricing not configured for your model → Check CalculateOpenAICost()
3. ILLMLogRepository not capturing logs → Verify myframework.Observability.LLMLogs is set up

**Debug:**
```csharp
// In UserTokenCostService.GetUserTotalCostAsync(), add logging:
var logs = await _logRepository.GetLogsAsync(...);
Console.WriteLine($"Found {logs.Count()} logs for user {userId}");
```

### Component doesn't render
**Fix:**
1. Check browser console for errors
2. Verify API endpoint is reachable: `curl http://localhost:5000/api/user-costs/my-summary`
3. Check CORS if frontend/backend on different ports

### Pricing seems wrong
**Fix:**
1. Verify token counts in LLMLogEntry are correct
2. Check pricing calculation matches provider's pricing page
3. Test with known example:
   ```csharp
   // 1M input tokens + 1M output tokens for gpt-4o should = $12.50
   // (1M * $2.50/M) + (1M * $10/M) = $2.50 + $10 = $12.50
   ```

---

## 📚 FULL DOCUMENTATION

For advanced features, see:
- **C:\scripts\user-cost-tracking-implementation.md** - Complete architecture guide
- **C:\scripts\myframework-dual-app-analysis.md** - Feature analysis and prioritization

---

## 🎯 SUCCESS CHECKLIST

You have successfully integrated per-user cost tracking ONLY IF:

- [ ] Backend builds without errors
- [ ] API endpoint `/api/user-costs/my-summary` returns valid JSON
- [ ] Frontend component renders without console errors
- [ ] User can see their total cost in the UI
- [ ] Cost increases after using AI features (verify after 5 min cache TTL)
- [ ] Cost breakdown shows correct provider/model splits
- [ ] Component styling matches your app's design

**Total time:** ~15 minutes
**Maintenance:** Update pricing quarterly when providers change rates

---

**Need help?** Check troubleshooting section or review full documentation in C:\scripts\user-cost-tracking-implementation.md
