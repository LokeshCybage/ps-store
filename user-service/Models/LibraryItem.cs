using System.ComponentModel.DataAnnotations;

namespace UserService.Models;

public class LibraryItem
{
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid UserId { get; set; }

    [Required]
    public Guid GameId { get; set; }

    [Required]
    public Guid OrderId { get; set; }

    public DateTime PurchasedAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
}
