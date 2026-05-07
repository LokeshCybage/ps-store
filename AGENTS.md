# AGENTS.md

## Cursor Cloud specific instructions

This is a multi-service PlayStation Store clone (microservices architecture). See `README.md` for full architecture details, environment variables, and inter-service communication paths.

### Services overview

| Service | Directory | Port | Runtime |
|---------|-----------|------|---------|
| Game Catalog | `game-catalog-service/` | 8001 | Python 3.11+ / FastAPI |
| User Service | `user-service/` | 8002 | .NET 8 / ASP.NET Core |
| Order Service | `order-service/` | 8003 | Node.js 20+ / Express |
| Frontend | `frontend/` | 3000 | React 18 / Vite |

### Starting services (after dependencies are installed)

1. **PostgreSQL** must be running on localhost:5432 with databases `catalog_db`, `user_db`, `order_db` (user/pass: postgres/postgres).
   ```bash
   sudo pg_ctlcluster 16 main start
   ```
2. **Game Catalog**: `cd game-catalog-service && python3 -m uvicorn app.main:app --port 8001 --reload`
3. **User Service**: `cd user-service && dotnet run`
4. **Order Service**: `cd order-service && npm start`
5. **Frontend**: `cd frontend && npm run dev`

Services auto-create tables on first startup. The catalog service seeds sample games and the user service creates an admin user (`admin`/`admin123`).

### Running tests

- **game-catalog-service**: `cd game-catalog-service && python3 -m pytest tests/ -v`
- **user-service**: `cd user-service/UserService.Tests && dotnet test`
- **order-service**: `cd order-service && npx jest --ci`
- **frontend**: `cd frontend && npx vitest run`

### Non-obvious caveats

- There is **no ESLint or dedicated linter** configured in this repo. The .NET build (`dotnet build`) serves as the closest compile-time check for user-service.
- The Python command is `python3` (not `python`) in this environment.
- `pip install` installs to `~/.local/bin` which must be on PATH for `uvicorn` CLI. Using `python3 -m uvicorn` avoids PATH issues.
- All three backends export OpenTelemetry traces to Zipkin (port 9411) but run fine without Zipkin — trace export errors are logged but non-fatal.
- The cart API uses `game_id` (snake_case), not `gameId`.
- Health endpoints: `GET /health` on all three backend services.
