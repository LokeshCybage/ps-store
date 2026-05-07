#!/usr/bin/env bash
# Sandbox startup script — deploys all services natively on the host.
# Suitable for environments where Docker cgroup v2 support is restricted.
#
# Prerequisites installed by this script if missing:
#   - Docker (for PostgreSQL container)
#   - .NET 8 SDK
#   - Python 3 + pip
#   - Node.js (expected to be pre-installed)
#
# Usage: bash scripts/sandbox-start.sh

set -euo pipefail
WORKSPACE="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="/tmp/ps-store-logs"
mkdir -p "$LOG_DIR"

green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
info()  { printf '\033[0;34m[INFO] %s\033[0m\n' "$*"; }
warn()  { printf '\033[0;33m[WARN] %s\033[0m\n' "$*"; }

info "Starting PlayStation Store sandbox environment"
info "Workspace: $WORKSPACE"
echo ""

# ── 1. Ensure Docker daemon is running ────────────────────────────────────────
info "Checking Docker daemon..."
if ! sudo docker info &>/dev/null; then
  warn "Docker daemon not running — starting it..."
  sudo mkdir -p /etc/docker
  echo '{"iptables": false, "storage-driver": "vfs", "default-cgroupns-mode": "host"}' \
    | sudo tee /etc/docker/daemon.json > /dev/null
  sudo dockerd --host=unix:///var/run/docker.sock 2>"$LOG_DIR/dockerd.log" &
  for i in {1..15}; do
    sleep 2
    if sudo docker info &>/dev/null; then
      green "Docker daemon started"
      break
    fi
  done
  sudo docker info &>/dev/null || { echo "Docker failed to start. Check $LOG_DIR/dockerd.log"; exit 1; }
fi
green "Docker daemon is running"

# ── 2. Start PostgreSQL ───────────────────────────────────────────────────────
info "Starting PostgreSQL..."
if sudo docker ps --format '{{.Names}}' | grep -q '^postgres$'; then
  green "PostgreSQL already running"
else
  sudo docker rm -f postgres 2>/dev/null || true
  sudo docker run -d --name postgres \
    --cgroupns=host \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -v "$WORKSPACE/docker/postgres-init:/docker-entrypoint-initdb.d:ro" \
    -p 5432:5432 \
    postgres:16.6-bookworm 2>&1

  info "Waiting for PostgreSQL to be ready..."
  for i in {1..30}; do
    sleep 2
    if sudo docker exec postgres pg_isready -U postgres &>/dev/null; then
      green "PostgreSQL is ready (databases: catalog_db, user_db, order_db)"
      break
    fi
    if [[ "$i" -eq 30 ]]; then
      echo "PostgreSQL failed to become ready"
      sudo docker logs postgres
      exit 1
    fi
  done
fi

# ── 3. Install dependencies ───────────────────────────────────────────────────
info "Installing/verifying Python dependencies (game-catalog-service)..."
pip3 install -q -r "$WORKSPACE/game-catalog-service/requirements.txt" 2>&1 | tail -3
export PATH="$PATH:/home/ubuntu/.local/bin"
green "Python dependencies ready"

info "Installing/verifying Node.js dependencies (order-service)..."
(cd "$WORKSPACE/order-service" && npm install --silent 2>&1 | tail -3)
green "Node.js dependencies ready"

info "Restoring .NET dependencies (user-service)..."
(cd "$WORKSPACE/user-service" && dotnet restore --nologo 2>&1 | tail -3)
green ".NET dependencies ready"

# ── 4. Start backend services ─────────────────────────────────────────────────
start_service() {
  local name="$1" session="$2" dir="$3" env_exports="$4" cmd="$5"
  if tmux -f /exec-daemon/tmux.portal.conf has-session -t "=$session" 2>/dev/null; then
    warn "tmux session '$session' already exists — skipping"
    return
  fi
  tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$session" -c "$dir" -- "${SHELL:-bash}" -l
  tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$session:0.0" \
    "$env_exports $cmd 2>&1 | tee $LOG_DIR/$name.log" C-m
  info "$name started in tmux session '$session' (log: $LOG_DIR/$name.log)"
}

info "Starting Game Catalog Service (Python/FastAPI) on :8001..."
start_service "game-catalog" "game-catalog" "$WORKSPACE/game-catalog-service" \
  'export PATH="$PATH:/home/ubuntu/.local/bin" DATABASE_URL="postgresql://postgres:postgres@localhost:5432/catalog_db" PORT=8001 JWT_SECRET="ps-store-jwt-secret-key-change-in-production" ORDER_SERVICE_URL="http://localhost:8003" USER_SERVICE_URL="http://localhost:8002"' \
  'python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8001'

info "Starting User Service (.NET 8) on :8002..."
start_service "user-service" "user-svc" "$WORKSPACE/user-service" \
  'export ASPNETCORE_URLS="http://0.0.0.0:8002" ConnectionStrings__DefaultConnection="Host=localhost;Port=5432;Database=user_db;Username=postgres;Password=postgres" Jwt__Secret="ps-store-jwt-secret-key-change-in-production" Jwt__Issuer="ps-store" ServiceUrls__CatalogService="http://localhost:8001" ServiceUrls__OrderService="http://localhost:8003"' \
  'dotnet run'

info "Starting Order Service (Node.js) on :8003..."
start_service "order-service" "order-svc" "$WORKSPACE/order-service" \
  'export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/order_db" PORT=8003 JWT_SECRET="ps-store-jwt-secret-key-change-in-production" CATALOG_SERVICE_URL="http://localhost:8001" USER_SERVICE_URL="http://localhost:8002"' \
  'npm start'

# ── 5. Wait for services to be healthy ────────────────────────────────────────
info "Waiting for all services to become healthy..."
declare -A HEALTH_URLS=(
  ["game-catalog"]="http://localhost:8001/health"
  ["user-service"]="http://localhost:8002/health"
  ["order-service"]="http://localhost:8003/health"
)

for svc in "game-catalog" "user-service" "order-service"; do
  url="${HEALTH_URLS[$svc]}"
  for i in {1..30}; do
    sleep 3
    if curl -sf "$url" &>/dev/null; then
      green "$svc is healthy ($url)"
      break
    fi
    if [[ "$i" -eq 30 ]]; then
      warn "$svc did not become healthy in time. Check $LOG_DIR/$svc.log"
    fi
  done
done

# ── 6. Summary ────────────────────────────────────────────────────────────────
echo ""
echo "================================================"
echo "  PlayStation Store sandbox is running!"
echo "================================================"
echo ""
echo "  Service        URL"
echo "  ─────────────────────────────────────────────"
echo "  Game Catalog   http://localhost:8001"
echo "  User Service   http://localhost:8002"
echo "  Order Service  http://localhost:8003"
echo ""
echo "  Default admin credentials: admin / admin123"
echo ""
echo "  Run E2E tests:"
echo "    bash tests/e2e_purchase_flow.sh"
echo ""
echo "  Logs:"
echo "    $LOG_DIR/"
echo ""
echo "  tmux sessions: game-catalog | user-svc | order-svc"
echo "    tmux -f /exec-daemon/tmux.portal.conf attach -t game-catalog"
echo "================================================"
