# GPT-5.5 Security-Focused Code Review Report

Date: 2026-04-29  
Review type: Static repository review, OWASP-oriented vulnerability detection  
Scope: Frontend, user-service, game-catalog-service, order-service, Docker, Kubernetes, Helm, Terraform, and Azure Pipelines

## Executive Summary

The review found **14 security findings** across application code, service-to-service APIs, deployment configuration, CI security gates, and cloud infrastructure. The highest-risk issues are unauthenticated internal APIs, a seeded privileged default admin account, shared/default JWT secrets, and Kubernetes manifests containing usable secret material or placeholder credentials that can be applied as-is.

The codebase also has several positive controls: password hashes use BCrypt, many SQL paths use parameterized queries or ORM APIs, Helm/Kubernetes workloads include non-root and restricted security contexts, ACR admin access is disabled in Terraform, and CI includes Trivy image scanning.

## Metrics

| Metric | Value |
|---|---:|
| Total findings | 14 |
| Critical findings | 1 |
| High findings | 4 |
| Medium findings | 7 |
| Low findings | 2 |
| OWASP Top 10 categories represented | 5 |
| Services reviewed | 4 |
| Infra/CI surfaces reviewed | 6 |
| Dynamic exploit validation | Not performed |

### Findings By OWASP Category

| OWASP category | Count | Main themes |
|---|---:|---|
| A01: Broken Access Control | 2 | Unauthenticated internal service routes |
| A02: Cryptographic Failures | 2 | Shared/default JWT secrets, committed secret material |
| A05: Security Misconfiguration | 6 | Permissive CORS, missing headers, TLS/rate-limit gaps, AKS API exposure, image hardening |
| A06: Vulnerable and Outdated Components | 2 | Unpinned Python dependencies, non-blocking Trivy gate |
| A07: Identification and Authentication Failures | 4 | Default admin account, weak secret defaults, localStorage bearer tokens, no visible brute-force controls |

## Findings

### CRITICAL-01: Seeded Privileged Admin Uses a Weak Default Password

- **OWASP:** A07 Identification and Authentication Failures
- **Evidence:** `user-service/Program.cs` seeds `admin@psstore.com` with username `admin`, password `admin123`, and `IsAdmin = true` when the user table is empty.
- **Impact:** A newly deployed or reset environment can expose a predictable administrator login, enabling full administrative compromise.
- **Recommendation:** Remove production admin seeding. Use a one-time bootstrap workflow, a secret-backed initial password, or a protected admin invitation process. Add an environment guard that fails startup if default credentials are enabled outside local development.

### HIGH-01: User Service Internal Routes Are Anonymous

- **OWASP:** A01 Broken Access Control
- **Evidence:** `user-service/Controllers/InternalController.cs` applies `[AllowAnonymous]` at the controller level. `ValidateUser` returns `IsAdmin`, and `AddToLibrary` can add games to any user's library.
- **Impact:** Any actor that can reach the service can probe admin status or grant library items to arbitrary users.
- **Recommendation:** Require service-to-service authentication such as mTLS, workload identity, or a rotated internal API credential. Restrict network reachability with Kubernetes NetworkPolicies and test that anonymous calls are denied.

### HIGH-02: Order Service Internal User Statistics Are Unauthenticated

- **OWASP:** A01 Broken Access Control
- **Evidence:** `order-service/src/index.js` mounts `/internal/orders`; `order-service/src/routes/internal.js` exposes `/user/:userId/stats` without authentication.
- **Impact:** Order count and total spent can be queried for arbitrary users if the route is reachable.
- **Recommendation:** Add internal route authentication and source restrictions. Avoid returning cross-user financial or behavioral data without caller identity and authorization checks.

### HIGH-03: Shared Default JWT Secret Exists Across Services and Compose

- **OWASP:** A02 Cryptographic Failures, A07 Identification and Authentication Failures
- **Evidence:** `order-service/src/config.js`, `game-catalog-service/app/config.py`, and `docker-compose.yml` default to `ps-store-jwt-secret-key-change-in-production`.
- **Impact:** If defaults reach a shared or production-like environment, attackers can forge JWTs and impersonate users or admins across services.
- **Recommendation:** Remove usable JWT defaults from service code. Require explicit secrets at startup, source them from Azure Key Vault or Kubernetes Secrets managed outside Git, and rotate any value that has been used outside local development.

### HIGH-04: Kubernetes Manifests Include Plain Secret Material

- **OWASP:** A02 Cryptographic Failures, A05 Security Misconfiguration
- **Evidence:** `k8s/02-postgres.yaml` defines `postgres-credentials` using `stringData` with `POSTGRES_USER` and `POSTGRES_PASSWORD`. Similar service secret patterns exist in the application manifests.
- **Impact:** Values in Git can be reused accidentally and are visible to anyone with repository access. Applied manifests can create predictable credentials.
- **Recommendation:** Replace inline secrets with External Secrets Operator, Sealed Secrets, Azure Key Vault CSI driver, or deployment-time secret creation. Add policy checks to block committed Kubernetes `Secret.stringData` values.

### MEDIUM-01: Permissive CORS Across APIs

- **OWASP:** A05 Security Misconfiguration
- **Evidence:** `user-service/Program.cs` allows any origin, method, and header. `game-catalog-service/app/main.py` uses `allow_origins=["*"]` with credentials enabled. `order-service/src/index.js` calls `cors()` with defaults.
- **Impact:** Browser-based abuse becomes easier, especially if combined with token exposure or weak client-side controls.
- **Recommendation:** Configure allowed origins per environment. Avoid wildcard origins for credentialed flows and add regression tests for CORS policy.

