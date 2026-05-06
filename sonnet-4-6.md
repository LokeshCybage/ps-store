# Security Code Review Report — PlayStation Store
**Model:** sonnet-4-6
**Date:** 2026-04-29
**Scope:** OWASP Top 10 (2021)
**Reviewer:** Automated Security Code Review

---

## Executive Summary

The PlayStation Store application demonstrates a good security baseline in its infrastructure layer — container pods run as non-root, Kubernetes NetworkPolicies enforce default-deny, and BCrypt is used for password hashing. However, the application carries **four critical vulnerabilities** that could lead to full authentication bypass, unauthorized data access, and complete system compromise: a hardcoded admin password, a well-known default JWT secret committed to version-controlled Kubernetes manifests, and entirely unauthenticated internal service endpoints. These critical issues must be remediated before any production deployment.

---

## Risk Score Summary

| OWASP Category | Risk Level | Findings Count |
|---|---|---|
| A01 — Broken Access Control | **CRITICAL** | 4 |
| A02 — Cryptographic Failures | **HIGH** | 5 |
| A03 — Injection | **MEDIUM** | 3 |
| A04 — Insecure Design | **HIGH** | 5 |
| A05 — Security Misconfiguration | **HIGH** | 5 |
| A06 — Vulnerable & Outdated Components | **MEDIUM** | 3 |
| A07 — Identification & Authentication Failures | **HIGH** | 5 |
| A08 — Software & Data Integrity Failures | **MEDIUM** | 3 |
| A09 — Security Logging & Monitoring Failures | **MEDIUM** | 4 |
| A10 — Server-Side Request Forgery | **LOW** | 2 |

## Overall Risk Score: **8.2 / 10** *(Critical)*

---

## Findings by OWASP Category

---

### A01 — Broken Access Control

#### [CRITICAL] Order Service Internal Endpoints Completely Unauthenticated

- **File:** `order-service/src/routes/internal.js:1-40`
- **Description:** The `/internal/orders/*` routes — which expose game purchase statistics, popular game IDs, and per-user spending data — are mounted with **zero authentication middleware**. Any party that can reach the order-service port (other pods, or an attacker who achieves lateral movement) can query purchase counts and user financial stats without a token.
- **Evidence:**
  ```javascript
  // order-service/src/index.js:23
  app.use('/internal/orders', internalRoutes);
  
  // order-service/src/routes/internal.js — no auth middleware applied
  router.get('/games/:gameId/stats', async (req, res) => { ... });
  router.get('/popular', async (req, res) => { ... });
  router.get('/user/:userId/stats', async (req, res) => { ... });
  ```
- **Remediation:** Apply a network-identity check (e.g., a shared internal API key injected as a secret, mutual TLS, or a `X-Internal-Token` header validated against a secret) to all `/internal/*` routes. At minimum, assert the `X-Forwarded-For` or `X-Real-IP` is a known cluster CIDR. Consider a dedicated `authInternal` middleware that verifies a service-level bearer token.

---

#### [CRITICAL] User Service Internal Controller Decorated `[AllowAnonymous]`

- **File:** `user-service/Controllers/InternalController.cs:12`
- **Description:** The `InternalController` — which exposes admin-status validation and library-write operations — explicitly opts out of authentication with `[AllowAnonymous]`. An attacker who can reach port 8002 (or bypasses NetworkPolicies) can: (a) enumerate whether any user UUID is an admin, and (b) write arbitrary games to any user's library.
- **Evidence:**
  ```csharp
  [ApiController]
  [Route("internal")]
  [AllowAnonymous]   // ← NO authentication on admin-privilege endpoint
  public class InternalController : ControllerBase
  {
      [HttpGet("users/{userId:guid}/validate")]   // returns IsAdmin
      [HttpPost("users/{userId:guid}/library")]   // writes to user library
  ```
- **Remediation:** Remove `[AllowAnonymous]`. Implement an internal service authentication scheme (e.g., a pre-shared secret header `X-Internal-Api-Key` validated against a Kubernetes Secret) and apply a policy-based authorization attribute that validates it.

---

#### [HIGH] CORS Wildcard Combined with `allow_credentials=True`

- **File:** `game-catalog-service/app/main.py:32-38`
- **Description:** The CORS middleware is configured with `allow_origins=["*"]` and `allow_credentials=True` simultaneously. The CORS specification forbids this combination for credentialed requests — modern browsers will reject such responses. More critically, this reveals the *intent* to allow credentialed cross-origin access from any origin, which would be a critical broken-access-control issue if browsers were to honor it.
- **Evidence:**
  ```python
  app.add_middleware(
      CORSMiddleware,
      allow_origins=["*"],       # wildcard
      allow_credentials=True,    # credentials — invalid combination
      allow_methods=["*"],
      allow_headers=["*"],
  )
  ```
- **Remediation:** Replace `allow_origins=["*"]` with an explicit allowlist of trusted frontend origins (e.g., `["https://ps-store.example.com"]`). Apply the same fix to `user-service/Program.cs` and `order-service/src/index.js` where `cors()` is called with no configuration (wildcard by default).

