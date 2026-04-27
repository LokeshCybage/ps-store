# Dockerfile Templates by Tech Stack

Ready-to-use templates for each service in this project. Adapt versions and paths as needed.

## Python (FastAPI) — Game Catalog Service

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS builder
WORKDIR /build

COPY requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

COPY . .

FROM python:3.12-slim
WORKDIR /app

RUN useradd --no-create-home -u 1000 appuser

COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin/uvicorn /usr/local/bin/uvicorn
COPY --from=builder /build/app ./app

USER appuser
EXPOSE 8001

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8001/health')" || exit 1

ENTRYPOINT ["uvicorn"]
CMD ["app.main:app", "--host", "0.0.0.0", "--port", "8001"]
```

## .NET 8 — User Service

```dockerfile
# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS builder
WORKDIR /build

COPY *.csproj ./
RUN --mount=type=cache,target=/root/.nuget \
    dotnet restore

COPY . .
RUN dotnet publish -c Release -o /publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

RUN useradd --no-create-home -u 1000 appuser

COPY --from=builder /publish .

USER appuser
EXPOSE 8002

ENV ASPNETCORE_URLS=http://+:8002

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8002/health || exit 1

ENTRYPOINT ["dotnet"]
CMD ["UserService.dll"]
```

## Node.js (Express) — Order Service

```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-slim AS builder
WORKDIR /build

COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

COPY . .

FROM node:20-slim
WORKDIR /app

RUN useradd --no-create-home -u 1000 appuser

COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/src ./src
COPY --from=builder /build/package.json ./

USER appuser
EXPOSE 8003

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8003/health || exit 1

ENTRYPOINT ["node"]
CMD ["src/index.js"]
```

## React (Vite) + Nginx — Frontend

```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-slim AS builder
WORKDIR /build

COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=builder /build/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

RUN adduser -D -u 1000 appuser && \
    chown -R appuser:appuser /var/cache/nginx /var/log/nginx /usr/share/nginx/html
USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget -qO- http://localhost:3000/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

## Docker Compose — Full Stack

```yaml
services:
  postgres:
    image: postgres:16.2-alpine
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
    tmpfs:
      - /tmp
      - /run/postgresql
    env_file:
      - .env
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M

  game-catalog:
    build:
      context: ./game-catalog-service
      dockerfile: Dockerfile
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
    ports:
      - "8001:8001"
    env_file:
      - .env
    environment:
      DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/catalog_db
      ORDER_SERVICE_URL: http://order-service:8003
      USER_SERVICE_URL: http://user-service:8002
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8001/health')"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
        reservations:
          cpus: "0.1"
          memory: 64M

  user-service:
    build:
      context: ./user-service
      dockerfile: Dockerfile
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
    ports:
      - "8002:8002"
    env_file:
      - .env
    environment:
      ConnectionStrings__DefaultConnection: Host=postgres;Port=5432;Database=user_db;Username=postgres;Password=${POSTGRES_PASSWORD}
      ServiceUrls__CatalogService: http://game-catalog:8001
      ServiceUrls__OrderService: http://order-service:8003
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8002/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
        reservations:
          cpus: "0.1"
          memory: 64M

  order-service:
    build:
      context: ./order-service
      dockerfile: Dockerfile
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
    ports:
      - "8003:8003"
    env_file:
      - .env
    environment:
      DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/order_db
      CATALOG_SERVICE_URL: http://game-catalog:8001
      USER_SERVICE_URL: http://user-service:8002
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8003/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
        reservations:
          cpus: "0.1"
          memory: 64M

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
    ports:
      - "3000:3000"
    depends_on:
      - game-catalog
      - user-service
      - order-service
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 128M
        reservations:
          cpus: "0.1"
          memory: 32M

volumes:
  postgres_data:
```
