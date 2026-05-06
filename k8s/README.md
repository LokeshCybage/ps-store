# Kubernetes Manifests — PlayStation Store

Raw Kubernetes manifests deploying the full PlayStation Store stack:

| Layer    | Workload                          | Service Port      |
| -------- | --------------------------------- | ----------------- |
| Frontend | `frontend` (React/Nginx)          | `80`              |
| Backend  | `game-catalog` (Python/FastAPI)   | `8001`            |
| Backend  | `user-service` (.NET 8)           | `8002`            |
| Backend  | `order-service` (Node.js/Express) | `8003`            |
| Data     | `postgres` (StatefulSet)          | `5432` (headless) |

All resources live in the `ps-store` namespace, which enforces the Pod Security
Standards **`restricted`** profile.

## Layout

```
k8s/
├── 00-namespace.yaml                # Namespace + ResourceQuota + LimitRange
├── 01-default-network-policies.yaml # Default-deny + DNS allow
├── 02-postgres.yaml                 # SA, Secret, ConfigMap (init SQL), Service, StatefulSet, NetworkPolicy
├── 03-game-catalog.yaml             # SA, ConfigMap, Secret, Service, Deployment, PDB, HPA, NetworkPolicy
├── 04-user-service.yaml             # SA, ConfigMap, Secret, Service, Deployment, PDB, HPA, NetworkPolicy
├── 05-order-service.yaml            # SA, ConfigMap, Secret, Service, Deployment, PDB, HPA, NetworkPolicy
├── 06-frontend.yaml                 # SA, Service, Deployment, PDB, HPA, NetworkPolicy, Ingress
└── kustomization.yaml               # Aggregates everything; overrides image tags
```

## Apply

### With `kubectl`

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/
```

### With Kustomize

```bash
kubectl apply -k k8s/
```

### Validate before applying

```bash
# Schema and best-practice validation
kubeconform -strict -summary k8s/*.yaml

# Server-side dry-run
kubectl apply -k k8s/ --dry-run=server

# Security/reliability lint
kube-linter lint k8s/
```

## Build & push images

The deployments reference the image names below. Build and push them to a
registry the cluster can pull from (or load into kind/minikube), then update
the tags in `kustomization.yaml`:

```bash
docker build -t ps-store/game-catalog:1.0.0 game-catalog-service/
docker build -t ps-store/user-service:1.0.0 user-service/
docker build -t ps-store/order-service:1.0.0 order-service/
docker build -t ps-store/frontend:1.0.0 \
  --build-arg VITE_CATALOG_API=https://ps-store.local/api/catalog \
  --build-arg VITE_USER_API=https://ps-store.local/api/users \
  --build-arg VITE_ORDER_API=https://ps-store.local/api/orders \
  frontend/

# Local clusters: load images instead of pushing
# kind load docker-image ps-store/game-catalog:1.0.0
# minikube image load ps-store/game-catalog:1.0.0
```

## Secrets — replace before any real deployment

Every `Secret` in this directory ships a placeholder value
(`ChangeMe-Use-SealedSecrets-Or-ESO`, demo JWT key). Before you deploy to
anything beyond a throwaway local cluster:

1. Generate strong values:
   ```bash
   openssl rand -base64 32   # JWT_SECRET
   openssl rand -base64 24   # POSTGRES_PASSWORD
   ```
2. Rotate the values into a managed solution:
   - **Sealed Secrets** (`kubeseal`) — commit encrypted YAML alongside the
     manifests.
   - **External Secrets Operator** — sync from Vault, AWS Secrets Manager,
     Azure Key Vault, or GCP Secret Manager.
   - **SOPS + Helm/Kustomize plugin** — encrypt at rest in Git.
3. Make sure the Postgres password matches in `postgres-credentials` and in
   each backend's `DATABASE_URL` / `ConnectionStrings__DefaultConnection`.

## Ingress

`06-frontend.yaml` defines an `Ingress` for host `ps-store.local`, expecting
the **ingress-nginx** controller and a TLS certificate in
`ps-store/ps-store-tls` (use [cert-manager](https://cert-manager.io/) in real
clusters). Routes:

| Path            | Backend                  |
| --------------- | ------------------------ |
| `/api/catalog/` | `game-catalog:8001`      |
| `/api/users/`   | `user-service:8002`      |
| `/api/orders/`  | `order-service:8003`     |
| `/` (catch-all) | `frontend:80`            |

For local testing without DNS:

```bash
echo "127.0.0.1 ps-store.local" | sudo tee -a /etc/hosts
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8443:443
# https://ps-store.local:8443
```

> The frontend's API base URLs are baked in at **build time** by Vite. Rebuild
> the frontend image with the production `VITE_*_API` URLs before deploying.

## Security highlights

- **Namespace-level Pod Security Standards: `restricted`** (enforce, warn, audit).
- **`runAsNonRoot: true`**, no privilege escalation, all capabilities dropped.
  Frontend re-adds only `NET_BIND_SERVICE` to bind nginx on port 80.
- **`readOnlyRootFilesystem: true`** for every container, with `emptyDir`
  volumes for `/tmp`, nginx cache/run, and Postgres `/var/run/postgresql`.
- **Dedicated `ServiceAccount` per workload**, `automountServiceAccountToken: false`.
- **`seccompProfile: RuntimeDefault`** on every pod.
- **Default-deny `NetworkPolicy`** + explicit allow rules: each backend can
  reach Postgres + sibling backends only; frontend can be reached from the
  ingress controller only; Postgres only from backends.

## Reliability highlights

- `replicas: 2` minimum on every Deployment, `PodDisruptionBudget` with
  `minAvailable: 1`, `topologySpreadConstraints` to spread across nodes.
- `RollingUpdate` with `maxUnavailable: 0` for zero-downtime rollouts.
- `startupProbe` + `readinessProbe` + `livenessProbe` on every container.
- `HorizontalPodAutoscaler` (CPU + memory) on each app workload.
- `ResourceQuota` + `LimitRange` on the namespace.
- `PersistentVolumeClaim` (5Gi, RWO) for Postgres data.

## Validation

```bash
kubectl rollout status -n ps-store deploy/game-catalog
kubectl rollout status -n ps-store deploy/user-service
kubectl rollout status -n ps-store deploy/order-service
kubectl rollout status -n ps-store deploy/frontend
kubectl rollout status -n ps-store statefulset/postgres

kubectl get pods -n ps-store -w
kubectl top pods -n ps-store

# Smoke-test the API gateway
curl -k https://ps-store.local/api/catalog/health
curl -k https://ps-store.local/api/users/health
curl -k https://ps-store.local/api/orders/health
```

## Troubleshooting

```bash
kubectl describe pod -n ps-store <pod>
kubectl logs -n ps-store <pod> --previous
kubectl auth can-i --list -n ps-store --as=system:serviceaccount:ps-store:game-catalog
kubectl rollout undo -n ps-store deploy/<name>
```

## Related rules / skills

- `.cursor/rules/kubernetes-best-practices.mdc`
- `.cursor/skills/kubernetes-config/SKILL.md`
- `.cursor/skills/helm-chart-config/SKILL.md` — for migrating to a Helm chart
