# PlayStation Store - Microservices Application

A simplified PlayStation Store clone built as a microservices architecture with 3 backend services and 1 frontend, designed for practicing DevOps tooling (Docker, Kubernetes, CI/CD, SonarQube, etc.).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Frontend (React) :3000                        │
└──────────┬──────────────────┬──────────────────┬────────────────┘
           │                  │                  │
     ┌─────▼─────┐    ┌──────▼──────┐    ┌──────▼──────┐
     │  Game      │◄──►│   User      │◄──►│   Order     │
     │  Catalog   │    │   Service   │    │   Service   │
     │  (Python)  │◄──►│  (.NET 8)   │    │  (Node.js)  │
     │  :8001     │    │   :8002     │    │   :8003     │
     └─────┬──────┘    └──────┬──────┘    └──────┬──────┘
           │                  │                  │
     ┌─────▼──────┐    ┌─────▼──────┐    ┌──────▼─────┐
     │ catalog_db │    │  user_db   │    │  order_db  │
     │ (Postgres) │    │ (Postgres) │    │ (Postgres) │
     └────────────┘    └────────────┘    └────────────┘
```

All 3 backend services communicate with each other (full service mesh), making this ideal for practicing distributed tracing.

## Services

| Service | Tech Stack | Port | Directory |
|---------|-----------|------|-----------|
| Game Catalog | Python, FastAPI, SQLAlchemy | 8001 | `game-catalog-service/` |
| User Service | .NET 8, EF Core | 8002 | `user-service/` |
| Order Service | Node.js, Express | 8003 | `order-service/` |
| Frontend | React 18, Vite | 3000 | `frontend/` |

## Inter-Service Communication

Every backend service calls both other backends (6 directional call paths):

| Direction | Purpose | Endpoint Called |
|-----------|---------|---------------|
| Catalog → Order | Get purchase counts / trending games | `GET /internal/orders/games/{id}/stats`, `GET /internal/orders/popular` |
| Catalog → User | Validate admin before game CRUD | `GET /internal/users/{id}/validate` |
| Order → Catalog | Verify game + price on cart/checkout | `GET /internal/games/{id}` |
| Order → User | Sync library after checkout | `POST /internal/users/{id}/library` |
| User → Catalog | Enrich wishlist/library with game details | `POST /internal/games/batch` |
| User → Order | Get order stats for profile | `GET /internal/orders/user/{id}/stats` |

## Prerequisites

- **PostgreSQL** 14+ running on localhost:5432
- **Python** 3.11+
- **.NET SDK** 8.0
- **Node.js** 20+

## Database Setup

Create 3 databases in PostgreSQL:

```sql
CREATE DATABASE catalog_db;
CREATE DATABASE user_db;
CREATE DATABASE order_db;
```

Tables are auto-created on first startup of each service.

## Running the Services

### 1. Game Catalog Service (Python)

```bash
cd game-catalog-service
pip install -r requirements.txt
python -m uvicorn app.main:app --port 8001 --reload
```

### 2. User Service (.NET)

```bash
cd user-service
dotnet restore
dotnet run
```

### 3. Order Service (Node.js)

```bash
cd order-service
npm install
npm start
```

### 4. Frontend (React)

```bash
cd frontend
npm install
npm run dev
```

Then open http://localhost:3000 in your browser.

## Distributed tracing (OpenTelemetry + Zipkin)

Backends export traces to Zipkin using the standard Zipkin HTTP API (`/api/v2/spans`). Spans use W3C trace context so calls that hop between Catalog, User, and Order appear as one trace.

### Run Zipkin

**Docker Compose** (from the repo root):

```bash
docker compose -f docker-compose.zipkin.yml up -d
```

**Docker CLI:**

```bash
docker run --rm -p 9411:9411 openzipkin/zipkin
```

Open the Zipkin UI at [http://localhost:9411](http://localhost:9411).

### Configuration

All three backends read:

| Variable | Purpose | Default |
|----------|---------|---------|
| `OTEL_EXPORTER_ZIPKIN_ENDPOINT` | Zipkin span ingest URL | `http://localhost:9411/api/v2/spans` |
| `OTEL_SERVICE_NAME` | `service.name` in Zipkin | Per-service default below |

