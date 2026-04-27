using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UserService.Data;
using UserService.DTOs;
using UserService.Models;
using UserService.Services;

namespace UserService.Controllers;

[ApiController]
[Route("api/wishlist")]
[Authorize]
public class WishlistController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly CatalogClient _catalogClient;

    public WishlistController(AppDbContext context, CatalogClient catalogClient)
    {
        _context = context;
        _catalogClient = catalogClient;
    }

    private Guid GetCurrentUserId()
    {
        var idClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                   ?? User.FindFirst("sub")?.Value;
        return Guid.Parse(idClaim!);
    }

    [HttpGet]
    public async Task<IActionResult> GetWishlist()
    {
        var userId = GetCurrentUserId();

        var items = await _context.WishlistItems
            .Where(w => w.UserId == userId)
            .OrderByDescending(w => w.AddedAt)
            .ToListAsync();

        var gameIds = items.Select(i => i.GameId).ToList();
        var games = await _catalogClient.GetGamesBatchAsync(gameIds);
        var gamesDict = games.ToDictionary(g => g.Id);

        var response = items.Select(item =>
        {
            gamesDict.TryGetValue(item.GameId, out var game);
            return new WishlistItemResponse
            {
                Id = item.Id,
                GameId = item.GameId,
                AddedAt = item.AddedAt,
                Title = game?.Title,
                Price = game?.Price,
                SalePrice = game?.SalePrice,
                ImageUrl = game?.ImageUrl,
                Platform = game?.Platform
            };
        }).ToList();

        return Ok(response);
    }

    [HttpPost]
    public async Task<IActionResult> AddToWishlist([FromBody] AddWishlistRequest request)
    {
        var userId = GetCurrentUserId();

        var game = await _catalogClient.GetGameAsync(request.GameId);
        if (game == null)
            return NotFound(new { message = "Game not found" });

        var exists = await _context.WishlistItems
            .AnyAsync(w => w.UserId == userId && w.GameId == request.GameId);

        if (exists)
            return Conflict(new { message = "Game already in wishlist" });

        var item = new WishlistItem
        {
            UserId = userId,
            GameId = request.GameId
        };

        _context.WishlistItems.Add(item);
        await _context.SaveChangesAsync();

        return StatusCode(201, new WishlistItemResponse
        {
            Id = item.Id,
            GameId = item.GameId,
            AddedAt = item.AddedAt,
            Title = game.Title,
            Price = game.Price,
            SalePrice = game.SalePrice,
            ImageUrl = game.ImageUrl,
            Platform = game.Platform
        });
    }

    [HttpDelete("{gameId:guid}")]
    public async Task<IActionResult> RemoveFromWishlist(Guid gameId)
    {
        var userId = GetCurrentUserId();

        var item = await _context.WishlistItems
            .FirstOrDefaultAsync(w => w.UserId == userId && w.GameId == gameId);

        if (item == null)
            return NotFound(new { message = "Wishlist item not found" });

        _context.WishlistItems.Remove(item);
        await _context.SaveChangesAsync();

        return NoContent();
    }
}
