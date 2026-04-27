# Order Service

Order and cart microservice for the PlayStation Store application. Handles shopping cart management, checkout, and order history.

## Prerequisites

- Node.js 20+
- PostgreSQL with a database named `order_db`

## Install

```bash
npm install
```

## Run

```bash
npm start
```

The service starts on port **8003** by default.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `postgresql://postgres:postgres@localhost:5432/order_db` | PostgreSQL connection string |
| `PORT` | `8003` | HTTP port |
| `JWT_SECRET` | `ps-store-jwt-secret-key-change-in-production` | Secret for JWT verification |
| `CATALOG_SERVICE_URL` | `http://localhost:8001` | Catalog service base URL |
| `USER_SERVICE_URL` | `http://localhost:8002` | User service base URL |

## API Endpoints

### Public (require JWT)

| Method | Path | Description |
|---|---|---|
| GET | `/api/cart` | Get cart items |
| POST | `/api/cart` | Add game to cart |
| DELETE | `/api/cart/:gameId` | Remove game from cart |
| DELETE | `/api/cart` | Clear cart |
| POST | `/api/orders/checkout` | Checkout cart |
| GET | `/api/orders` | Order history |
| GET | `/api/orders/:id` | Order details |

### Internal (no auth)

| Method | Path | Description |
|---|---|---|
| GET | `/internal/orders/games/:gameId/stats` | Game purchase count |
| GET | `/internal/orders/popular` | Top 10 popular games |
| GET | `/internal/orders/user/:userId/stats` | User order stats |

### Health

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Service health check |
