// Copy this file to: YourApp/Services/UserTokenCostService.cs
// Namespace: Adjust to match your app (e.g., ClientManagerAPI.Services or ArtRevisionistAPI.Services)

using Hazina.Observability.LLMLogs.Storage;
using Hazina.AI.Compression.TokenCounting;
using Microsoft.Extensions.Caching.Memory;

namespace YourApp.Services
{
    // ============================================
    // DATA MODELS
    // ============================================

    public class UserCostSummary
    {
        public string UserId { get; set; }
        public decimal TotalCost { get; set; }
        public long TotalTokens { get; set; }
        public int TotalRequests { get; set; }
        public DateTime FirstRequest { get; set; }
        public DateTime LastRequest { get; set; }
        public Dictionary<string, decimal> CostByProvider { get; set; } = new();
        public Dictionary<string, decimal> CostByModel { get; set; } = new();
    }

    public class UserCostBreakdown
    {
        public string UserId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public decimal TotalCost { get; set; }
        public List<CostByModel> ModelBreakdown { get; set; } = new();
        public List<CostByProvider> ProviderBreakdown { get; set; } = new();
        public List<CostByDate> DailyBreakdown { get; set; } = new();
    }

    public class CostByModel
    {
        public string Model { get; set; }
        public decimal Cost { get; set; }
        public long Tokens { get; set; }
        public int RequestCount { get; set; }
        public decimal AverageCostPerRequest { get; set; }
    }

    public class CostByProvider
    {
        public string Provider { get; set; }
        public decimal Cost { get; set; }
        public long Tokens { get; set; }
        public int RequestCount { get; set; }
    }

    public class CostByDate
    {
        public DateTime Date { get; set; }
        public decimal Cost { get; set; }
        public long Tokens { get; set; }
        public int RequestCount { get; set; }
    }

    // ============================================
    // SERVICE INTERFACE
    // ============================================

    public interface IUserTokenCostService
    {
        Task<UserCostSummary> GetUserTotalCostAsync(string userId);
        Task<UserCostBreakdown> GetUserCostBreakdownAsync(
            string userId,
            DateTime? startDate = null,
            DateTime? endDate = null);
    }

    // ============================================
    // SERVICE IMPLEMENTATION
    // ============================================

    public class UserTokenCostService : IUserTokenCostService
    {
        private readonly ILLMLogRepository _logRepository;
        private readonly IMemoryCache _cache;
        private const int CacheDurationMinutes = 5;

        public UserTokenCostService(
            ILLMLogRepository logRepository,
            IMemoryCache cache)
        {
            _logRepository = logRepository;
            _cache = cache;
        }

        public async Task<UserCostSummary> GetUserTotalCostAsync(string userId)
        {
            var cacheKey = $"user_cost_summary_{userId}";

            if (_cache.TryGetValue(cacheKey, out UserCostSummary cached))
                return cached;

            // Get all logs for this user
            var logs = await _logRepository.GetLogsAsync(
                startDate: DateTime.MinValue,
                endDate: DateTime.MaxValue,
                userId: userId);

            if (!logs.Any())
            {
                return new UserCostSummary
                {
                    UserId = userId,
                    TotalCost = 0,
                    TotalTokens = 0,
                    TotalRequests = 0,
                    FirstRequest = DateTime.UtcNow,
                    LastRequest = DateTime.UtcNow
                };
            }

            var summary = new UserCostSummary
            {
                UserId = userId,
                TotalCost = logs.Sum(l => CalculateCost(l)),
                TotalTokens = logs.Sum(l => l.TokenUsage.TotalTokens),
                TotalRequests = logs.Count(),
                FirstRequest = logs.Min(l => l.Timestamp),
                LastRequest = logs.Max(l => l.Timestamp),
                CostByProvider = logs
                    .GroupBy(l => l.Provider)
                    .ToDictionary(
                        g => g.Key,
                        g => g.Sum(l => CalculateCost(l))),
                CostByModel = logs
                    .GroupBy(l => l.Model)
                    .ToDictionary(
                        g => g.Key,
                        g => g.Sum(l => CalculateCost(l)))
            };

            _cache.Set(cacheKey, summary, TimeSpan.FromMinutes(CacheDurationMinutes));
            return summary;
        }

        public async Task<UserCostBreakdown> GetUserCostBreakdownAsync(
            string userId,
            DateTime? startDate = null,
            DateTime? endDate = null)
        {
            var start = startDate ?? DateTime.UtcNow.AddDays(-30);
            var end = endDate ?? DateTime.UtcNow;

            var logs = await _logRepository.GetLogsAsync(start, end, userId: userId);

            var breakdown = new UserCostBreakdown
            {
                UserId = userId,
                StartDate = start,
                EndDate = end,
                TotalCost = logs.Sum(l => CalculateCost(l)),
                ModelBreakdown = logs
                    .GroupBy(l => l.Model)
                    .Select(g => new CostByModel
                    {
                        Model = g.Key,
                        Cost = g.Sum(l => CalculateCost(l)),
                        Tokens = g.Sum(l => l.TokenUsage.TotalTokens),
                        RequestCount = g.Count(),
                        AverageCostPerRequest = g.Count() > 0 ? g.Average(l => CalculateCost(l)) : 0
                    })
                    .OrderByDescending(m => m.Cost)
                    .ToList(),
                ProviderBreakdown = logs
                    .GroupBy(l => l.Provider)
                    .Select(g => new CostByProvider
                    {
                        Provider = g.Key,
                        Cost = g.Sum(l => CalculateCost(l)),
                        Tokens = g.Sum(l => l.TokenUsage.TotalTokens),
                        RequestCount = g.Count()
                    })
                    .OrderByDescending(p => p.Cost)
                    .ToList(),
                DailyBreakdown = logs
                    .GroupBy(l => l.Timestamp.Date)
                    .Select(g => new CostByDate
                    {
                        Date = g.Key,
                        Cost = g.Sum(l => CalculateCost(l)),
                        Tokens = g.Sum(l => l.TokenUsage.TotalTokens),
                        RequestCount = g.Count()
                    })
                    .OrderBy(d => d.Date)
                    .ToList()
            };

            return breakdown;
        }