---

#### [HIGH] Unauthenticated `/internal` Routes Accept Requests from `ingress-nginx` Namespace

- **File:** `k8s/04-user-service.yaml:236-245`, `k8s/03-game-catalog.yaml:233-244`
- **Description:** The Kubernetes NetworkPolicies for user-service and game-catalog allow ingress from the `ingress-nginx` namespace to ports 8002 and 8001 respectively. Because the ingress controller sits in the `ingress-nginx` namespace, any path that the ingress routes to these services — including the `/internal/*` paths — is reachable from the public internet via the Nginx ingress.
- **Evidence:**
  ```yaml
  # k8s/04-user-service.yaml:236-244
  ingress:
    - from:
        - podSelector: { matchExpressions: [...] }
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx   # ingress-nginx can reach internal APIs
      ports:
        - protocol: TCP
          port: 8002
  ```
- **Remediation:** Add an Nginx ingress rule to explicitly deny paths matching `/internal/*` at the ingress layer, e.g.:
  ```yaml
  nginx.ingress.kubernetes.io/server-snippet: |
    location ~ ^/internal/ { return 403; }
  ```
  Combine with the service-level authentication fix above.

---

### A02 — Cryptographic Failures

#### [CRITICAL] Known Default JWT Secret Committed to Version-Controlled Kubernetes Manifests

- **File:** `k8s/03-game-catalog.yaml:42`, `k8s/04-user-service.yaml:45`, `k8s/05-order-service.yaml:43`, `game-catalog-service/app/config.py:9`, `order-service/src/config.js:6`
- **Description:** The same hardcoded JWT secret `"ps-store-jwt-secret-key-change-in-production"` appears: (1) as a fallback default in application config code, and (2) in plaintext inside Kubernetes `Secret` manifests that are tracked by Git. An attacker who reads the repository — or the running k8s Secret — can forge arbitrary JWT tokens, grant themselves admin status, and impersonate any user.
- **Evidence:**
  ```python
  # game-catalog-service/app/config.py:9
  JWT_SECRET = os.getenv("JWT_SECRET", "ps-store-jwt-secret-key-change-in-production")
  ```
  ```yaml
  # k8s/04-user-service.yaml:45
  stringData:
    Jwt__Secret: "ps-store-jwt-secret-key-change-in-production"
  ```
- **Remediation:** (1) Remove all fallback defaults for JWT_SECRET — fail fast with a startup error if the env var is unset. (2) Remove the `stringData` from all k8s Secret manifests in version control; replace with references to sealed-secrets/ESO placeholders (the manifests already contain this advisory annotation — act on it). (3) Rotate the JWT secret immediately in any deployed environment.

---

#### [HIGH] JWT Stored in `localStorage` — Vulnerable to XSS Token Theft

- **File:** `frontend/src/context/AuthContext.jsx:29`
- **Description:** The JWT is persisted to `localStorage`, which is accessible to any JavaScript running on the page (including injected via XSS). A single stored-XSS exploit is sufficient to silently exfiltrate the token and allow persistent session hijacking.
- **Evidence:**
  ```javascript
  // AuthContext.jsx:29
  localStorage.setItem('token', newToken);
  ```
- **Remediation:** Store the JWT in an `HttpOnly; Secure; SameSite=Strict` cookie set by the server. The frontend never needs direct access to the raw token bytes; it can be included automatically on same-origin requests. If a cookie-based approach is not feasible short-term, consider `sessionStorage` (cleared on tab close) over `localStorage` as a partial mitigation.

---

#### [HIGH] JWT Audience Validation Disabled

- **File:** `user-service/Program.cs:41`
- **Description:** `ValidateAudience = false` means a token issued for any audience — or by any service using the same shared secret — is accepted by the user service. Because all three services share the same JWT secret, a token minted in one service context is equally valid in all others.
- **Evidence:**
  ```csharp
  options.TokenValidationParameters = new TokenValidationParameters
  {
      ValidateIssuer = true,
      ValidateAudience = false,   // ← audience not enforced
      ValidateLifetime = true,
      IssuerSigningKey = key,
  };
  ```
- **Remediation:** Set `ValidateAudience = true` and `ValidAudience = "ps-store-api"` (or per-service audiences). Update `TokenService.cs` to set the `audience` claim when minting tokens.

---

#### [MEDIUM] Token Expiry Not Validated Client-Side

- **File:** `frontend/src/utils/token.js:1-8`
- **Description:** `decodeToken` base64-decodes the JWT payload but never checks the `exp` claim. On page load, an expired token stored in localStorage is loaded and set as the active authentication state. The user appears logged in until the next server request fails with 401.
- **Evidence:**
  ```javascript
  export function decodeToken(token) {
    try {
      const payload = token.split(".")[1];
      return JSON.parse(atob(payload));  // no exp check
    } catch {
      return null;
    }
  }
  ```
