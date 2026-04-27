using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using UserService.Data;
using UserService.Services;

var builder = WebApplication.CreateBuilder(args);

var otelServiceName = builder.Configuration["OTEL_SERVICE_NAME"] ?? "user-service";
var zipkinEndpoint = builder.Configuration["OTEL_EXPORTER_ZIPKIN_ENDPOINT"]
    ?? builder.Configuration["Zipkin:Endpoint"]
    ?? "http://localhost:9411/api/v2/spans";

builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource.AddService(otelServiceName))
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddZipkinExporter(o => o.Endpoint = new Uri(zipkinEndpoint)));

// Database
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// JWT Authentication
var jwtSecret = builder.Configuration["Jwt:Secret"]!;
var jwtIssuer = builder.Configuration["Jwt:Issuer"]!;
var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret));

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtIssuer,
            ValidateAudience = false,
            ValidateLifetime = true,
            IssuerSigningKey = key,
            ValidateIssuerSigningKey = true
        };
    });

builder.Services.AddAuthorization();

// CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// Services
builder.Services.AddSingleton<TokenService>();

builder.Services.AddHttpClient<CatalogClient>(client =>
{
    client.BaseAddress = new Uri(builder.Configuration["ServiceUrls:CatalogService"]!);
});

builder.Services.AddHttpClient<OrderClient>(client =>
{
    client.BaseAddress = new Uri(builder.Configuration["ServiceUrls:OrderService"]!);
});

builder.Services.AddControllers();

builder.WebHost.UseUrls("http://0.0.0.0:8002");

var app = builder.Build();

// Ensure database created and seed admin user
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    context.Database.EnsureCreated();

    if (!context.Users.Any())
    {
        context.Users.Add(new UserService.Models.User
        {
            Username = "admin",
            Email = "admin@psstore.com",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("admin123"),
            IsAdmin = true
        });
        context.SaveChanges();
    }
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new { status = "healthy", service = "user-service" }));

app.MapControllers();

app.Run();
