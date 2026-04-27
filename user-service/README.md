# User Service

PlayStation Store User Service — a .NET 8 Web API handling authentication, user profiles, wishlists, and game libraries.

## Features

- **Authentication**: Register and login with JWT-based auth (BCrypt password hashing)
- **User Profiles**: View and update profile, including order stats from Order Service
- **Wishlist**: Add/remove/list wishlist items, enriched with game details from Catalog Service
- **Library**: View owned games, enriched with game details from Catalog Service
- **Internal APIs**: User validation and library management for inter-service communication

## Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- PostgreSQL running on `localhost:5432` (database: `user_db`)

## Configuration

Environment is configured via `appsettings.json`. Key settings:

| Setting | Default |
|---|---|
| `ConnectionStrings:DefaultConnection` | `Host=localhost;Port=5432;Database=user_db;Username=postgres;Password=postgres` |
| `Jwt:Secret` | `ps-store-jwt-secret-key-change-in-production` |
| `ServiceUrls:CatalogService` | `http://localhost:8001` |
| `ServiceUrls:OrderService` | `http://localhost:8003` |

Override via environment variables using the standard ASP.NET Core pattern (e.g., `ConnectionStrings__DefaultConnection`).

## Build & Run

```bash
cd user-service
dotnet restore
dotnet build
dotnet run
```

The service starts on **http://localhost:8002**.

On first startup, the database is auto-created and an admin user is seeded:
- Username: `admin`
- Password: `admin123`

## API Endpoints

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/api/auth/register` | No | Register a new user |
| POST | `/api/auth/login` | No | Login and get JWT |
| GET | `/api/users/me` | Yes | Get current user profile |
| PUT | `/api/users/me` | Yes | Update profile |
| GET | `/api/wishlist` | Yes | List wishlist items |
| POST | `/api/wishlist` | Yes | Add game to wishlist |
| DELETE | `/api/wishlist/{gameId}` | Yes | Remove from wishlist |
| GET | `/api/library` | Yes | List library items |
| GET | `/internal/users/{userId}/validate` | No | Validate user (internal) |
| POST | `/internal/users/{userId}/library` | No | Add games to library (internal) |
