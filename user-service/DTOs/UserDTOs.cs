using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace UserService.DTOs;

public class UserResponse
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("username")]
    public string Username { get; set; } = string.Empty;

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("avatar_url")]
    public string? AvatarUrl { get; set; }

    [JsonPropertyName("is_admin")]
    public bool IsAdmin { get; set; }

    [JsonPropertyName("created_at")]
    public DateTime CreatedAt { get; set; }

    [JsonPropertyName("order_count")]
    public int OrderCount { get; set; }

    [JsonPropertyName("total_spent")]
    public decimal TotalSpent { get; set; }
}

public class UpdateProfileRequest
{
    [MaxLength(50)]
    public string? Username { get; set; }

    [EmailAddress, MaxLength(100)]
    public string? Email { get; set; }

    [JsonPropertyName("avatar_url")]
    public string? AvatarUrl { get; set; }
}
