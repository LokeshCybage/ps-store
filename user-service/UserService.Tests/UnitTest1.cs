using System.IdentityModel.Tokens.Jwt;
using Microsoft.Extensions.Configuration;
using UserService.Models;
using UserService.Services;

namespace UserService.Tests;

public class TokenServiceTests
{
    [Fact]
    public void GenerateToken_IncludesExpectedClaims()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Jwt:Secret"] = "this-is-a-test-secret-long-enough-for-hmac",
                ["Jwt:Issuer"] = "ps-store-tests",
                ["Jwt:ExpiryHours"] = "24",
            })
            .Build();

        var svc = new TokenService(config);
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "alice",
            Email = "alice@example.com",
            IsAdmin = true,
            PasswordHash = "hash",
        };

        var token = svc.GenerateToken(user);

        var jwt = new JwtSecurityTokenHandler().ReadJwtToken(token);
        Assert.Equal("ps-store-tests", jwt.Issuer);
        Assert.Contains(jwt.Claims, c => c.Type == JwtRegisteredClaimNames.Sub && c.Value == user.Id.ToString());
        Assert.Contains(jwt.Claims, c => c.Type == "username" && c.Value == "alice");
        Assert.Contains(jwt.Claims, c => c.Type == "email" && c.Value == "alice@example.com");
        Assert.Contains(jwt.Claims, c => c.Type == "is_admin" && c.Value == "true");
    }
}