- **Remediation:** Add expiry validation:
  ```javascript
  export function decodeToken(token) {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      if (payload.exp && Date.now() / 1000 > payload.exp) return null;
      return payload;
    } catch {
      return null;
    }
  }
  ```

---

#### [LOW] TLS Disabled by Default in Helm Values

- **File:** `helm/ps-store/values.yaml:36`
- **Description:** The base `values.yaml` ships with `tls.enabled: false`. Any deployment that uses this file without also specifying `values-prod.yaml` (or an equivalent override) will serve traffic over plain HTTP, exposing JWTs and session data in transit.
- **Evidence:**
  ```yaml
  ingress:
    tls:
      enabled: false   # ← default is cleartext HTTP
  ```
- **Remediation:** Flip the default to `enabled: true` in the base `values.yaml` and require a valid `secretName`. If self-signed certs are needed for dev/local environments, document the cert-manager or `mkcert` setup explicitly.

---

### A03 — Injection

#### [MEDIUM] Stored XSS via Unsanitized Review Text and Username

- **File:** `game-catalog-service/app/routes/games.py:200-233`
- **Description:** The `create_review` endpoint takes `review_text` from the request body and `username` directly from the JWT payload, storing both in the database without sanitization. When these values are later served as JSON and rendered in the React frontend, an attacker who crafts a review containing `<script>` tags or an HTML injection payload could execute JavaScript in other users' browsers — a stored XSS.
- **Evidence:**
  ```python
  # games.py:201-202
  payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
  username = payload.get("username", "Anonymous")  # taken from user-controlled token
  
  # games.py:227-233
  review = Review(
      ...
      username=username,            # unsanitized JWT claim
      rating=review_data.rating,
      review_text=review_data.review_text,  # unsanitized user input
  )
  ```
- **Remediation:** (1) Apply server-side output encoding when these strings are returned (FastAPI/Pydantic does not automatically HTML-escape JSON). (2) In the React frontend, always render user-supplied text via React's default text rendering (never `dangerouslySetInnerHTML`). (3) Add a Content-Security-Policy header (see A05). (4) Consider a library like `bleach` to strip HTML from review text before persistence.

---

#### [MEDIUM] AvatarUrl Stored Without URL Validation

- **File:** `user-service/Controllers/UsersController.cs:75-76`
- **Description:** The `AvatarUrl` field accepts arbitrary strings without validation. This allows `javascript:` protocol URLs, data URIs, or other dangerous values. If the frontend renders this as an `<img src>` or `<a href>`, it can trigger XSS or open-redirect attacks.
- **Evidence:**
  ```csharp
  if (request.AvatarUrl != null)
      user.AvatarUrl = request.AvatarUrl;  // no URL format validation
  ```
- **Remediation:** Validate that `AvatarUrl`, when present, is a well-formed `https://` URL pointing to an allowed domain (allowlist approach). Reject `javascript:`, `data:`, and relative URLs.

---

#### [LOW] Search/Filter Parameters Use SQLAlchemy ORM (Mitigated, but Needs Acknowledgment)

- **File:** `game-catalog-service/app/routes/games.py:141-149`
- **Description:** The `search`, `category`, and `platform` query parameters are passed into `ilike(f"%{search}%")` via SQLAlchemy's ORM layer. SQLAlchemy parameterizes these values correctly, preventing SQL injection. However, wildcard-prefix LIKE queries (`%search%`) on unindexed columns cause full table scans and can be exploited for denial-of-service via slow-query flooding.
- **Evidence:**
  ```python
  if search:
      query = query.filter(
          Game.title.ilike(f"%{search}%") | Game.description.ilike(f"%{search}%")
      )
  ```
- **Remediation:** Add database indexes on `Game.title` and `Game.description` (or migrate to full-text search). Add rate limiting on the `/api/games` endpoint.

---

### A04 — Insecure Design

#### [CRITICAL] Default Admin Account Seeded with Known Weak Password

- **File:** `user-service/Program.cs:87-95`
- **Description:** On first startup, if the Users table is empty, an admin account is seeded with username `"admin"` and password `"admin123"`. This is among the most commonly guessed credential pairs. Any attacker who can reach the login endpoint with these credentials immediately obtains full admin access including game creation, modification, and deletion.
- **Evidence:**
  ```csharp
  context.Users.Add(new UserService.Models.User
  {
      Username = "admin",
      Email = "admin@psstore.com",
      PasswordHash = BCrypt.Net.BCrypt.HashPassword("admin123"),  // ← trivial password
      IsAdmin = true
  });
  ```
- **Remediation:** (1) Remove the hardcoded seed entirely. (2) Provision the admin account via a one-time setup script that reads credentials from a Kubernetes Secret. (3) At minimum, generate a random password and log it only once at startup, forcing immediate rotation.

---

#### [HIGH] No Rate Limiting on Authentication Endpoints

