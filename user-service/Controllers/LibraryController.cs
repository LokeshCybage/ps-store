using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UserService.Data;
using UserService.DTOs;
using UserService.Services;

namespace UserService.Controllers;

[ApiController]
[Route("api/library")]
[Authorize]
public class LibraryController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly CatalogClient _catalogClient;

    public LibraryController(AppDbContext context, CatalogClient catalogClient)
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
    public async Task<IActionResult> GetLibrary()
    {
        var userId = GetCurrentUserId();

        var items = await _context.LibraryItems
            .Where(l => l.UserId == userId)
            .OrderByDescending(l => l.PurchasedAt)
            .ToListAsync();

        var gameIds = items.Select(i => i.GameId).ToList();
        var games = await _catalogClient.GetGamesBatchAsync(gameIds);
        var gamesDict = games.ToDictionary(g => g.Id);

        var response = items.Select(item =>
        {
            gamesDict.TryGetValue(item.GameId, out var game);
            return new LibraryItemResponse
            {
                Id = item.Id,
                GameId = item.GameId,
                OrderId = item.OrderId,
                PurchasedAt = item.PurchasedAt,
                Title = game?.Title,
                Price = game?.Price,
                SalePrice = game?.SalePrice,
                ImageUrl = game?.ImageUrl,
                Platform = game?.Platform
            };
        }).ToList();

        return Ok(response);
    }
}
