---
name: docker-container-config
description: Create, review, and maintain Docker and container configurations (Dockerfiles, docker-compose, .dockerignore) following project best practices. Use when the user asks to create Dockerfiles, review container configs, set up Docker Compose, add .dockerignore files, containerize services, or audit existing Docker configurations for best-practice compliance.
---

# Docker & Container Configuration

Create and review Docker/container configurations for this project. Always enforce the standards defined in `.cursor/rules/docker-best-practices.mdc`.

## Before You Start

1. Read `.cursor/rules/docker-best-practices.mdc` for the authoritative standards.
2. Read `.cursor/rules/kubernetes-best-practices.mdc` if Kubernetes manifests are in scope.
3. Identify the services and their tech stacks from `README.md`.

## Project Context

This is a microservices application with four components:

| Service | Stack | Port | Directory |
|---------|-------|------|-----------|
| Game Catalog | Python, FastAPI | 8001 | `game-catalog-service/` |
| User Service | .NET 8, EF Core | 8002 | `user-service/` |
| Order Service | Node.js, Express | 8003 | `order-service/` |
| Frontend | React 18, Vite | 3000 | `frontend/` |

Shared infrastructure: PostgreSQL (3 databases: `catalog_db`, `user_db`, `order_db`).

---

## Mode: Creating Configurations

### Workflow

Copy this checklist and track progress:

```
Creation Progress:
- [ ] Step 1: Identify target service(s) and tech stack
- [ ] Step 2: Create Dockerfile(s)
- [ ] Step 3: Create .dockerignore(s)
- [ ] Step 4: Create docker-compose.yml (if multi-service)
- [ ] Step 5: Self-review against checklist
```

### Step 1: Identify Target

Determine which services need containerization. Check `README.md` for the tech stack and ports.

### Step 2: Create Dockerfiles

Apply these rules for **every** Dockerfile:

1. Start with `# syntax=docker/dockerfile:1`
2. Use multi-stage builds (builder + runtime)
3. Pin base image versions — never `:latest`
4. Copy dependency manifests before source code (layer caching)
5. Run as non-root user
6. Include a `HEALTHCHECK`
7. Use `COPY` not `ADD`
8. Use `ENTRYPOINT` + `CMD` pattern

**Stack-specific guidance:**

**Python (FastAPI):**
- Builder: `python:3.12-slim` — install deps with `pip install --no-cache-dir`
- Runtime: `python:3.12-slim` — copy only app code and installed packages
- Use `--mount=type=cache,target=/root/.cache/pip` for build caching
- Entrypoint: `uvicorn`

**Node.js (Express / React+Vite):**
- Builder: `node:20-slim` — `npm ci` for deps
- Runtime (Express): `node:20-slim` or distroless — copy `dist/` + `node_modules/`
- Runtime (React): `nginx:1.27-alpine` — copy built static assets to `/usr/share/nginx/html`
- Use `--mount=type=cache,target=/root/.npm` for build caching

**.NET 8:**
- Builder: `mcr.microsoft.com/dotnet/sdk:8.0` — restore + publish
- Runtime: `mcr.microsoft.com/dotnet/aspnet:8.0` — copy published output
- Use `--mount=type=cache,target=/root/.nuget` for build caching

### Step 3: Create .dockerignore

Every service directory with a Dockerfile must have a `.dockerignore`:

```
.git
node_modules
dist
bin
obj
__pycache__
*.pyc
.env
.env.*
**/*.log
.vscode
.idea
*.md
```

Tailor to the specific tech stack (e.g., `bin/obj` for .NET, `__pycache__` for Python).

### Step 4: Create docker-compose.yml

When creating Compose files:

- Pin all image versions
- Set `restart: unless-stopped`
- Define resource limits under `deploy.resources`
- Include health checks for every service
- Use `env_file` for secrets — never inline credentials
- Use a shared network for inter-service communication
- Separate dev (`docker-compose.yml`) and prod (`docker-compose.prod.yml`) overrides
- Set `read_only: true` and `security_opt: [no-new-privileges:true]`
- Expose only necessary ports

### Step 5: Self-Review

After creating configs, run the review checklist below against your own output. Fix any violations before presenting to the user.

---

## Mode: Reviewing Configurations

### Workflow

```
Review Progress:
- [ ] Step 1: Inventory all Docker/container files
- [ ] Step 2: Review each Dockerfile
- [ ] Step 3: Review .dockerignore files
- [ ] Step 4: Review Compose files
- [ ] Step 5: Report findings
```

### Step 1: Inventory

Search the project for all Docker-related files:
- `**/Dockerfile*`
- `**/docker-compose*.yml`, `**/compose*.yml`
- `**/.dockerignore`

### Step 2: Review Dockerfiles

Check each Dockerfile against this checklist:

**Structure:**
- [ ] Starts with `# syntax=docker/dockerfile:1`
- [ ] Uses multi-stage build
- [ ] Base images are pinned to specific versions (no `:latest`)
- [ ] Dependency manifests copied before source code
- [ ] Related `RUN` commands combined with `&&`
- [ ] Package manager cache cleaned in the same layer

**Security:**
- [ ] Runs as non-root user (`USER` directive present)
- [ ] No secrets in `ENV` or `COPY` — uses BuildKit secret mounts
- [ ] No unnecessary packages installed
- [ ] Uses `COPY` not `ADD`

**Best Practice:**
- [ ] `HEALTHCHECK` defined
- [ ] Uses `ENTRYPOINT` + `CMD` pattern
- [ ] BuildKit cache mounts used for package managers
- [ ] `EXPOSE` matches the service port
- [ ] `WORKDIR` is set

### Step 3: Review .dockerignore

- [ ] `.dockerignore` exists alongside every Dockerfile
- [ ] Excludes: `.git`, `node_modules`, build outputs, `.env`, logs, IDE files
- [ ] Does not exclude files needed during build

### Step 4: Review Compose Files

- [ ] All image versions pinned (no `:latest`)
- [ ] `restart: unless-stopped` set
- [ ] Resource limits defined (`deploy.resources.limits`)
- [ ] Health checks defined for every service
- [ ] `read_only: true` set where possible
- [ ] `security_opt: [no-new-privileges:true]` set
- [ ] Secrets use `env_file` or Docker secrets, not inline
- [ ] Dev and prod overrides separated
- [ ] Only necessary ports exposed to host

### Step 5: Report Findings

Present findings using severity levels:

- **CRITICAL**: Security vulnerabilities or broken builds (must fix)
- **WARNING**: Best-practice violations (should fix)
- **INFO**: Suggestions for improvement (nice to have)

Format each finding as:

```
[SEVERITY] File: path/to/file, Line: N
Issue: Description of the problem
Fix: How to resolve it
```

---

## Additional Resources

- For the full review checklist with examples, see [review-checklist.md](review-checklist.md)
- For Dockerfile templates per tech stack, see [creation-templates.md](creation-templates.md)
