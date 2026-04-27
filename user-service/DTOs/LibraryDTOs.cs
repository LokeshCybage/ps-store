using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace UserService.DTOs;

public class LibraryItemResponse
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("game_id")]
    public Guid GameId { get; set; }

    [JsonPropertyName("order_id")]
    public Guid OrderId { get; set; }

    [JsonPropertyName("purchased_at")]
    public DateTime PurchasedAt { get; set; }

    [JsonPropertyName("title")]
    public string? Title { get; set; }

    [JsonPropertyName("price")]
    public decimal? Price { get; set; }

    [JsonPropertyName("sale_price")]
    public decimal? SalePrice { get; set; }

    [JsonPropertyName("image_url")]
    public string? ImageUrl { get; set; }

    [JsonPropertyName("platform")]
    public string? Platform { get; set; }
}

public class AddToLibraryRequest
{
    [Required]
    [JsonPropertyName("game_ids")]
    public List<Guid> GameIds { get; set; } = new();

    [Required]
    [JsonPropertyName("order_id")]
    public Guid OrderId { get; set; }
}