- **File:** `user-service/Controllers/AuthController.cs:23-73`, `order-service/src/middleware/auth.js`
- **Description:** The `/api/auth/login` and `/api/auth/register` endpoints have no throttling, account lockout, or CAPTCHA. This enables unconstrained credential stuffing, brute-force attacks, and bulk account registration. A standard 10-threads-per-second attack can test millions of password combinations per day.
- **Evidence:**
  ```csharp
  [HttpPost("login")]
  public async Task<IActionResult> Login([FromBody] LoginRequest request)
  {
      // No rate limiting, no lockout, no CAPTCHA
      var user = await _context.Users.FirstOrDefaultAsync(u => u.Username == request.Username);
      if (user == null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
          return Unauthorized(...);
  ```
- **Remediation:** Apply IP-based rate limiting via ASP.NET Core's `AspNetCoreRateLimit` package or an API gateway. Implement account lockout after N failed attempts (e.g., 5 within 10 minutes). Consider adding CAPTCHA for the login UI.

---

#### [HIGH] No CSRF Protection

- **File:** All backend services
- **Description:** None of the services implement CSRF tokens. State-changing endpoints (checkout, cart modification, profile update) use only JWT bearer tokens for authentication. With the current wildcard CORS configuration, a malicious site could make credentialed cross-origin requests if the victim visits it while logged in (particularly relevant if the JWT is moved to cookies).
- **Remediation:** If migrating to HttpOnly cookie-based auth (recommended), implement the Synchronizer Token Pattern or use the `SameSite=Strict` cookie attribute (which alone provides substantial CSRF protection for same-origin frontends).

---

#### [MEDIUM] JWT Token Revocation Not Implemented

- **File:** All services
- **Description:** There is no token blacklist or revocation mechanism. Once a JWT is issued, it remains valid until its `exp` time (default 24 hours per `TokenService.cs:22`). Compromised tokens, logged-out users' tokens, and tokens belonging to deleted accounts all remain valid for the full duration.
- **Remediation:** Implement a Redis-backed token blacklist for logout and account deletion events. Alternatively, reduce token lifetime to 15 minutes and implement a refresh-token rotation pattern.

---

#### [LOW] No Password Complexity Requirements

- **File:** `user-service/DTOs/AuthDTOs.cs` (implied), `user-service/Controllers/AuthController.cs`
- **Description:** Password validation on registration is limited to whatever model validation annotations are on `RegisterRequest`. There are no apparent minimum-length, character-class, or common-password requirements enforced server-side.
- **Remediation:** Add validation attributes enforcing minimum 12 characters and a mix of character classes, or integrate a "have I been pwned" API check on registration.

---

### A05 — Security Misconfiguration

#### [HIGH] nginx Missing All HTTP Security Headers

- **File:** `frontend/nginx.conf:1-14`
- **Description:** The nginx configuration serves the React SPA with no security-relevant HTTP headers. Missing headers include: `Content-Security-Policy`, `X-Frame-Options`, `X-Content-Type-Options`, `Strict-Transport-Security`, `Referrer-Policy`, and `Permissions-Policy`. This leaves the application exposed to clickjacking, MIME-sniffing attacks, and eliminates defense-in-depth against XSS.
- **Evidence:**
  ```nginx
  server {
      listen 8080;
      root /usr/share/nginx/html;
      index index.html;
      # No security headers defined anywhere in this file
      location /assets/ { try_files $uri =404; }
      location / { try_files $uri $uri/ /index.html; }
  }
  ```
- **Remediation:** Add a `add_header` block:
  ```nginx
  add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://ps-store.example.com;" always;
  add_header X-Frame-Options "DENY" always;
  add_header X-Content-Type-Options "nosniff" always;
  add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
  add_header Referrer-Policy "strict-origin-when-cross-origin" always;
  ```

---

#### [HIGH] Kubernetes Secrets in Plaintext in Version-Controlled Manifests

- **File:** `k8s/02-postgres.yaml:25-26`, `k8s/03-game-catalog.yaml:40-42`, `k8s/04-user-service.yaml:43-45`, `k8s/05-order-service.yaml:41-43`
- **Description:** All Kubernetes `Secret` resources use `stringData` with real credential values (or known placeholder values) directly in the YAML files. Even "placeholder" values like `"ChangeMe-Use-SealedSecrets-Or-ESO"` can be deployed as-is if operators follow the manifests literally. Git history will permanently retain any previously committed real secrets.
- **Evidence:**
  ```yaml
  # k8s/03-game-catalog.yaml:40-42
  stringData:
    DATABASE_URL: "postgresql://postgres:ChangeMe-Use-SealedSecrets-Or-ESO@postgres:5432/catalog_db"
    JWT_SECRET: "ps-store-jwt-secret-key-change-in-production"
  ```
- **Remediation:** Replace all `stringData` Secret blocks with External Secrets Operator (ESO) `ExternalSecret` resources that reference Azure Key Vault. Alternatively, use `kubeseal` to create SealedSecrets. Add a `git-secrets` pre-commit hook to prevent future accidental credential commits.

---

#### [MEDIUM] FastAPI Interactive API Documentation Exposed in Production

