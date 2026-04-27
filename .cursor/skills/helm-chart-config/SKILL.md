---
name: helm-chart-config
description: Create, review, and maintain Helm charts (Chart.yaml, values, templates, _helpers.tpl, hooks, dependencies) for this project. Use when the user asks to scaffold a Helm chart, add a new component template, refactor values, package/lint/render charts, add environment overrides (values-prod/staging/dev), wire dependencies, or audit an existing chart for best-practice compliance.
---

# Helm Chart Configuration

Create and review Helm charts for this project. Always enforce the standards
defined in `.cursor/rules/helm-best-practices.mdc` and
`.cursor/rules/kubernetes-best-practices.mdc`.

Reference material:
- [Helm official best practices](https://helm.sh/docs/chart_best_practices/)
- [helm-chart-scaffolding skill (skills.sh)](https://skills.sh/wshobson/agents/helm-chart-scaffolding)

## Before You Start

1. Read `.cursor/rules/helm-best-practices.mdc` for authoritative standards.
2. Read `.cursor/rules/kubernetes-best-practices.mdc` for manifest-level rules.
3. Inspect the existing chart at `helm/ps-store/` to match its conventions.
4. Identify the target service(s) and tech stack from `README.md`.

## Project Context

The repo ships a single umbrella chart `helm/ps-store/` that packages the four
microservices plus Postgres:

| Component      | Stack             | Port | Template file                          |
|----------------|-------------------|------|----------------------------------------|
| Game Catalog   | Python / FastAPI  | 8001 | `templates/game-catalog-service.yaml`  |
| User Service   | .NET 8 / EF Core  | 8002 | `templates/user-service.yaml`          |
| Order Service  | Node.js / Express | 8003 | `templates/order-service.yaml`         |
| Frontend       | React / nginx     | 3000 | `templates/frontend.yaml`              |
| Postgres       | PostgreSQL        | 5432 | `templates/postgres.yaml`              |

Shared helpers live in `templates/_helpers.tpl` (`ps-store.labels`,
`ps-store.selectorLabels`, `ps-store.image`, `ps-store.pgUri`,
`ps-store.pgDotnet`). Reuse them — do not re-implement.

Environment overrides: `values.yaml` (defaults) and `values-prod.yaml`.

---

## Mode: Creating / Extending the Chart

### Workflow

```
Creation Progress:
- [ ] Step 1: Identify the component and its contract (ports, env, deps)
- [ ] Step 2: Add values block in values.yaml (documented, camelCase)
- [ ] Step 3: Create templates/<component>.yaml (Deployment + Service + ---)
- [ ] Step 4: Reuse helpers from _helpers.tpl (labels, image, pgUri)
- [ ] Step 5: Add environment overrides in values-<env>.yaml if needed
- [ ] Step 6: Render + lint (helm lint, helm template)
- [ ] Step 7: Self-review against checklist
```

### Step 1: Identify the Component

Determine ports, env vars, dependencies (DB/queue), resource footprint, and
probe endpoints. For DB-backed services, confirm which database name in
`values.postgres.databases` it owns.

### Step 2: Add Values

Add a top-level block in `values.yaml`, camelCase, fully documented:

```yaml
# Order service (Node.js/Express) — port 8003
orderService:
  enabled: true
  replicaCount: 2
  image:
    repository: ps-store/order-service
    tag: "1.0.0"                 # pin; bump on release
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 8003
  resources:
    requests: { cpu: "100m", memory: "128Mi" }
    limits:   { cpu: "500m", memory: "256Mi" }
  env: []                        # extra env vars appended verbatim
```

Add only deltas to `values-prod.yaml` (replica count, resource limits, image
tag, autoscaling).

### Step 3: Create the Template

One file per component. Group `Deployment` + `Service` (+ optional
`ConfigMap`/`HPA`) in the same file separated by `---`. Gate with
`{{- if .Values.<component>.enabled }}`.

Scaffold template:

```yaml
{{- if .Values.orderService.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  labels: {{- include "ps-store.labels" (dict "ctx" . "component" "order-service") | nindent 4 }}
spec:
  replicas: {{ .Values.orderService.replicaCount }}
  selector:
    matchLabels: {{- include "ps-store.selectorLabels" (dict "ctx" . "component" "order-service") | nindent 6 }}
  template:
    metadata:
      labels: {{- include "ps-store.selectorLabels" (dict "ctx" . "component" "order-service") | nindent 8 }}
    spec:
      {{- include "ps-store.imagePullSecrets" . | nindent 6 }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile: { type: RuntimeDefault }
      containers:
        - name: order-service
          image: {{ include "ps-store.image" (dict "img" .Values.orderService.image) | quote }}
          imagePullPolicy: {{ .Values.orderService.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.orderService.service.port }}
          env:
            - name: DATABASE_URL
              value: {{ include "ps-store.pgUri" (dict "ctx" . "db" "order_db") | quote }}
            {{- with .Values.orderService.env }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          readinessProbe:
            httpGet: { path: /ready, port: http }
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: http }
            periodSeconds: 10
          resources: {{- toYaml .Values.orderService.resources | nindent 12 }}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: { drop: ["ALL"] }
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  labels: {{- include "ps-store.labels" (dict "ctx" . "component" "order-service") | nindent 4 }}
spec:
  type: {{ .Values.orderService.service.type }}
  selector: {{- include "ps-store.selectorLabels" (dict "ctx" . "component" "order-service") | nindent 4 }}
  ports:
    - name: http
      port: {{ .Values.orderService.service.port }}
      targetPort: http
{{- end }}
```

### Step 4: Helpers

Reuse:
- `ps-store.labels` / `ps-store.selectorLabels` — all labeling
- `ps-store.image` — image reference
- `ps-store.pgUri` (libpq) or `ps-store.pgDotnet` — DB connection strings
- `ps-store.imagePullSecrets` — registry auth

Add a new helper in `_helpers.tpl` only when a pattern repeats in 2+ templates.

### Step 5: Dependencies (if adding external charts)

```yaml
# Chart.yaml
dependencies:
  - name: redis
    version: "19.0.0"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled
```

Then:

```bash
helm dependency update helm/ps-store
git add helm/ps-store/Chart.lock
# Do NOT commit helm/ps-store/charts/*.tgz
```

### Step 6: Render and Lint

```bash
helm lint helm/ps-store
helm template ps-store helm/ps-store --debug
helm template ps-store helm/ps-store -f helm/ps-store/values-prod.yaml --debug
helm install ps-store helm/ps-store --dry-run --debug -n ps-store --create-namespace
```

Fix every warning. Lint must pass cleanly.

### Step 7: Self-Review

Run the review checklist below against your own output before handing back.

---

## Mode: Reviewing the Chart

### Workflow

```
Review Progress:
- [ ] Step 1: Inventory chart files
- [ ] Step 2: Review Chart.yaml
- [ ] Step 3: Review values.yaml + overrides
- [ ] Step 4: Review each template + _helpers.tpl
- [ ] Step 5: Render and lint
- [ ] Step 6: Report findings by severity
```

### Step 2: Chart.yaml

- [ ] `apiVersion: v2`
- [ ] `version` (chart) uses SemVer and was bumped for the change
- [ ] `appVersion` is quoted and tracks the app release
- [ ] `kubeVersion`, `description`, `keywords`, `maintainers` present
- [ ] Dependencies pinned with exact `version`, `repository`, `condition`

### Step 3: values.yaml

- [ ] All keys camelCase
- [ ] Every value has an explanatory comment
- [ ] No secrets, tokens, or passwords
- [ ] Image tags pinned (no `latest`) and quoted
- [ ] Each component has `enabled`, `replicaCount`, `image`, `resources`
- [ ] Resource requests/limits set for every container
- [ ] `values-prod.yaml` overrides only deltas, not the full tree

### Step 4: Templates

- [ ] One file per component; related resources grouped with `---`
- [ ] Optional resources gated on `.Values.<component>.enabled`
- [ ] Labels applied via `ps-store.labels` helper
- [ ] Selectors use `ps-store.selectorLabels` (no `version` / `chart` labels)
- [ ] `{{ include … | nindent N }}` — never `indent`
- [ ] `toYaml` used for `resources`, `nodeSelector`, `tolerations`, `affinity`
- [ ] Image refs go through `ps-store.image`
- [ ] No hardcoded namespace
- [ ] Probes (`startupProbe`/`readinessProbe`/`livenessProbe`) present
- [ ] Pod + container `securityContext` set (non-root, drop ALL caps, RO rootfs)
- [ ] `required` used for mandatory values that would otherwise silently break

### Step 5: Render and Lint

```bash
helm lint helm/ps-store
helm template ps-store helm/ps-store --debug > /tmp/rendered-default.yaml
helm template ps-store helm/ps-store -f helm/ps-store/values-prod.yaml --debug > /tmp/rendered-prod.yaml
```

Inspect both renders. Optionally validate with `kubeconform`:

```bash
kubeconform -strict -summary /tmp/rendered-prod.yaml
```

### Step 6: Report Findings

Use severity levels:

- **CRITICAL** — breaks rendering, install, or security (must fix)
- **WARNING** — best-practice violation (should fix)
- **INFO** — stylistic / optional improvement

Format:

```
[SEVERITY] File: helm/ps-store/templates/foo.yaml, Line: N
Issue: …
Fix:   …
```

---

## Anti-Patterns (reject on sight)

- `image: myapp:latest` — always pin
- `namespace: ps-store` hardcoded in a template
- Hand-written label blocks instead of `ps-store.labels`
- `indent` in place of `nindent`
- Plaintext passwords in `values.yaml`
- Committed `charts/*.tgz` files (only `Chart.lock` is committed)
- `lookup` used for logic that should be values-driven (breaks `--dry-run`)
- Bumping `appVersion` without bumping chart `version` (or vice versa when templates changed)