        // ============================================
        // PRICING CALCULATIONS (UPDATE QUARTERLY)
        // ============================================

        private decimal CalculateCost(LLMLogEntry log)
        {
            return log.Provider switch
            {
                "OpenAI" => CalculateOpenAICost(log.Model, log.TokenUsage),
                "Anthropic" => CalculateAnthropicCost(log.Model, log.TokenUsage),
                "Ollama" => 0m, // Local inference = free
                "Google" => CalculateGoogleCost(log.Model, log.TokenUsage),
                _ => 0m
            };
        }

        private decimal CalculateOpenAICost(string model, TokenUsageInfo tokens)
        {
            // Pricing as of January 2026
            // Source: https://openai.com/pricing
            return model switch
            {
                "gpt-4o" =>
                    (tokens.InputTokens / 1_000_000m * 2.50m) +
                    (tokens.OutputTokens / 1_000_000m * 10.00m),
                "gpt-4o-mini" =>
                    (tokens.InputTokens / 1_000_000m * 0.15m) +
                    (tokens.OutputTokens / 1_000_000m * 0.60m),
                "gpt-4-turbo" or "gpt-4-turbo-2024-04-09" =>
                    (tokens.InputTokens / 1_000_000m * 10.00m) +
                    (tokens.OutputTokens / 1_000_000m * 30.00m),
                "gpt-4" or "gpt-4-0613" =>
                    (tokens.InputTokens / 1_000_000m * 30.00m) +
                    (tokens.OutputTokens / 1_000_000m * 60.00m),
                "gpt-3.5-turbo" or "gpt-3.5-turbo-0125" =>
                    (tokens.InputTokens / 1_000_000m * 0.50m) +
                    (tokens.OutputTokens / 1_000_000m * 1.50m),
                "text-embedding-3-small" =>
                    tokens.TotalTokens / 1_000_000m * 0.02m,
                "text-embedding-3-large" =>
                    tokens.TotalTokens / 1_000_000m * 0.13m,
                "text-embedding-ada-002" =>
                    tokens.TotalTokens / 1_000_000m * 0.10m,
                _ => 0m
            };
        }

        private decimal CalculateAnthropicCost(string model, TokenUsageInfo tokens)
        {
            // Pricing as of January 2026
            // Source: https://www.anthropic.com/pricing
            return model switch
            {
                "claude-3-5-sonnet-20241022" or "claude-3-5-sonnet-latest" =>
                    (tokens.InputTokens / 1_000_000m * 3.00m) +
                    (tokens.OutputTokens / 1_000_000m * 15.00m),
                "claude-3-opus-20240229" =>
                    (tokens.InputTokens / 1_000_000m * 15.00m) +
                    (tokens.OutputTokens / 1_000_000m * 75.00m),
                "claude-3-sonnet-20240229" =>
                    (tokens.InputTokens / 1_000_000m * 3.00m) +
                    (tokens.OutputTokens / 1_000_000m * 15.00m),
                "claude-3-haiku-20240307" =>
                    (tokens.InputTokens / 1_000_000m * 0.25m) +
                    (tokens.OutputTokens / 1_000_000m * 1.25m),
                _ => 0m
            };
        }

        private decimal CalculateGoogleCost(string model, TokenUsageInfo tokens)
        {
            // Pricing as of January 2026
            // Source: https://ai.google.dev/pricing
            return model switch
            {
                "gemini-pro" or "gemini-1.0-pro" =>
                    (tokens.InputTokens / 1_000_000m * 0.50m) +
                    (tokens.OutputTokens / 1_000_000m * 1.50m),
                "gemini-pro-vision" or "gemini-1.0-pro-vision" =>
                    (tokens.InputTokens / 1_000_000m * 0.50m) +
                    (tokens.OutputTokens / 1_000_000m * 1.50m),
                "gemini-1.5-pro" or "gemini-1.5-pro-latest" =>
                    (tokens.InputTokens / 1_000_000m * 1.25m) +
                    (tokens.OutputTokens / 1_000_000m * 5.00m),
                "gemini-1.5-flash" or "gemini-1.5-flash-latest" =>
                    (tokens.InputTokens / 1_000_000m * 0.075m) +
                    (tokens.OutputTokens / 1_000_000m * 0.30m),
                _ => 0m
            };
        }
    }
}