### MEDIUM-02: Frontend Stores Bearer JWTs In localStorage

- **OWASP:** A07 Identification and Authentication Failures
- **Evidence:** `frontend/src/context/AuthContext.jsx` reads and writes `localStorage.getItem('token')` and `localStorage.setItem('token', ...)`.
- **Impact:** Any XSS or malicious dependency running in the page can steal the bearer token.
- **Recommendation:** Prefer httpOnly, Secure, SameSite cookies with CSRF protection, or shorten JWT lifetimes and add strong CSP and dependency hardening if bearer tokens remain in browser storage.

### MEDIUM-03: Client Trusts Decoded JWT Payload For Auth State

- **OWASP:** A07 Identification and Authentication Failures
- **Evidence:** `frontend/src/utils/token.js` base64-decodes the token payload without checking signature or expiry; `AuthContext` treats any decoded payload as authenticated client state.
- **Impact:** Server-side authorization may still protect APIs, but UI guards and admin UX can be spoofed locally.
- **Recommendation:** Treat client decoding as display-only, enforce expiry handling, and rely on server validation for protected data and actions.

### MEDIUM-04: Ingress TLS and Abuse Controls Are Not Enforced By Default

- **OWASP:** A05 Security Misconfiguration
- **Evidence:** `helm/ps-store/values.yaml` sets `ingress.tls.enabled: false` and only includes `proxy-body-size`; no rate-limit or WAF annotations are present.
- **Impact:** A default Helm deployment can expose credentials and tokens over HTTP and lacks basic edge throttling for brute-force or DoS pressure.
- **Recommendation:** Require TLS for non-local environments, add NGINX ingress rate limits or place Azure Front Door/Application Gateway WAF in front, and fail deployment when production values are missing.

### MEDIUM-05: Trivy Scan Does Not Fail Builds By Default

- **OWASP:** A06 Vulnerable and Outdated Components
- **Evidence:** `.azure-pipelines/templates/steps-trivy.yml` defaults `exitCode` to `0`, so HIGH/CRITICAL findings are reported but do not block builds unless overridden.
- **Impact:** Vulnerable images can continue through CI/CD even after scanner detection.
- **Recommendation:** Use `exitCode: '1'` for release-bearing branches or enforce a separate Azure DevOps quality gate for HIGH/CRITICAL vulnerabilities.

### MEDIUM-06: AKS API Server Exposure Is Not Constrained In Terraform

- **OWASP:** A05 Security Misconfiguration
- **Evidence:** `terraform/modules/aks/main.tf` defines the AKS cluster without an `api_server_access_profile`, private cluster setting, or authorized IP ranges.
- **Impact:** The Kubernetes management plane may be broadly reachable depending on Azure defaults and environment policy.
- **Recommendation:** Prefer a private AKS cluster or configure authorized IP ranges. Pair this with Azure RBAC and audited break-glass access.

### MEDIUM-07: Python Dependencies Are Mostly Unpinned

- **OWASP:** A06 Vulnerable and Outdated Components
- **Evidence:** `game-catalog-service/requirements.txt` leaves packages such as `fastapi`, `uvicorn[standard]`, `sqlalchemy`, `psycopg2-binary`, `httpx`, `pyjwt`, and `python-dotenv` unpinned.
- **Impact:** Builds are not reproducible and can pull unexpected vulnerable or breaking versions.
- **Recommendation:** Pin direct dependencies, generate a locked constraints file, and run dependency scanning in CI.

### LOW-01: Frontend Nginx Lacks Browser Security Headers

- **OWASP:** A05 Security Misconfiguration
- **Evidence:** `frontend/nginx.conf` only configures routing and static file fallback; it does not set CSP, HSTS, X-Frame-Options, X-Content-Type-Options, or Referrer-Policy.
- **Impact:** Missing headers reduce defense-in-depth against XSS, clickjacking, MIME sniffing, and downgrade risks.
- **Recommendation:** Add headers at the Nginx or ingress layer. Tune CSP for the generated Vite asset layout.

### LOW-02: Runtime Image Includes Extra Tooling For Health Check

- **OWASP:** A05 Security Misconfiguration
- **Evidence:** `user-service/Dockerfile` installs `curl` in the runtime image only for `HEALTHCHECK`.
- **Impact:** The production image has unnecessary packages and a larger attack surface.
- **Recommendation:** Use a runtime-native health check, a minimal static probe, or orchestrator health probes instead of installing extra tooling.

## Positive Security Observations

- `user-service` uses BCrypt for password hashing.
- Reviewed Node/PostgreSQL order queries use placeholders rather than string-concatenated SQL.
- Several Kubernetes and Helm workload definitions use non-root users, read-only filesystems, dropped capabilities, and restricted pod security settings.
- Terraform disables ACR admin credentials and marks kubeconfig output as sensitive.
- Azure Pipelines include image scanning and deployment jobs that target Azure DevOps environments.

## Recommended Next Actions

1. Fix `CRITICAL-01`, `HIGH-01`, `HIGH-02`, and `HIGH-03` before exposing the stack beyond local development.
2. Add automated tests that prove internal routes reject anonymous and cross-service unauthorized calls.
3. Add CI policy gates for secrets, dependency vulnerabilities, and container vulnerabilities.
4. Move all runtime secrets to Azure Key Vault, External Secrets Operator, Sealed Secrets, or another approved secret manager.
5. Add a production deployment guardrail that requires TLS, restricted CORS, and explicit non-default JWT configuration.

## Review Limitations

This was a static review of repository contents. It did not include live application testing, authenticated role testing, dependency CVE resolution, container image scanning output, Terraform plan validation, or cloud control-plane inspection.
