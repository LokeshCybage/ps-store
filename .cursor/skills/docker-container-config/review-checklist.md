# Docker Configuration Review Checklist

Detailed checklist with examples for reviewing Docker and container configurations.

## Dockerfile Review

### Structure Issues

**Missing parser directive:**
```dockerfile
# Bad
FROM node:20-slim

# Good
# syntax=docker/dockerfile:1
FROM node:20-slim
```

**Single-stage build (ships build tools in production):**
```dockerfile
# Bad
FROM node:20
COPY . .
RUN npm install && npm run build
CMD ["node", "dist/index.js"]

# Good
FROM node:20-slim AS builder
WORKDIR /build
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-slim
WORKDIR /app
COPY --from=builder /build/dist ./dist
COPY --from=builder /build/node_modules ./node_modules
CMD ["node", "dist/index.js"]
```

**Unpinned base image:**
```dockerfile
# Bad — mutable tag
FROM node:latest
FROM python:3

# Good — pinned version
FROM node:20.11-slim
FROM python:3.12-slim

# Best — pinned digest
FROM node:20.11-slim@sha256:abc123...
```

**Poor layer caching (source copied before deps):**
```dockerfile
# Bad — any source change invalidates npm install cache
COPY . .
RUN npm install

# Good — deps cached until package.json changes
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
```

### Security Issues

**Running as root:**
```dockerfile
# Bad — defaults to root
FROM node:20-slim
COPY . /app
CMD ["node", "app/index.js"]

# Good — explicit non-root user
FROM node:20-slim
RUN useradd --no-create-home -u 1000 appuser
WORKDIR /app
COPY --chown=appuser:appuser . .
USER appuser
CMD ["node", "index.js"]
```

**Secrets baked into image:**
```dockerfile
# Bad — secret persists in image layer
ENV NPM_TOKEN=abc123
COPY .npmrc /root/.npmrc

# Good — BuildKit secret mount
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) npm ci
```

**Using ADD instead of COPY:**
```dockerfile
# Bad — ADD has implicit behaviors
ADD . /app
ADD https://example.com/file.tar.gz /tmp/

# Good — explicit and predictable
COPY . /app
RUN curl -o /tmp/file.tar.gz https://example.com/file.tar.gz
```

### Missing Best Practices

**No HEALTHCHECK:**
```dockerfile
# Add to every Dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

**No WORKDIR set:**
```dockerfile
# Bad
COPY . /app
RUN cd /app && npm ci

# Good
WORKDIR /app
COPY . .
RUN npm ci
```

**No cache mounts:**
```dockerfile
# Without cache mount — downloads every build
RUN npm ci

# With cache mount — reuses cached packages
RUN --mount=type=cache,target=/root/.npm npm ci
```

## .dockerignore Review

**Missing .dockerignore** inflates build context and may leak secrets.

**Minimum entries by stack:**

| Stack | Must exclude |
|-------|-------------|
| All | `.git`, `.env`, `.env.*`, `**/*.log`, `.vscode`, `.idea` |
| Node.js | `node_modules`, `dist`, `coverage` |
| Python | `__pycache__`, `*.pyc`, `.venv`, `venv` |
| .NET | `bin`, `obj` |

## Docker Compose Review

**Missing resource limits:**
```yaml
# Bad — no limits, can consume all host resources
services:
  api:
    image: my-app:1.0

# Good — bounded resource usage
services:
  api:
    image: my-app:1.0
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
```

**Missing security hardening:**
```yaml
# Good — hardened service
services:
  api:
    image: my-app:1.0
    read_only: true
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped
```

**Inline secrets:**
```yaml
# Bad — credentials in compose file
services:
  db:
    environment:
      POSTGRES_PASSWORD: mysecretpassword

# Good — external env file
services:
  db:
    env_file:
      - .env
```
