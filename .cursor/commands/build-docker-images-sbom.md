# docker-build-all

Build **all** application container images with the **same tag** on every image, and produce **SBOM** artifacts next to the build. Stop and report if any step fails.

## Services and image names (must match Helm `values.yaml`)

Build from the **repository root** (`Playstation store`). Use these contexts and image repositories (no registry prefix unless the user specifies one):

| Build context | Image repository (`-t` name before tag) |
|----------------|----------------------------------------|
| `frontend/` | `ps-store/frontend` |
| `game-catalog-service/` | `ps-store/game-catalog-service` |
| `order-service/` | `ps-store/order-service` |
| `user-service/` | `ps-store/user-service` |

## Step 1 — Resolve tag and optional registry prefix

1. **Tag (`TAG`)** — use **one** value for all four images in this run:
   - If the user supplied a tag in their message (e.g. `1.4.0`, `20260424-abc1234`), use that exactly.
   - Else if this is a git repo: run `git describe --tags --always --dirty` (or on Windows PowerShell: `git describe --tags --always --dirty 2>$null`; if it fails, fall back below).
   - Else: use UTC stamp `YYYYMMDD-HHmmss` (e.g. `20260424-143022`).
2. **Registry prefix (`REG_PREFIX`)** — empty by default. If the user asked for a registry (e.g. `ghcr.io/acme/`, `myacr.azurecr.io/`), set `REG_PREFIX` to that string **with a trailing slash** if not already present. Full image reference: `${REG_PREFIX}ps-store/<service>:${TAG}`.

Echo `TAG` and `REG_PREFIX` to the user before building.

## Step 2 — Prepare output directory for SBOM files

From the repo root, create `dist/sbom/` if it does not exist. All SBOM files for this run go there.

Suggested filenames (replace `<TAG>` with the actual tag, sanitized for filenames if needed, e.g. replace `:` with `-`):

- `dist/sbom/frontend-<TAG>.spdx.json`
- `dist/sbom/game-catalog-service-<TAG>.spdx.json`
- `dist/sbom/order-service-<TAG>.spdx.json`
- `dist/sbom/user-service-<TAG>.spdx.json`

## Step 3 — Ensure BuildKit / buildx

1. Prefer `docker buildx version`; if missing, instruct the user to install Docker Buildx or use Docker Desktop.
2. Use a builder that supports SBOM (default `docker-container` or desktop driver is fine). If builds fail with SBOM-related errors, retry once with `DOCKER_BUILDKIT=1` explicitly set.

## Step 4 — Build each image with SBOM generation and load into the local engine

For **each** row in the table in Step 1, from the repo root:

1. Run a build that enables SBOM and loads the image locally, for example:

   **PowerShell (repo root):**

   ```powershell
   $TAG = "<resolved TAG>"
   $REG_PREFIX = "<resolved REG_PREFIX>"   # e.g. "" or "ghcr.io/org/"
   docker buildx build `
     --sbom=true `
     -f <context>/Dockerfile `
     -t "${REG_PREFIX}ps-store/<service-short-name>:${TAG}" `
     --load `
     <context>/
   ```

   Use the real context path and image name from the table (`frontend`, `game-catalog-service`, `order-service`, `user-service`).

2. Confirm the image appears: `docker image inspect "${REG_PREFIX}ps-store/<name>:${TAG}"` (or equivalent).

**Order:** any order is fine; keep the **same** `TAG` and `REG_PREFIX` for all four builds.

## Step 5 — Export SBOM files (SPDX JSON)

After each image is built, write SPDX JSON into `dist/sbom/` using **one** of these approaches (try in order):

1. **Docker Scout** (common on Docker Desktop):  
   `docker scout sbom --format spdx-json "${REG_PREFIX}ps-store/<name>:${TAG}"` and redirect stdout to the matching `dist/sbom/*.spdx.json` file.
2. If `docker scout` is unavailable, try **Syft** if installed:  
   `syft "${REG_PREFIX}ps-store/<name>:${TAG}" -o spdx-json=dist/sbom/<file>.spdx.json`
3. If neither works, document which tool is missing and suggest: install [Syft](https://github.com/anchore/syft) or use Docker Desktop with Scout; still report success for image builds and list the four image references the user can scan manually.

Do not claim SBOM export succeeded without a non-empty SPDX file or clear tool output.

## Step 6 — Summary for the user

Report:

- The **exact** four `docker pull`-style references built (with `REG_PREFIX` and `TAG`).
- Paths to the four SBOM files under `dist/sbom/`, or which exports failed and why.
- One-line reminder: set Helm `image.repository` / `image.tag` (or your CI variables) to match `REG_PREFIX` and `TAG` when deploying.

## Safety rules

- Do not push to a registry unless the user explicitly asks.
- Do not embed secrets in tags or commands.
- If `dist/sbom/` is gitignored, mention that SBOMs are local-only unless committed or uploaded by the user.
