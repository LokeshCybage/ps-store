using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UserService.Data;
using UserService.DTOs;
using UserService.Services;

namespace UserService.Controllers;

[ApiController]
[Route("api/users")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly OrderClient _orderClient;

    public UsersController(AppDbContext context, OrderClient orderClient)
    {
        _context = context;
        _orderClient = orderClient;
    }

    private Guid GetCurrentUserId()
    {
        var idClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                   ?? User.FindFirst("sub")?.Value;
        return Guid.Parse(idClaim!);
    }

    [HttpGet("me")]
    public async Task<IActionResult> GetProfile()
    {
        var userId = GetCurrentUserId();
        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound();

        var stats = await _orderClient.GetUserStatsAsync(userId);

        return Ok(new UserResponse
        {
            Id = user.Id,
            Username = user.Username,
            Email = user.Email,
            AvatarUrl = user.AvatarUrl,
            IsAdmin = user.IsAdmin,
            CreatedAt = user.CreatedAt,
            OrderCount = stats?.OrderCount ?? 0,
            TotalSpent = stats?.TotalSpent ?? 0m
        });
    }

    [HttpPut("me")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest request)
    {
        var userId = GetCurrentUserId();
        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound();

        if (!string.IsNullOrWhiteSpace(request.Username))
        {
            var taken = await _context.Users.AnyAsync(u => u.Username == request.Username && u.Id != userId);
            if (taken) return Conflict(new { message = "Username already taken" });
            user.Username = request.Username;
        }

        if (!string.IsNullOrWhiteSpace(request.Email))
        {
            var taken = await _context.Users.AnyAsync(u => u.Email == request.Email && u.Id != userId);
            if (taken) return Conflict(new { message = "Email already taken" });
            user.Email = request.Email;
        }

        if (request.AvatarUrl != null)
            user.AvatarUrl = request.AvatarUrl;

        await _context.SaveChangesAsync();

        return Ok(new UserResponse
        {
            Id = user.Id,
            Username = user.Username,
            Email = user.Email,
            AvatarUrl = user.AvatarUrl,
            IsAdmin = user.IsAdmin,
            CreatedAt = user.CreatedAt
        });
    }
}
