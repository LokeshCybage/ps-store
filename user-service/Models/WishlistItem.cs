using System.ComponentModel.DataAnnotations;

namespace UserService.Models;

public class WishlistItem
{
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid UserId { get; set; }

    [Required]
    public Guid GameId { get; set; }

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
}