- **File:** `game-catalog-service/app/main.py:25-30`
- **Description:** FastAPI is initialized without disabling the auto-generated interactive documentation. In production, the `/docs` (Swagger UI) and `/redoc` endpoints expose the complete API schema, endpoint list, request/response shapes, and allow unauthenticated exploration of all APIs.
- **Evidence:**
  ```python
  app = FastAPI(
      title="Game Catalog Service",
      description="PlayStation Store-inspired game catalog microservice",
      version="1.0.0",
      # No: docs_url=None, redoc_url=None, openapi_url=None
  )
  ```
- **Remediation:** Disable docs in production:
  ```python
  import os
  is_production = os.getenv("ENVIRONMENT", "dev") == "production"
  app = FastAPI(
      docs_url=None if is_production else "/docs",
      redoc_url=None if is_production else "/redoc",
      openapi_url=None if is_production else "/openapi.json",
  )
  ```

---

#### [MEDIUM] Wildcard CORS on Order Service and User Service

- **File:** `order-service/src/index.js:14`, `user-service/Program.cs:53-58`
- **Description:** Both services enable CORS with no origin restrictions — `app.use(cors())` in Express defaults to allowing all origins, and the C# policy explicitly calls `.AllowAnyOrigin()`. This allows any website to make credentialed cross-origin requests to these APIs.
- **Evidence:**
  ```javascript
  // order-service/src/index.js:14
  app.use(cors());  // allows *, no restriction
  ```
  ```csharp
  // user-service/Program.cs:54-57
  policy.AllowAnyOrigin()
        .AllowAnyMethod()
        .AllowAnyHeader();
  ```
- **Remediation:** Replace with explicit origin allowlists reflecting actual frontend domains.

---

#### [LOW] `NET_BIND_SERVICE` Capability Added to Frontend Container

- **File:** `k8s/06-frontend.yaml:123`
- **Description:** The frontend container adds `NET_BIND_SERVICE` to allow binding to port 80. Since the actual container listens on 8080 (per `nginx.conf`) and is served by Nginx which does not need privileged port binding as a non-root user, this capability is likely unnecessary.
- **Evidence:**
  ```yaml
  capabilities:
    drop: ["ALL"]
    add: ["NET_BIND_SERVICE"]   # nginx listens on 8080, not 80
  ```
- **Remediation:** Verify whether `NET_BIND_SERVICE` is actually required; remove it if not. The `containerPort: 80` in the k8s spec vs the `listen 8080` in nginx.conf is a mismatch that should be reconciled.

---

### A06 — Vulnerable and Outdated Components

#### [HIGH] Python Dependencies Entirely Unpinned

- **File:** `game-catalog-service/requirements.txt:1-9`
- **Description:** Eight of the eleven dependencies have no version pin. Any fresh `pip install -r requirements.txt` (such as in a CI rebuild or new environment) will pull the latest available version of `fastapi`, `sqlalchemy`, `psycopg2-binary`, `pyjwt`, and others — including any versions with newly disclosed CVEs. This makes the dependency supply chain non-deterministic and non-auditable.
- **Evidence:**
  ```
  fastapi          # no pin
  uvicorn[standard] # no pin
  sqlalchemy       # no pin
  psycopg2-binary  # no pin
  httpx            # no pin
  pyjwt            # no pin
  python-dotenv    # no pin
  pytest           # no pin
  pytest-asyncio   # no pin
  ```
- **Remediation:** Pin all dependencies to exact versions (`fastapi==0.115.x`), generate a `requirements-lock.txt` via `pip-compile`, and enforce `pip install --require-hashes`. Add `pip-audit` to the CI pipeline to detect known CVEs automatically.

---

#### [MEDIUM] Node.js Dependencies Use Caret Ranges (`^`)

- **File:** `order-service/package.json:14-28`
- **Description:** All production dependencies specify `^` ranges (e.g., `"express": "^4.21.0"`). While `package-lock.json` pins exact installed versions, running `npm update` or deleting the lockfile will potentially install vulnerable minor/patch versions. CI pipelines that run `npm install` without the lockfile would exhibit non-deterministic behavior.
- **Remediation:** Use `npm ci` exclusively in CI (already done per the Dockerfile). Consider periodic `npm audit` runs and enable Dependabot or Renovate for automated dependency PRs. Pin particularly sensitive packages (`jsonwebtoken`, `express`) to exact versions.

---

#### [MEDIUM] No Software Composition Analysis (SCA) in CI Pipelines

- **File:** `azure-pipelines-ci-game-catalog.yml`, `azure-pipelines-ci-order-service.yml`, `azure-pipelines-ci-frontend.yml`
- **Description:** The CI pipeline files do not include any dependency vulnerability scanning step (e.g., `pip-audit`, `npm audit --audit-level=high`, Snyk, or OWASP Dependency-Check). Known CVEs in transitive dependencies will never be automatically surfaced.
- **Remediation:** Add SCA steps to each CI pipeline. For Python: `pip-audit -r requirements.txt --fail-on-vuln`. For Node.js: `npm audit --audit-level=high`. Integrate with Azure Defender for Containers for registry-level scanning.

---

### A07 — Identification and Authentication Failures

