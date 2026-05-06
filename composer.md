# Security-Focused Code Review Report

**Reviewer model:** Composer  
**Scope:** Repository snapshot — frontend (React/Vite), user-service (ASP.NET Core), order-service (Node/Express), game-catalog-service (FastAPI), Helm/Kubernetes templates, static nginx config  
**Framework mapping:** [OWASP Top 10 (2021)](https://owasp.org/Top10/)  
**Methodology:** Manual review of authentication, authorization, secret handling, injection surfaces, CORS, internal APIs, and transport assumptions. No dependency CVE scan was executed in this pass (see recommendations).

---

## Executive metrics

| Metric | Value |
|--------|------:|
| Total findings | 18 |
| Critical | 0 |
| High | 4 |
| Medium | 7 |
| Low | 4 |
| Informational | 3 |
| OWASP categories touched | 8 / 10 |

### Severity distribution

```
Critical  █ 0
High      ████ 4
Medium    ███████ 7
Low       ████ 4
Info      ███ 3
```

### Findings by OWASP Top 10 (2021)

| ID | Category | Count |
|----|----------|------:|
| A01 | Broken Access Control | 5 |
| A02 | Cryptographic Failures | 2 |
| A03 | Injection | 0 (ORM/parameterized queries; see notes) |
| A04 | Insecure Design | 2 |
| A05 | Security Misconfiguration | 5 |
| A06 | Vulnerable and Outdated Components | 1 |
| A07 | Identification and Authentication Failures | 2 |
| A08 | Software and Data Integrity Failures | 0 |
| A09 | Security Logging and Monitoring Failures | 1 |
| A10 | Server-Side Request Forgery (SSRF) | 0 |

---

## Positive controls observed

| Area | Evidence |
|------|----------|
| Password storage | BCrypt hashing on register (`AuthController`) |
| SQL injection resistance | Parameterized queries in order-service (`order.js` models) |
| JWT verification (APIs) | `jwt.verify` with explicit `HS256` in order-service auth middleware |
| User-scoped resources | Orders and cart scoped to `req.user` / JWT `sub` |
| Helm hygiene | `values.yaml` documents secrets via external K8s Secrets |
| Pod hardening | `automountServiceAccountToken: false` in workload templates |

---

## Detailed findings

### High

| ID | OWASP | Finding | Location / notes |
|----|-------|---------|------------------|
| H1 | A01 | **Unauthenticated internal APIs (user-service)** — `/internal/users/{id}/validate` and `/internal/users/{id}/library` are `[AllowAnonymous]`. Any caller that can reach these URLs can validate arbitrary users and append library entries without proving service identity. | `user-service/Controllers/InternalController.cs` |
| H2 | A01 | **Unauthenticated internal APIs (order-service)** — `/internal/orders/user/:userId/stats` (and related internal routes) have no auth middleware. Leaks per-user order aggregates and enables user enumeration if the internal surface is exposed or misrouted. | `order-service/src/routes/internal.js` |
| H3 | A02 | **Default secrets in repo** — `appsettings.json` ships with a fixed JWT secret and database password suitable only for local dev; risk if reused or deployed without override. | `user-service/appsettings.json` |
| H4 | A05 | **Permissive CORS (user-service)** — `AllowAnyOrigin`, `AllowAnyMethod`, `AllowAnyHeader` increases cross-origin attack surface for browser-based abuse (e.g., malicious sites invoking APIs where browser policy allows). | `user-service/Program.cs` |

### Medium

| ID | OWASP | Finding | Location / notes |
|----|-------|---------|------------------|
| M1 | A04 | **Admin authorization via unauthenticated internal call** — `validate_admin` calls user-service internal validate endpoint without service credentials; trust boundary is “network only.” Compromise of catalog→user path or DNS/MITM in poorly segmented networks is impactful. | `game-catalog-service/app/services/user_client.py` |
| M2 | A05 | **JWT validation gaps** — `ValidateAudience = false` weakens cross-service token semantics if keys are shared across apps. | `user-service/Program.cs` |
| M3 | A07 | **Tokens in `localStorage`** — JWT stored client-side; any XSS yields bearer token theft. Prefer httpOnly cookies + CSRF defenses for new flows, or strict CSP with minimal inline script. | `frontend/src/context/AuthContext.jsx`, `frontend/src/api/index.js` |
| M4 | A05 | **No browser security headers on static host** — nginx config lacks `Content-Security-Policy`, `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, etc. | `frontend/nginx.conf` |
| M5 | A07 | **Weak password policy** — registration only enforces `MinLength(6)`; no complexity or breach-check guidance. | `user-service/DTOs/AuthDTOs.cs` |
| M6 | A04 | **Client-side JWT “decode” for UI** — payload read without signature verification (`decodeToken`); acceptable for display-only if server always re-authorizes, but UI must never gate privileged actions on decoded claims alone. | `frontend/src/utils/token.js` |
| M7 | A01 | **PostgreSQL `ILIKE` wildcards** — user-controlled `search`/`category`/`platform` may include `%` and `_`, broadening results (abuse / odd UX), not classic SQLi due to parameterization. | `game-catalog-service/app/routes/games.py` |

### Low

| ID | OWASP | Finding | Notes |
|----|-------|---------|-------|
| L1 | A05 | **order-service `cors()` default** — permissive CORS on a JWT API is lower risk than cookie sessions but still unnecessary openness. | `order-service/src/index.js` |
| L2 | A09 | **Generic 500 errors** — helpful for users; ensure production logs capture correlation IDs without leaking secrets. | Multiple services |
| L3 | A05 | **Default HTTP API URLs in frontend** — `localhost` fallbacks are fine for dev; production must enforce HTTPS via env. | `frontend/src/api/index.js` |
| L4 | A02 | **Duplicate JWT decode** — `create_review` decodes token twice; minor hygiene / timing consistency. | `game-catalog-service/app/routes/games.py` |

### Informational

| ID | Notes |
|----|-------|
| I1 | Cart/checkout pulls prices from catalog at checkout time — good mitigation vs. client-tampered cart prices. |
| I2 | `game-catalog-service` uses SQLAlchemy filters (parameterized) — aligns with A03 risk reduction. |
| I3 | NetworkPolicy templates exist (`helm/ps-store/templates/network-policies.yaml`) — helps segment internal traffic when enabled. |

---

## Recommended next steps (prioritized)

1. **Protect internal routes:** Mutual TLS, signed service JWTs, or Kubernetes NetworkPolicies **plus** application-level shared secrets / `Authorization` headers between services; never rely on “internal” path names alone.
2. **Remove or segregate default secrets** from tracked config; use env/Key Vault references only in deployment.
3. **Tighten CORS** to known frontend origins; avoid `AllowAnyOrigin` in production.
4. **Add nginx (or ingress) response headers** — CSP, `frame-ancestors`, MIME-sniffing protections.
5. **Run automated SCA** — `npm audit`, `dotnet list package --vulnerable`, `pip-audit` / Dependabot, and container image scans (Trivy) in CI.
6. **Rate-limit** `/api/auth/login` and `/api/auth/register` to reduce credential stuffing and enumeration pacing.

---

## Report metadata

| Field | Value |
|-------|-------|
| Output file | `composer.md` |
| Review type | OWASP-oriented static analysis (manual) |
| Dynamic testing | Not performed |
| Dependency CVE audit | Not performed (recommended) |
