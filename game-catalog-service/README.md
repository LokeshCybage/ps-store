# Game Catalog Service

A FastAPI microservice that manages the game catalog for a PlayStation Store-inspired application. Provides public APIs for browsing, searching, and managing games, plus internal endpoints for service-to-service communication.

## Features

- Browse and search games by category, platform, title, and sale status
- Featured games endpoint with deals and trending sections
- Admin-only game CRUD operations (JWT-authenticated)
- Internal APIs for other microservices (Order Service, User Service)
- Automatic database seeding with sample PlayStation-style games

## Prerequisites

- Python 3.11+
- PostgreSQL with a database named `catalog_db`

## Installation

```bash
cd game-catalog-service
pip install -r requirements.txt
```

## Environment Variables

| Variable            | Default                                                    | Description                  |
| ------------------- | ---------------------------------------------------------- | ---------------------------- |
| `DATABASE_URL`      | `postgresql://postgres:postgres@localhost:5432/catalog_db`  | PostgreSQL connection string |
| `PORT`              | `8001`                                                     | Server port                  |
| `JWT_SECRET`        | `ps-store-jwt-secret-key-change-in-production`             | Secret for JWT verification  |
| `ORDER_SERVICE_URL` | `http://localhost:8003`                                    | Order Service base URL       |
| `USER_SERVICE_URL`  | `http://localhost:8002`                                    | User Service base URL        |

## Running

```bash
python -m uvicorn app.main:app --port 8001
```

Or with auto-reload during development:

```bash
python -m uvicorn app.main:app --port 8001 --reload
```

The API docs are available at `http://localhost:8001/docs` once the server is running.

## API Endpoints

### Public

| Method | Path                  | Description              |
| ------ | --------------------- | ------------------------ |
| GET    | `/health`             | Health check             |
| GET    | `/api/games`          | List/search games        |
| GET    | `/api/games/featured` | Deals and trending games |
| GET    | `/api/games/{id}`     | Game details             |
| GET    | `/api/categories`     | List categories          |
| POST   | `/api/games`          | Create game (admin)      |
| PUT    | `/api/games/{id}`     | Update game (admin)      |
| DELETE | `/api/games/{id}`     | Delete game (admin)      |

### Internal (service-to-service)

| Method | Path                      | Description             |
| ------ | ------------------------- | ----------------------- |
| GET    | `/internal/games/{id}`    | Lightweight game detail |
| POST   | `/internal/games/batch`   | Batch fetch games       |
