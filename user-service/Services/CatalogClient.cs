using System.Net.Http.Json;
using System.Text.Json.Serialization;

namespace UserService.Services;

public record GameInfo
{
    [JsonPropertyName("id")]
    public Guid Id { get; init; }

    [JsonPropertyName("title")]
    public string Title { get; init; } = string.Empty;

    [JsonPropertyName("price")]
    public decimal Price { get; init; }

    [JsonPropertyName("sale_price")]
    public decimal? SalePrice { get; init; }

    [JsonPropertyName("image_url")]
    public string? ImageUrl { get; init; }

    [JsonPropertyName("platform")]
    public string? Platform { get; init; }
}

public class CatalogClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<CatalogClient> _logger;

    public CatalogClient(HttpClient httpClient, ILogger<CatalogClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<GameInfo?> GetGameAsync(Guid gameId)
    {
        try
        {
            var response = await _httpClient.GetAsync($"/internal/games/{gameId}");
            if (!response.IsSuccessStatusCode) return null;
            return await response.Content.ReadFromJsonAsync<GameInfo>();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to fetch game {GameId} from catalog service", gameId);
            return null;
        }
    }

    public async Task<List<GameInfo>> GetGamesBatchAsync(List<Guid> gameIds)
    {
        try
        {
            var response = await _httpClient.PostAsJsonAsync("/internal/games/batch", new { game_ids = gameIds });
            if (!response.IsSuccessStatusCode) return new List<GameInfo>();
            return await response.Content.ReadFromJsonAsync<List<GameInfo>>() ?? new List<GameInfo>();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to fetch games batch from catalog service");
            return new List<GameInfo>();
        }
    }
}
