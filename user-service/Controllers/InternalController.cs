using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UserService.Data;
using UserService.DTOs;
using UserService.Models;

namespace UserService.Controllers;

[ApiController]
[Route("internal")]
[AllowAnonymous]
public class InternalController : ControllerBase
{
    private readonly AppDbContext _context;

    public InternalController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet("users/{userId:guid}/validate")]
    public async Task<IActionResult> ValidateUser(Guid userId)
    {
        var user = await _context.Users.FindAsync(userId);

        if (user == null)
            return Ok(new ValidateUserResponse { Exists = false });

        return Ok(new ValidateUserResponse
        {
            UserId = user.Id,
            Username = user.Username,
            IsAdmin = user.IsAdmin,
            Exists = true
        });
    }

    [HttpPost("users/{userId:guid}/library")]
    public async Task<IActionResult> AddToLibrary(Guid userId, [FromBody] AddToLibraryRequest request)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null)
            return NotFound(new { message = "User not found" });

        foreach (var gameId in request.GameIds)
        {
            var exists = await _context.LibraryItems
                .AnyAsync(l => l.UserId == userId && l.GameId == gameId);

            if (exists) continue;

            _context.LibraryItems.Add(new LibraryItem
            {
                UserId = userId,
                GameId = gameId,
                OrderId = request.OrderId
            });
        }

        await _context.SaveChangesAsync();
        return Ok(new { message = "Library updated" });
    }
}
