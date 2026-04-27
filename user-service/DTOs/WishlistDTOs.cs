using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace UserService.DTOs;

public class AddWishlistRequest
{
    [Required]
    [JsonPropertyName("game_id")]
    public Guid GameId { get; set; }
}

public class WishlistItemResponse
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("game_id")]
    public Guid GameId { get; set; }

    [JsonPropertyName("added_at")]
    public DateTime AddedAt { get; set; }

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