#### [CRITICAL] Default Admin Credentials `admin/admin123` (Cross-Listed from A04)

Covered in full under A04. The trivially guessable default admin account represents both an insecure design and an authentication failure.

---

#### [HIGH] No Account Lockout After Failed Login Attempts

- **File:** `user-service/Controllers/AuthController.cs:54-73`
- **Description:** The login endpoint performs no failed-attempt tracking. An attacker can make unlimited sequential or parallel requests to test passwords for any known username. Combined with the weak default admin password, this enables trivial account compromise.
- **Remediation:** Track failed attempt counts per username and per source IP (e.g., in a distributed cache / Redis). Lock accounts for 15 minutes after 5 consecutive failures. Log failed attempts with source IP for alerting.

---

#### [HIGH] `isAuthenticated` State Based Solely on Client-Side Token Presence

- **File:** `frontend/src/context/AuthContext.jsx:50`
- **Description:** The authenticated flag is derived purely from `!!token` after a client-side decode. There is no server-side session validation on page load. A manually crafted token (even with an invalid signature) that successfully passes the trivial `decodeToken` function will set `isAuthenticated = true`, unlocking the UI even before any server call is made.
- **Evidence:**
  ```javascript
  const isAuthenticated = !!token;   // no signature or server validation
  ```
- **Remediation:** For the loading state, perform a `/api/users/me` verification call on initialization to confirm the token is valid server-side. Guard `isAuthenticated` on the server response, not just token existence.

---

#### [MEDIUM] JWT `is_admin` Claim Controlled by Token and Never Re-Verified for Privilege Changes

- **File:** `user-service/Services/TokenService.cs:32`
- **Description:** The admin status is baked into the JWT at login time. If a user's admin status is revoked in the database, their existing token continues to grant admin privileges for the remainder of its 24-hour lifetime. The game-catalog service relies on `validate_admin()` (which does a live user-service call) for write operations, but other clients that read the `is_admin` claim from the token directly would be unaffected by a revocation.
- **Evidence:**
  ```csharp
  new Claim("is_admin", user.IsAdmin.ToString().ToLower())
  ```
- **Remediation:** For admin privilege changes, implement token revocation (see A04). For the game-catalog service specifically, the current `validate_admin()` live-check pattern is correct and should be consistently applied wherever admin status is consumed.

---

#### [LOW] No Multi-Factor Authentication

- **File:** All authentication flows
- **Description:** The application has no MFA/2FA capability. For a store handling financial transactions, MFA is a standard security requirement.
- **Remediation:** Implement TOTP-based MFA (e.g., Google Authenticator compatible) for admin accounts as a minimum. Consider offering MFA to all users who have purchase history.

---

### A08 — Software and Data Integrity Failures

#### [HIGH] Container Images Not Pinned by Digest

- **File:** `k8s/03-game-catalog.yaml:117`, `k8s/04-user-service.yaml:120`, `k8s/05-order-service.yaml:118`, `k8s/06-frontend.yaml:85`
- **Description:** All Kubernetes deployment manifests reference container images by mutable semver tags (`ps-store/game-catalog:1.0.0`). If the container registry is compromised or a tag is overwritten, the next pod restart will silently pull a malicious image. Tag immutability is not enforced.
- **Evidence:**
  ```yaml
  # k8s/03-game-catalog.yaml:117
  image: ps-store/game-catalog:1.0.0   # mutable tag, no digest
  ```
- **Remediation:** Pin images to their SHA256 digest:
  ```yaml
  image: psstore.azurecr.io/game-catalog:1.0.0@sha256:<digest>
  ```
  Enable Azure Container Registry content trust and configure the AKS cluster to verify image signatures via Azure Policy.

---

#### [MEDIUM] Library Sync Failure is Silent — Data Integrity Risk

- **File:** `order-service/src/services/userClient.js:9-22`, `order-service/src/routes/orders.js:40-43`
- **Description:** During checkout, if the call to add purchased games to the user's library fails, the order is still marked as completed and the error is silently swallowed. The user has paid (transaction committed) but doesn't receive their games. This represents a business-logic data integrity failure.
- **Evidence:**
  ```javascript
  await userClient.addToLibrary(userId, gameIds, order.id);  // failure silently ignored
  await cartModel.clearCart(userId);
  res.status(201).json({ order: { ...order, items: orderItems } });
  ```
- **Remediation:** Implement a transactional outbox pattern or a retry queue (e.g., a simple DB-backed job table). At minimum, if `addToLibrary` fails, mark the order with a `library_sync_pending` status and implement a background reconciliation job.

---

#### [LOW] No Subresource Integrity (SRI) for External Resources

- **File:** `frontend/` (build output)
- **Description:** The Vite build produces hashed bundle filenames (`index-CKpJX8Zi.css`) which provides cache-busting but not supply-chain integrity. If external fonts, analytics, or CDN-hosted scripts are added in the future without SRI, they would represent an integrity risk.
- **Remediation:** The current setup with no external CDN scripts is good. Document a policy requiring SRI hashes for any future externally hosted resource additions.

