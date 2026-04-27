using System.Net.Http.Json;
using System.Text.Json.Serialization;

namespace UserService.Services;

public record UserOrderStats
{
    [JsonPropertyName("order_count")]
    public int OrderCount { get; init; }

    [JsonPropertyName("total_spent")]
    public decimal TotalSpent { get; init; }
}

public class OrderClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<OrderClient> _logger;

    public OrderClient(HttpClient httpClient, ILogger<OrderClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<UserOrderStats?> GetUserStatsAsync(Guid userId)
    {
        try
        {
            var response = await _httpClient.GetAsync($"/internal/orders/user/{userId}/stats");
            if (!response.IsSuccessStatusCode) return null;
            return await response.Content.ReadFromJsonAsync<UserOrderStats>();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to fetch order stats for user {UserId}", userId);
            return null;
        }
    }
}