If services run **inside Docker** while Zipkin is on the host, set `OTEL_EXPORTER_ZIPKIN_ENDPOINT` to `http://host.docker.internal:9411/api/v2/spans` (Docker Desktop on Windows/macOS) or your Zipkin service DNS name in Kubernetes.

### Verify

1. Start PostgreSQL, Zipkin, and all three backend services (and optionally the frontend).
2. Trigger cross-service traffic, for example open the storefront or call an API that hits internals (see **Inter-Service Communication** above).
3. In Zipkin, click **Run Query** — you should see traces containing spans from `game-catalog-service`, `user-service`, and `order-service` sharing the same trace id.

## Default Credentials

An admin user is auto-created on first startup of the User Service:
- **Username:** admin
- **Password:** admin123

## Environment Variables

### Game Catalog Service
| Variable | Default |
|----------|---------|
| `DATABASE_URL` | `postgresql://postgres:postgres@localhost:5432/catalog_db` |
| `PORT` | `8001` |
| `JWT_SECRET` | `ps-store-jwt-secret-key-change-in-production` |
| `ORDER_SERVICE_URL` | `http://localhost:8003` |
| `USER_SERVICE_URL` | `http://localhost:8002` |
| `OTEL_EXPORTER_ZIPKIN_ENDPOINT` | `http://localhost:9411/api/v2/spans` |
| `OTEL_SERVICE_NAME` | `game-catalog-service` |

### User Service
| Variable | Default |
|----------|---------|
| `ConnectionStrings__DefaultConnection` | `Host=localhost;Port=5432;Database=user_db;...` |
| `Jwt__Secret` | `ps-store-jwt-secret-key-change-in-production` |
| `Jwt__Issuer` | `ps-store` |
| `ASPNETCORE_URLS` | `http://+:8002` |
| `ServiceUrls__CatalogService` | `http://localhost:8001` |
| `ServiceUrls__OrderService` | `http://localhost:8003` |
| `OTEL_EXPORTER_ZIPKIN_ENDPOINT` | `http://localhost:9411/api/v2/spans` |
| `OTEL_SERVICE_NAME` | `user-service` |
| `Zipkin__Endpoint` | `http://localhost:9411/api/v2/spans` (see `appsettings.json`) |

### Order Service
| Variable | Default |
|----------|---------|
| `DATABASE_URL` | `postgresql://postgres:postgres@localhost:5432/order_db` |
| `PORT` | `8003` |
| `JWT_SECRET` | `ps-store-jwt-secret-key-change-in-production` |
| `CATALOG_SERVICE_URL` | `http://localhost:8001` |
| `USER_SERVICE_URL` | `http://localhost:8002` |
| `OTEL_EXPORTER_ZIPKIN_ENDPOINT` | `http://localhost:9411/api/v2/spans` |
| `OTEL_SERVICE_NAME` | `order-service` |

### Frontend
| Variable | Default |
|----------|---------|
| `VITE_CATALOG_API` | `http://localhost:8001` |
| `VITE_USER_API` | `http://localhost:8002` |
| `VITE_ORDER_API` | `http://localhost:8003` |

## DevOps Practice Opportunities

This application is structured for practicing:

- **Dockerfiles** - One per service (Python, .NET, Node.js, React/Nginx)
- **Docker Compose** - Orchestrate all services + PostgreSQL
- **Kubernetes** - Deployments, Services, ConfigMaps, Secrets, Ingress
- **CI/CD Pipelines** - GitHub Actions, GitLab CI, Jenkins, Azure DevOps
- **SonarQube** - Code quality analysis for all 3 languages
- **API Gateway** - Nginx, Kong, or Traefik in front of services
- **Distributed Tracing** - OpenTelemetry → Zipkin (see **Distributed tracing** above); Jaeger is an optional swap-in
- **Monitoring** - Prometheus + Grafana with health endpoints
- **Message Brokers** - RabbitMQ/Kafka for async communication
- **Service Mesh** - Istio or Linkerd on Kubernetes