---

### A09 — Security Logging and Monitoring Failures

#### [HIGH] Authentication Events Not Logged

- **File:** `user-service/Controllers/AuthController.cs:54-73`
- **Description:** Successful and failed login events are not logged at all. This makes it impossible to detect credential-stuffing attacks, impossible to correlate suspicious activity, and non-compliant with most security standards (PCI-DSS, SOC 2) which require authentication event logging.
- **Evidence:**
  ```csharp
  [HttpPost("login")]
  public async Task<IActionResult> Login([FromBody] LoginRequest request)
  {
      var user = await _context.Users.FirstOrDefaultAsync(...);
      if (user == null || !BCrypt.Net.BCrypt.Verify(...))
          return Unauthorized(...);   // no log of failure
      // ... no log of success either
  ```
- **Remediation:** Inject `ILogger<AuthController>` and log:
  - Failed attempts: `LogWarning("Failed login for username {Username} from IP {IP}", request.Username, ip)`
  - Successful logins: `LogInformation("User {UserId} authenticated from IP {IP}", user.Id, ip)`
  - Ensure logs are forwarded to Azure Monitor/Log Analytics (already wired via the AKS OMS agent in Terraform).

---

#### [HIGH] No Audit Logging for Admin Operations

- **File:** `game-catalog-service/app/routes/games.py:267-338`
- **Description:** Admin-only operations — create game, update game, delete game — produce no audit log entries. There is no record of which admin performed what change at what time.
- **Evidence:**
  ```python
  @router.delete("/api/games/{game_id}", status_code=204)
  async def delete_game(game_id: UUID, authorization: str = Header(...), db: Session = Depends(get_db)):
      user_id = _extract_user_id(authorization)
      is_admin = await validate_admin(user_id)
      if not is_admin:
          raise HTTPException(status_code=403, detail="Admin access required")
      # No audit log: who deleted what, when
      db.delete(game)
  ```
- **Remediation:** Add structured audit logging (at `INFO` level) for all admin mutations: `logger.info("Admin %s deleted game %s", user_id, game_id)`. Forward to a tamper-evident log sink (Azure Monitor, immutable storage).

---

#### [MEDIUM] Unauthorized Access Attempts Not Logged

- **File:** `game-catalog-service/app/services/user_client.py:6-14`
- **Description:** When `validate_admin()` returns `False` and an HTTP 403 is returned, no security log is generated. Repeated 403 responses on admin endpoints are a classic indicator of authorization probing.
- **Evidence:**
  ```python
  async def validate_admin(user_id: str) -> bool:
      try:
          ...
          return data.get("is_admin", False) is True
      except Exception:
          return False   # silent failure, no log
  ```
- **Remediation:** Log the user_id and the attempted action at `WARNING` level both when `validate_admin` returns `False` and when the caller raises a 403 HTTP response.

---

#### [MEDIUM] PII Logged in Plain Text

- **File:** `order-service/src/services/userClient.js:17`
- **Description:** User IDs (UUIDs) are logged in error messages. While UUIDs are low-entropy PII, they are directly usable to reference users in the database and constitute personal data under GDPR. Additionally, the order-service logs contain usernames and email addresses via the JWT payload in error stack traces.
- **Evidence:**
  ```javascript
  console.error(`Failed to sync library for user ${userId}:`, 'User service unavailable');
  ```
- **Remediation:** Replace direct PII logging with hashed/truncated identifiers (`userId.slice(0, 8) + '...'`) for operational logs, or use structured logging that can be configured to mask PII fields at the transport layer.

---

### A10 — Server-Side Request Forgery (SSRF)

#### [MEDIUM] `AvatarUrl` Field is a User-Controlled URL Without Validation (SSRF Vector)

- **File:** `user-service/Controllers/UsersController.cs:75-76`
- **Description:** The `AvatarUrl` is stored as an arbitrary string. While the current codebase does not appear to make HTTP requests to this URL (it is only returned in profile responses), the pattern creates a latent SSRF vulnerability: any future feature that fetches/proxies this URL (e.g., avatar caching, image resizing) would inherit the SSRF risk. An attacker could set `AvatarUrl` to `http://169.254.169.254/metadata` (Azure IMDS) to probe cloud metadata.
- **Evidence:**
  ```csharp
  if (request.AvatarUrl != null)
      user.AvatarUrl = request.AvatarUrl;  // no scheme/domain validation
  ```
- **Remediation:** Validate that `AvatarUrl` is an `https://` URL on an explicitly allowlisted domain. Reject any `http://`, `file://`, `javascript:`, or IP-literal URLs. Implement this now to prevent future SSRF exposure as the codebase grows.

---

#### [LOW] Internal Service URL Construction from Concatenated User Input

