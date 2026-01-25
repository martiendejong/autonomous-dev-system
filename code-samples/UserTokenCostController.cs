// Copy this file to: YourApp/Controllers/UserTokenCostController.cs
// Namespace: Adjust to match your app

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using YourApp.Services; // ← Change this to your namespace

namespace YourApp.Controllers
{
    [ApiController]
    [Route("api/user-costs")]
    [Authorize] // Ensure user is authenticated
    public class UserTokenCostController : ControllerBase
    {
        private readonly IUserTokenCostService _costService;

        public UserTokenCostController(IUserTokenCostService costService)
        {
            _costService = costService;
        }

        /// <summary>
        /// Get total cost summary for current authenticated user
        /// </summary>
        /// <returns>Cost summary with total spend, tokens, and breakdowns</returns>
        [HttpGet("my-summary")]
        [ProducesResponseType(typeof(UserCostSummary), 200)]
        public async Task<ActionResult<UserCostSummary>> GetMyCostSummary()
        {
            // Get userId from authenticated user context
            // Adjust this based on your authentication setup:
            var userId = User.Identity?.Name; // Or User.FindFirst(ClaimTypes.NameIdentifier)?.Value

            if (string.IsNullOrEmpty(userId))
                return Unauthorized("User not authenticated");

            var summary = await _costService.GetUserTotalCostAsync(userId);
            return Ok(summary);
        }

        /// <summary>
        /// Get detailed cost breakdown for current user with date filtering
        /// </summary>
        /// <param name="startDate">Start date (defaults to 30 days ago)</param>
        /// <param name="endDate">End date (defaults to now)</param>
        /// <returns>Detailed breakdown by model, provider, and date</returns>
        [HttpGet("my-breakdown")]
        [ProducesResponseType(typeof(UserCostBreakdown), 200)]
        public async Task<ActionResult<UserCostBreakdown>> GetMyCostBreakdown(
            [FromQuery] DateTime? startDate = null,
            [FromQuery] DateTime? endDate = null)
        {
            var userId = User.Identity?.Name;

            if (string.IsNullOrEmpty(userId))
                return Unauthorized("User not authenticated");

            var breakdown = await _costService.GetUserCostBreakdownAsync(
                userId,
                startDate,
                endDate);
            return Ok(breakdown);
        }

        // ============================================
        // ADMIN-ONLY ENDPOINTS (Optional)
        // ============================================

        /// <summary>
        /// Get cost summary for any user (admin only)
        /// </summary>
        /// <param name="userId">Target user ID</param>
        /// <returns>Cost summary for specified user</returns>
        [HttpGet("{userId}/summary")]
        [Authorize(Roles = "Admin")] // Adjust role name as needed
        [ProducesResponseType(typeof(UserCostSummary), 200)]
        [ProducesResponseType(403)]
        public async Task<ActionResult<UserCostSummary>> GetUserCostSummary(string userId)
        {
            var summary = await _costService.GetUserTotalCostAsync(userId);
            return Ok(summary);
        }

        /// <summary>
        /// Get cost breakdown for any user (admin only)
        /// </summary>
        [HttpGet("{userId}/breakdown")]
        [Authorize(Roles = "Admin")]
        [ProducesResponseType(typeof(UserCostBreakdown), 200)]
        [ProducesResponseType(403)]
        public async Task<ActionResult<UserCostBreakdown>> GetUserCostBreakdown(
            string userId,
            [FromQuery] DateTime? startDate = null,
            [FromQuery] DateTime? endDate = null)
        {
            var breakdown = await _costService.GetUserCostBreakdownAsync(
                userId,
                startDate,
                endDate);
            return Ok(breakdown);
        }
    }
}