- **File:** `order-service/src/services/catalogClient.js:10`
- **Description:** The catalog client constructs URLs by appending user-controlled `gameId` to the base URL path: `` client.get(`/internal/games/${gameId}`) ``. While `gameId` values are UUID-format strings validated in the cart insertion flow, the path concatenation without sanitization could be exploited if validation is ever relaxed. Path traversal characters (`../`) or encoded slashes could redirect the request to unintended endpoints.
- **Evidence:**
  ```javascript
  async function getGame(gameId) {
    const { data } = await client.get(`/internal/games/${gameId}`);  // unsanitized
  ```
- **Remediation:** Validate `gameId` against a strict UUID regex before use in URL construction: `/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i`. Axios's built-in path construction does not prevent path traversal in interpolated segments.

---

## Security Metrics

| Metric | Value |
|---|---|
| Total Findings | 39 |
| Critical | 4 |
| High | 14 |
| Medium | 14 |
| Low | 7 |
| Informational | 0 |
| Files Reviewed | 46 |
| Lines of Code Reviewed | ~2,100 |

---

## Positive Security Practices

The following practices reflect genuinely good security engineering present in the codebase:

1. **BCrypt password hashing** — Passwords are hashed using BCrypt with default cost factor, correctly implemented in `AuthController.cs`.
2. **Kubernetes pod hardening** — All pods run as non-root users, with `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, `seccompProfile: RuntimeDefault`, and `capabilities.drop: ALL`. This is exemplary container security.
3. **Default-deny Kubernetes NetworkPolicies** — A proper default-deny-all + explicit allow pattern is implemented for all services, effectively enforcing least-privilege east-west traffic.
4. **Parameterized SQL queries** — All database access uses parameterized queries (SQLAlchemy ORM, `pg` pool with `$1/$2` placeholders, EF Core). SQL injection is effectively prevented across the entire data layer.
5. **JWT properly verified server-side** — The order-service `auth.js` middleware calls `jwt.verify()` with explicit `{ algorithms: ['HS256'] }` constraint, preventing algorithm confusion attacks.
6. **Multi-stage Docker builds with minimal base images** — All Dockerfiles use multi-stage builds and `-slim` or `-alpine` base images, minimizing the attack surface.
7. **ResourceQuota and LimitRange enforced** — The Kubernetes namespace has hard resource quotas preventing resource exhaustion attacks.
8. **`automountServiceAccountToken: false`** — All service accounts disable automatic token mounting, preventing container-escape-to-cluster-admin escalation via RBAC.
9. **ORM-based data access with one-review-per-user enforcement** — The game catalog service correctly enforces uniqueness constraints at both the database and application layers.
10. **Terraform AKS cluster uses Workload Identity** — The AKS module enables OIDC issuer and Workload Identity federation, following the modern zero-trust approach to pod-level cloud credentials.

---

## Top 5 Remediation Priorities

1. **[IMMEDIATE] Rotate and externalize the JWT secret.** Remove the hardcoded `"ps-store-jwt-secret-key-change-in-production"` from all config files and Kubernetes manifests. Store the secret in Azure Key Vault and inject it via External Secrets Operator. Generate a cryptographically random 256-bit secret. Any deployed instance is currently fully compromised.

2. **[IMMEDIATE] Remove the hardcoded `admin/admin123` seed account.** Provision admin credentials via a one-time setup procedure driven by secrets management. Every deployed instance has a known-privileged account with a trivially guessable password.

3. **[IMMEDIATE] Add authentication to all `/internal/*` endpoints.** The order-service internal routes have no authentication at all, and the user-service internal controller uses `[AllowAnonymous]`. Add an internal service API key validated at the application layer, independent of (but in addition to) Kubernetes NetworkPolicies.

4. **[SHORT-TERM] Migrate JWT storage from `localStorage` to `HttpOnly` cookies and add nginx security headers.** These two changes together eliminate the two primary client-side attack vectors: XSS-driven token theft and clickjacking. The nginx `add_header Content-Security-Policy` directive also reduces XSS impact across the entire frontend.

5. **[SHORT-TERM] Pin Python dependencies and add SCA scanning to all CI pipelines.** The current unpinned `requirements.txt` means a single `pip install` in a new environment could pull a CVE-laden version of FastAPI, SQLAlchemy, or PyJWT. Add `pip-audit` and `npm audit --audit-level=high` gates to fail CI on known vulnerabilities.

---

## Conclusion

The PlayStation Store application shows genuine effort in infrastructure-level hardening — Kubernetes manifests are well-structured, container security contexts are properly configured, and database access correctly uses parameterized queries throughout. However, the application layer harbors four critical vulnerabilities (hardcoded JWT secret committed to git, default admin credentials, and unauthenticated internal APIs) that represent immediate exploitation risk in any deployed environment. These must be treated as P0 blockers for production deployment.

The recommended remediation path is: (1) treat the JWT secret as compromised and rotate immediately, (2) remove the admin seed and replace with a secrets-driven provisioning process, (3) gate all internal routes with service-level authentication, (4) add nginx security headers and migrate token storage to HttpOnly cookies, and (5) establish automated dependency vulnerability scanning in CI. Addressing these five priorities will raise the effective security posture from **Critical** to **Low-Medium** risk, with the remaining findings suitable for a tracked sprint backlog.
