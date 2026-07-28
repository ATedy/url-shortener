#!/usr/bin/env bash
#
# URL Shortener — GitHub issue seeding script
# ============================================
# Creates all labels, 9 epic tracking issues, and 33 story issues
# for the URL Shortener DevOps learning project.
#
# Prerequisites:
#   1. `gh` CLI installed and authenticated (`gh auth status` should succeed)
#   2. Run this script from inside the repository directory (so `gh` picks
#      up the repo automatically), OR set the REPO env var:
#         REPO=owner/url-shortener ./create-issues.sh
#
# Idempotency:
#   - Label creation uses `|| true` so re-runs won't fail on existing labels
#   - Issue creation is NOT idempotent — running twice will create duplicates.
#     Comment out any section you've already run.
#
# To review before creating anything, run:
#     bash -n create-issues.sh    # syntax check only
#     grep '^# EPIC' create-issues.sh    # see the epic list
#
set -euo pipefail

REPO_ARG=""
if [[ -n "${REPO:-}" ]]; then
  REPO_ARG="--repo $REPO"
fi

echo "==> Preparing to create labels and issues"
echo "    Repo: ${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo 'current dir')}"
echo ""

# =============================================================================
# SECTION 1 — Labels
# =============================================================================
# Colours picked for legibility: epic labels use warm tones, area labels cool,
# priority labels standard traffic-light.

echo "==> Creating labels (existing ones will be skipped)"

create_label() {
  local name="$1" color="$2" description="$3"
  gh label create "$name" --color "$color" --description "$description" $REPO_ARG 2>/dev/null \
    || echo "    (label '$name' already exists — skipped)"
}

# Meta
create_label "epic"                 "8B4FBB" "Parent tracking issue for an epic"
create_label "type:story"           "0E8A16" "Standard story-sized unit of work"

# Epic labels (one per epic, applied to both the epic issue and its child stories)
create_label "epic:foundation"      "D93F0B" "Epic 1 — App Foundation"
create_label "epic:testing"         "1D76DB" "Epic 2 — Testing"
create_label "epic:caching"         "5319E7" "Epic 3 — Caching & Rate Limiting"
create_label "epic:docker"          "0366D6" "Epic 4 — Dockerisation"
create_label "epic:k8s"             "006B75" "Epic 5 — Kubernetes Manifests"
create_label "epic:terraform"       "7057FF" "Epic 6 — Infrastructure as Code (Terraform)"
create_label "epic:observability"   "FBCA04" "Epic 7 — Observability"
create_label "epic:cicd"            "C5DEF5" "Epic 8 — CI/CD Pipeline"
create_label "epic:docs"            "BFD4F2" "Epic 9 — Documentation & Portfolio Polish"

# Priority
create_label "priority:high"        "B60205" "Blocks progress or on a critical path"
create_label "priority:medium"      "FBCA04" "Normal priority"
create_label "priority:low"         "0E8A16" "Nice-to-have, can be deferred"

# Area
create_label "area:backend"         "1D76DB" "Application code (Node/Express/Prisma)"
create_label "area:infra"           "5319E7" "K8s manifests, Docker, cloud infrastructure"
create_label "area:devops"          "0075CA" "CI/CD, observability, security tooling"
create_label "area:docs"            "C5DEF5" "READMEs, diagrams, write-ups"

echo ""

# =============================================================================
# Helper — create an issue with a heredoc body
# =============================================================================

create_issue() {
  local title="$1" labels="$2" body="$3"
  gh issue create $REPO_ARG \
    --title "$title" \
    --label "$labels" \
    --body "$body" \
    | tee -a .issues-created.log
}

# Clear the log for this run
: > .issues-created.log

# =============================================================================
# SECTION 2 — Epic tracking issues
# =============================================================================
# Each epic is a single tracking issue. Child stories reference the epic
# via a shared `epic:<name>` label so you can filter/board them together.
# Once stories are created you can (optionally) go back and add a task list
# to each epic with the story issue numbers.

echo "==> Creating epic tracking issues"

# ---- EPIC 1 ---------------------------------------------------------------
create_issue \
  "Epic 1 — App Foundation" \
  "epic,epic:foundation,priority:high" \
  "$(cat <<'EOF'
## Goal
Build the core Node/Express + PostgreSQL application that everything else in the project will containerise, orchestrate, monitor, and ship. Get the shape of the app right before it goes anywhere near Docker or Kubernetes.

## Scope
- Bootstrap Express + TypeScript with the three canonical endpoints
- Connect PostgreSQL via Prisma with proper schema and migrations
- Short-code generation strategy using **nanoid** (with collision handling)
- Input validation, error handling, structured error responses

## Definition of done
- `npm run dev` starts the app locally against a Postgres instance
- All three endpoints work: `POST /shorten`, `GET /:code`, `GET /health`
- Prisma migrations committed and reproducible
- Structured JSON errors on all failure paths
- No `any`, strict TypeScript passes

## What this teaches
Clean project layout, TypeScript configuration, Prisma workflow, ORM patterns, HTTP error handling — the *unglamorous foundation* everything else stands on.
EOF
)"

# ---- EPIC 2 ---------------------------------------------------------------
create_issue \
  "Epic 2 — Testing" \
  "epic,epic:testing,priority:high" \
  "$(cat <<'EOF'
## Goal
Establish a tested codebase so the CI pipeline actually has something to run, and so the rest of the epics can refactor without fear.

## Scope
- **Unit tests** (Jest) for pure logic: code generator, validators, service layer with mocked Prisma
- **Integration tests** using Testcontainers to spin up a real Postgres per suite
- **API contract tests** with supertest hitting the Express app end-to-end

## Definition of done
- `npm test` runs all three test types and returns green
- Code coverage report generated (target: 70%+ on business logic)
- Tests run in CI without hitting external services
- Testcontainers documented in README (Docker required for local test runs)

## What this teaches
The testing pyramid in practice, dependency mocking, Testcontainers as an alternative to fragile in-memory DBs, and how to keep integration tests fast and deterministic.
EOF
)"

# ---- EPIC 3 ---------------------------------------------------------------
create_issue \
  "Epic 3 — Caching & Rate Limiting" \
  "epic,epic:caching,priority:medium" \
  "$(cat <<'EOF'
## Goal
Add the two features that make a URL shortener production-shaped rather than a CRUD demo: a Redis cache in front of the redirect endpoint, and rate limiting to protect against abuse.

## Scope
- Wire up Redis (ioredis) as a first-class dependency
- Cache-aside pattern on `GET /:code` — the hot path
- Rate limiting middleware backed by Redis (different limits per endpoint)

## Definition of done
- Redis appears in `docker-compose.yml` alongside Postgres
- Redirect endpoint checks Redis first, falls back to DB, populates cache on miss
- Cache TTL configurable via env var (default: 1 hour)
- `POST /shorten` is rate-limited more aggressively than `GET /:code`
- 429 responses include a `Retry-After` header
- Health check verifies both Postgres AND Redis connectivity

## What this teaches
Cache-aside pattern (the most common caching strategy), Redis as a distributed cache and rate-limit store, and the reasoning behind TTL choices — all staples of system design interviews.
EOF
)"

# ---- EPIC 4 ---------------------------------------------------------------
create_issue \
  "Epic 4 — Dockerisation" \
  "epic,epic:docker,priority:high" \
  "$(cat <<'EOF'
## Goal
Containerise the application properly. Multi-stage Dockerfile, small image, non-root user, docker-compose for local dev with all three services (app, Postgres, Redis).

## Scope
- Multi-stage Dockerfile (builder → runner) targeting < 200MB
- `docker-compose.yml` with app + Postgres + Redis and healthchecks
- `.dockerignore` and full end-to-end verification

## Definition of done
- `docker build` produces an image under 200MB
- Container runs as non-root (verify with `docker exec whoami`)
- `docker-compose up` brings the whole stack up cleanly
- All endpoints work through the composed stack
- Data persists across `docker-compose down` / `up` cycles

## What this teaches
Multi-stage builds, layer caching, image slimming, Docker healthchecks, container security basics (non-root user, minimal base image), and multi-service local dev with compose.
EOF
)"

# ---- EPIC 5 ---------------------------------------------------------------
create_issue \
  "Epic 5 — Kubernetes Manifests" \
  "epic,epic:k8s,priority:high" \
  "$(cat <<'EOF'
## Goal
Run the whole stack on Kubernetes (minikube for cost reasons, but every manifest is EKS-compatible). This is the deepest learning epic in the project.

## Scope
- Install minikube, enable ingress + metrics-server addons
- Deployment for the app (with liveness + readiness probes, resource limits, rolling update strategy)
- Deployment + PVC for Postgres (stateful workload)
- Deployment for Redis (in-cluster, no persistence — noted intentionally)
- Services (all ClusterIP; external access via Ingress)
- ConfigMap + Secret for configuration and credentials
- Ingress via nginx-ingress addon
- HorizontalPodAutoscaler for the app deployment

## Definition of done
- `kubectl apply -k k8s/` (or plain `-f`) brings everything up
- `kubectl get pods` shows all pods Running and Ready
- App reachable through the Ingress hostname
- HPA scales replicas under load (verified with a load-generation test)
- All manifests annotated with "how this maps to EKS" comments

## What this teaches
Real K8s primitives — not just Deployments and Services, but Ingress, HPA, PVCs, ConfigMap/Secret patterns, probes, and rolling updates. The comments make it clear this is the same manifest you'd apply to a managed cluster.
EOF
)"

# ---- EPIC 6 ---------------------------------------------------------------
create_issue \
  "Epic 6 — Infrastructure as Code (Terraform)" \
  "epic,epic:terraform,priority:high" \
  "$(cat <<'EOF'
## Goal
Move the AWS side of the project out of the console and into Terraform. Small in scope on purpose — the point is *learning the workflow*, not managing a fleet.

## Scope
- Terraform bootstrap: provider config, backend (local for learning, S3 documented for production)
- ECR repository as code
- IAM user + least-privilege policy for CI/CD as code
- CloudWatch log group with retention as code

## Definition of done
- `terraform init && terraform plan && terraform apply` provisions everything
- All AWS resources previously created by hand are now Terraform-managed
- `terraform destroy` cleans them up cleanly
- README explains the local-state trade-off and the S3-backend upgrade path

## What this teaches
The IaC workflow (plan → apply → destroy), Terraform state, provider configuration, least-privilege IAM, and the general habit of *declaring* infrastructure rather than clicking it. This is the single highest-leverage DevOps skill for a software engineer.
EOF
)"

# ---- EPIC 7 ---------------------------------------------------------------
create_issue \
  "Epic 7 — Observability" \
  "epic,epic:observability,priority:medium" \
  "$(cat <<'EOF'
## Goal
Turn the app from a black box into something you can debug in production. Logs, metrics, and one AWS-native destination.

## Scope
- Structured logging with **pino** (replace all `console.log`)
- Prometheus `/metrics` endpoint exposing default + custom counters (cache hits/misses, urls_created, redirects_served)
- Ship container logs to CloudWatch Logs

## Definition of done
- Every log line is valid JSON with a level, timestamp, and (where applicable) request ID
- `curl /metrics` returns Prometheus-format text with custom counters incrementing correctly
- Logs from a running container appear in the CloudWatch log group provisioned in Epic 6
- Log level configurable via env (info in prod, debug in dev)

## What this teaches
The three pillars of observability (metrics, logs, traces — you'll do metrics and logs here), structured logging conventions, the Prometheus data model, and cloud-native log shipping.
EOF
)"

# ---- EPIC 8 ---------------------------------------------------------------
create_issue \
  "Epic 8 — CI/CD Pipeline" \
  "epic,epic:cicd,priority:high" \
  "$(cat <<'EOF'
## Goal
Automate the full path from `git push` to a signed, scanned image in ECR, with a documented (and one-command-away) path to deploy.

## Scope
- GitHub Actions workflow: lint + test on every PR
- Trivy image scanning gate (fail on HIGH/CRITICAL vulns)
- ECR push on merge to main (tagged with commit SHA + `latest`)
- Kubectl deploy step — documented as manual for minikube, with the EKS automation path shown alongside

## Definition of done
- Every PR runs lint + tests and blocks merge on failure
- Every merge to main pushes a scanned image to ECR
- SARIF results from Trivy upload to the GitHub Security tab
- README contains a diagram and description of the full pipeline
- The "how this becomes fully automated on EKS" section is written

## What this teaches
GitHub Actions workflow syntax, matrix builds, secrets management, cloud auth from CI (access keys now; OIDC noted as the production upgrade), supply-chain security via image scanning, and the full delivery pipeline mental model.
EOF
)"

# ---- EPIC 9 ---------------------------------------------------------------
create_issue \
  "Epic 9 — Documentation & Portfolio Polish" \
  "epic,epic:docs,priority:high" \
  "$(cat <<'EOF'
## Goal
Make this project legible to a human being who has never seen it — because that's who reads it before an interview.

## Scope
- Comprehensive README with architecture diagram, setup, and pipeline description
- Architecture Decisions document explaining the *why* behind each choice
- System-design write-up positioning this as a URL shortener case study

## Definition of done
- README renders cleanly on GitHub with a Mermaid or ASCII architecture diagram
- Someone can go from `git clone` to a running local stack following only the README
- ARCHITECTURE.md exists with at least 6 decisions each explaining the trade-off
- SYSTEM-DESIGN.md exists with storage estimates, cache hit-rate targets, and "what breaks at 10× / 100× traffic" reasoning

## What this teaches
Technical writing — arguably the highest-leverage soft skill in engineering. Every senior interview will ask you to walk through a project; this documentation is the script.
EOF
)"

echo ""

# =============================================================================
# SECTION 3 — Story issues
# =============================================================================

echo "==> Creating story issues"

# ==================== EPIC 1: App Foundation ================================

create_issue \
  "Bootstrap Express + TypeScript application" \
  "type:story,epic:foundation,area:backend,priority:high" \
  "$(cat <<'EOF'
## Description
Initialise a Node/Express project with TypeScript in strict mode. Set up the three canonical endpoints as stubs — real implementation lands in later stories once Prisma and validation are in place.

## Tasks
- [ ] `npm init -y`, install `express`, `typescript`, `ts-node-dev`, `@types/express`, `@types/node`
- [ ] `tsconfig.json` with `strict: true`, `noUncheckedIndexedAccess: true`, target ES2022
- [ ] Project layout: `src/app.ts`, `src/server.ts`, `src/routes/`, `src/services/`, `src/config/`
- [ ] Endpoint stubs:
  - `POST /shorten` — accept `{ url: string }`, return `{ code: string, shortUrl: string }` (stub)
  - `GET /:code` — return `302` redirect (stub returns fixed URL)
  - `GET /health` — return `{ status: 'ok', uptime: process.uptime() }`
- [ ] Env-driven config module reading `PORT`, `NODE_ENV`
- [ ] `npm run dev` script using `ts-node-dev`
- [ ] `npm run build` compiles cleanly to `dist/`

## Acceptance criteria
- App boots with `npm run dev` and listens on `PORT` (default 3000)
- All three endpoints return valid responses (even if stubbed)
- `npm run build` produces working JS in `dist/`
- `tsc --noEmit` passes with zero errors

## Not in scope
- Database (Story 1.2)
- Real short-code generation (Story 1.3)
- Validation (Story 1.4)
EOF
)"

create_issue \
  "Connect PostgreSQL with Prisma" \
  "type:story,epic:foundation,area:backend,priority:high" \
  "$(cat <<'EOF'
## Description
Add Prisma ORM, define the `Url` model, and wire the endpoints to persist data.

## Tasks
- [ ] `npm install prisma @prisma/client`, `npx prisma init`
- [ ] Define schema:
  ```prisma
  model Url {
    id          Int      @id @default(autoincrement())
    code        String   @unique
    originalUrl String
    createdAt   DateTime @default(now())
    clickCount  Int      @default(0)
    @@index([code])
  }
  ```
- [ ] Create `PrismaService` singleton (or module-level export) with proper connect/disconnect lifecycle
- [ ] `POST /shorten` writes to DB (with a placeholder code — real generation in Story 1.3)
- [ ] `GET /:code` reads from DB, increments `clickCount`, redirects
- [ ] Run `npx prisma migrate dev --name init`, commit the migration
- [ ] `DATABASE_URL` in `.env.example`

## Acceptance criteria
- Prisma schema + initial migration committed
- App reads and writes to Postgres successfully
- `GET /:code` returns 302 with the original URL in the `Location` header
- Migration reproducible on a fresh DB with `prisma migrate deploy`

## Depends on
- Story: Bootstrap Express + TypeScript application
EOF
)"

create_issue \
  "Short-code generation with nanoid + collision handling" \
  "type:story,epic:foundation,area:backend,priority:high" \
  "$(cat <<'EOF'
## Description
Replace the placeholder code generation with **nanoid**, using a URL-safe alphabet. Handle the (extremely rare) collision case explicitly so the behaviour is defensible in an interview.

## Tasks
- [ ] `npm install nanoid`
- [ ] Create `src/services/codeGenerator.ts`:
  ```ts
  import { customAlphabet } from 'nanoid';
  // URL-safe base62 (no ambiguous chars: 0/O, 1/l/I)
  const ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  const generateCode = customAlphabet(ALPHABET, 7);
  ```
- [ ] Collision-retry logic: attempt insert, catch unique-constraint violation, retry up to 3 times, then throw a `CodeGenerationError`
- [ ] Unit test for the retry logic (mock Prisma to force collisions)

## Rationale (worth writing in a code comment)
- 57^7 ≈ 1.9 trillion possible codes → at 1M URLs, collision probability per generation is ~5×10⁻⁷
- The retry loop is defensive, not a hot path — logs a warning if it ever triggers
- Alphabet excludes visually ambiguous characters (better UX on printed short URLs)

## Acceptance criteria
- Generated codes are 7 chars, from the specified alphabet
- Unique constraint on `code` column enforces uniqueness
- Collision retry works (verified by unit test with a forced mock collision)
- Third consecutive collision fails loudly with a structured error

## Depends on
- Story: Connect PostgreSQL with Prisma
EOF
)"

create_issue \
  "Input validation, error handling, and structured responses" \
  "type:story,epic:foundation,area:backend,priority:medium" \
  "$(cat <<'EOF'
## Description
Production-grade error handling: strict input validation, a global error handler, and consistent JSON error responses across every endpoint.

## Tasks
- [ ] Install `zod` (lightweight, TypeScript-native)
- [ ] Zod schema for `POST /shorten` body: `url` must be a valid URL, reasonable length limits
- [ ] Reject URLs pointing at private/loopback ranges (SSRF prevention — brief note in code)
- [ ] Global Express error handler middleware — catches thrown errors and returns:
  ```json
  { "statusCode": 400, "message": "...", "code": "INVALID_URL" }
  ```
- [ ] `404` handler for unknown short codes with the same response shape
- [ ] Custom error classes: `ValidationError`, `NotFoundError`, `CodeGenerationError`
- [ ] Ensure no unhandled promise rejections (async error middleware)

## Acceptance criteria
- Invalid URLs → 400 with clear `message` and machine-readable `code`
- Empty body / missing `url` → 400
- Unknown short code on redirect → 404
- SSRF-y URLs (e.g. `http://localhost/`, `http://169.254.169.254/`) → 400
- Every error response is valid JSON with `statusCode`, `message`, and `code`

## Depends on
- Story: Connect PostgreSQL with Prisma
EOF
)"

# ==================== EPIC 2: Testing =======================================

create_issue \
  "Unit tests with Jest (services, validators, generator)" \
  "type:story,epic:testing,area:backend,priority:high" \
  "$(cat <<'EOF'
## Description
Establish Jest as the test runner and cover the pure-logic layer: code generation, URL validation, and the service layer with a mocked Prisma client.

## Tasks
- [ ] Install `jest`, `ts-jest`, `@types/jest`
- [ ] `jest.config.ts` with `ts-jest` preset, coverage output to `coverage/`
- [ ] Test suite for `codeGenerator.ts` — alphabet, length, collision retry
- [ ] Test suite for the Zod validators — happy path + each error type
- [ ] Test suite for the URL service — mocked Prisma using `jest.mock`
- [ ] `npm test` script; `npm run test:coverage` for coverage report

## Acceptance criteria
- `npm test` runs green with at least 15 tests
- Coverage on `src/services/` is ≥ 80%
- No test hits a real database or network
- Tests run in < 5 seconds locally

## Depends on
- Story: Short-code generation with nanoid + collision handling
- Story: Input validation, error handling, and structured responses
EOF
)"

create_issue \
  "Integration tests with Testcontainers (real Postgres)" \
  "type:story,epic:testing,area:backend,priority:medium" \
  "$(cat <<'EOF'
## Description
Add integration tests that spin up a real Postgres container per test suite using Testcontainers. This is a much better learning experience than sqlite-in-memory hacks and mirrors what serious teams actually do.

## Tasks
- [ ] `npm install --save-dev testcontainers`
- [ ] `tests/integration/setup.ts` — start a Postgres container, run `prisma migrate deploy` against it, expose the connection string to tests
- [ ] Integration test for the full `POST /shorten` → DB → `GET /:code` cycle
- [ ] Integration test for `clickCount` incrementing on redirect
- [ ] `npm run test:integration` script separate from unit tests
- [ ] Document Docker requirement in README

## Acceptance criteria
- Integration tests pass against a real Postgres container
- Suite starts and tears down the container cleanly
- No leftover containers after `npm run test:integration` (verify with `docker ps -a`)
- CI runs both unit and integration tests

## Depends on
- Story: Unit tests with Jest (services, validators, generator)
EOF
)"

create_issue \
  "API contract tests with supertest" \
  "type:story,epic:testing,area:backend,priority:medium" \
  "$(cat <<'EOF'
## Description
End-to-end HTTP tests using supertest — exercises the full Express app including middleware, error handling, and validation.

## Tasks
- [ ] `npm install --save-dev supertest @types/supertest`
- [ ] Test file per endpoint: `tests/api/shorten.test.ts`, `redirect.test.ts`, `health.test.ts`
- [ ] Happy path + at least 2 error paths per endpoint
- [ ] Assert status codes, response body shape (using inline JSON matchers), and headers where relevant (e.g. `Location` on redirect)

## Acceptance criteria
- Every endpoint has at least one happy-path and one error-path test
- Tests use a real Express app instance (not just mocked routes)
- Runs as part of `npm test`
- Coverage on `src/routes/` is ≥ 90%
EOF
)"

# ==================== EPIC 3: Caching & Rate Limiting =======================

create_issue \
  "Add Redis client and health-check integration" \
  "type:story,epic:caching,area:backend,priority:medium" \
  "$(cat <<'EOF'
## Description
Introduce Redis as a first-class dependency. This story doesn't use Redis for anything yet — it just wires the client, the config, and the health check.

## Tasks
- [ ] `npm install ioredis`
- [ ] `src/services/redisClient.ts` — singleton client with connection lifecycle
- [ ] `REDIS_URL` in `.env.example` and config module
- [ ] Extend `GET /health` to include Redis ping status alongside DB status:
  ```json
  { "status": "ok", "db": "up", "redis": "up", "uptime": 123 }
  ```
- [ ] Graceful degradation: if Redis is down, health returns `{ status: 'degraded', redis: 'down' }` but the app doesn't crash
- [ ] Add `redis:7-alpine` to `docker-compose.yml`

## Acceptance criteria
- App boots successfully with Redis running
- Health endpoint reports both DB and Redis status independently
- App boots (with warning logs) even if Redis is unreachable
- Redis appears in the compose stack

## Depends on
- Story: Input validation, error handling, and structured responses
EOF
)"

create_issue \
  "Cache-aside pattern on redirect endpoint" \
  "type:story,epic:caching,area:backend,priority:medium" \
  "$(cat <<'EOF'
## Description
The redirect endpoint is the hot path (reads outnumber writes by orders of magnitude in a URL shortener). Put Redis in front of it using the cache-aside pattern.

## Tasks
- [ ] Cache key: `url:<code>` → value: the `originalUrl` string
- [ ] `GET /:code` flow:
  1. Look up `url:<code>` in Redis
  2. HIT → return 302 immediately, fire-and-forget increment on DB
  3. MISS → query DB, if found set cache with TTL, return 302
- [ ] TTL configurable via `CACHE_TTL_SECONDS` (default 3600)
- [ ] Cache invalidation on delete/update (even though delete isn't implemented yet — leave a `TODO` and delete helper)
- [ ] Integration test: verify second request within TTL doesn't hit the DB (mock/spy Prisma)

## Acceptance criteria
- Second identical redirect within TTL returns without a DB query
- Cache entries expire correctly (test with a short TTL)
- Redis outage does NOT break redirects (falls back to DB)
- Design decision documented in a code comment: why cache-aside vs write-through

## Depends on
- Story: Add Redis client and health-check integration
EOF
)"

create_issue \
  "Rate limiting middleware backed by Redis" \
  "type:story,epic:caching,area:backend,priority:medium" \
  "$(cat <<'EOF'
## Description
Rate limiting is the other classic Redis use case. Apply different limits per endpoint — creation is expensive, redirects should be permissive, health should not be limited at all.

## Tasks
- [ ] Install `express-rate-limit` and `rate-limit-redis`
- [ ] Rate-limit config per route:
  - `POST /shorten` — 10 requests / minute / IP
  - `GET /:code` — 100 requests / minute / IP
  - `GET /health` — no limit
- [ ] Return `429 Too Many Requests` with a `Retry-After` header
- [ ] Structured error body consistent with other errors
- [ ] `X-RateLimit-*` headers for client visibility

## Acceptance criteria
- Exceeding a limit returns 429 with correct `Retry-After`
- Rate-limit state is shared across app instances (verify with 2 replicas in Docker)
- Limits configurable via env vars
- Health endpoint never rate-limits

## Depends on
- Story: Add Redis client and health-check integration
EOF
)"

# ==================== EPIC 4: Dockerisation =================================

create_issue \
  "Write multi-stage Dockerfile" \
  "type:story,epic:docker,area:infra,priority:high" \
  "$(cat <<'EOF'
## Description
Multi-stage Dockerfile targeting a small, secure production image.

## Tasks
- [ ] Stage 1 (`builder`, `node:20-alpine`): install all deps, run `prisma generate`, compile TS to `dist/`
- [ ] Stage 2 (`runner`, `node:20-alpine`): copy `dist/`, `node_modules` (production-only via `npm ci --omit=dev`), and `prisma/` folder
- [ ] Run as non-root `node` user (`USER node`)
- [ ] `EXPOSE 3000`, `CMD ["node", "dist/server.js"]`
- [ ] Add HEALTHCHECK instruction using the `/health` endpoint

## Acceptance criteria
- `docker build -t url-shortener:local .` succeeds
- Final image size under 200MB (`docker images url-shortener:local`)
- `docker run` starts the container; `docker exec whoami` returns `node`, not `root`
- HEALTHCHECK shows healthy status after startup
EOF
)"

create_issue \
  "docker-compose.yml for full local stack" \
  "type:story,epic:docker,area:infra,priority:high" \
  "$(cat <<'EOF'
## Description
Compose file with all three services (app, Postgres, Redis) and correct dependency ordering via healthchecks.

## Tasks
- [ ] Three services: `app`, `db` (postgres:15-alpine), `cache` (redis:7-alpine)
- [ ] Named volume for Postgres data
- [ ] Healthchecks on `db` and `cache`; `app` uses `depends_on: condition: service_healthy`
- [ ] `.env.example` listing all required variables
- [ ] Compose reads env vars from `.env` (git-ignored)
- [ ] `make dev` / npm script shortcut for `docker compose up --build`

## Acceptance criteria
- `docker compose up` brings the full stack up
- App waits for DB and Redis to be healthy before starting
- Postgres data survives `docker compose down` + `up`
- `.env` is gitignored; `.env.example` is committed
EOF
)"

create_issue \
  ".dockerignore + end-to-end verification" \
  "type:story,epic:docker,area:infra,priority:low" \
  "$(cat <<'EOF'
## Description
Add a proper `.dockerignore` to keep the build context small, then run a full end-to-end smoke test through the composed stack.

## Tasks
- [ ] `.dockerignore` excludes: `node_modules`, `.git`, `dist`, `coverage`, `.env*`, `*.md`, `tests/`
- [ ] Verify image size dropped (before vs after)
- [ ] Smoke test script (bash or Node) that:
  1. Waits for the stack to be healthy
  2. `POST /shorten` with a real URL, captures the returned code
  3. `GET /:code`, asserts 302 with correct `Location`
  4. `GET /health`, asserts `status: ok`
- [ ] Add the smoke test as a make target / npm script

## Acceptance criteria
- `.dockerignore` committed
- Smoke test passes against `docker compose up`
- Image size measurably smaller than before this story
EOF
)"

# ==================== EPIC 5: Kubernetes Manifests ==========================

create_issue \
  "Set up minikube + load image into cluster" \
  "type:story,epic:k8s,area:infra,priority:high" \
  "$(cat <<'EOF'
## Description
Get a local Kubernetes cluster running with the addons we'll need later (ingress, metrics-server), and put the app image where the cluster can find it.

## Tasks
- [ ] Install `minikube` and `kubectl` (document versions in README)
- [ ] `minikube start --cpus=4 --memory=6g --driver=docker`
- [ ] `minikube addons enable ingress`
- [ ] `minikube addons enable metrics-server`
- [ ] `eval $(minikube docker-env)` — point local Docker at minikube's daemon
- [ ] `docker build -t url-shortener:local .` (inside the minikube env)
- [ ] Verify with `minikube image ls | grep url-shortener`

## Acceptance criteria
- `minikube status` shows all components Running
- `kubectl get nodes` returns Ready
- `url-shortener:local` visible in `minikube image ls`
- Ingress and metrics-server addons enabled

## Note on production parity
This is a local cluster, but every manifest we write from here on is EKS-compatible. Comments in each manifest will call out the differences (imagePullPolicy, ingress class, storage class).
EOF
)"

create_issue \
  "App Deployment manifest (probes, resources, rolling update)" \
  "type:story,epic:k8s,area:infra,priority:high" \
  "$(cat <<'EOF'
## Description
Production-shaped Deployment for the app. Not just replicas — probes, resource limits, rolling update strategy, and env injection.

## Tasks
- [ ] `k8s/app-deployment.yaml`:
  - 2 replicas
  - `image: url-shortener:local`, `imagePullPolicy: Never` (minikube; comment: change to `Always` + ECR URI in prod)
  - Resource requests: 128Mi memory, 250m CPU
  - Resource limits: 256Mi memory, 500m CPU
  - **Readiness probe**: `GET /health`, initialDelay 5s, period 10s, failureThreshold 3
  - **Liveness probe**: `GET /health`, initialDelay 30s, period 30s, failureThreshold 3
  - Rolling update: `maxSurge: 1`, `maxUnavailable: 0`
  - `envFrom` referencing `app-config` ConfigMap + `app-secrets` Secret (created in later story)

## Acceptance criteria
- `kubectl apply -f k8s/app-deployment.yaml` succeeds
- `kubectl get pods` shows 2 pods, both Ready
- `kubectl describe pod` shows both probes passing
- Rolling update with `kubectl rollout restart deployment/app` completes with zero downtime

## Learning notes to include as comments
- Why readiness vs liveness (traffic vs restart)
- Why `maxUnavailable: 0` for zero-downtime deploys
EOF
)"

create_issue \
  "Postgres Deployment + PersistentVolumeClaim" \
  "type:story,epic:k8s,area:infra,priority:high" \
  "$(cat <<'EOF'
## Description
Stateful workload — Postgres needs a PVC. In production you'd use a StatefulSet or a managed DB (RDS); for the learning value here, a Deployment + PVC is fine and the trade-off is worth noting.

## Tasks
- [ ] `k8s/db-pvc.yaml`: `PersistentVolumeClaim` requesting 1Gi, `accessModes: [ReadWriteOnce]`
- [ ] `k8s/db-deployment.yaml`: 1 replica, `postgres:15-alpine`, mounts PVC at `/var/lib/postgresql/data`
- [ ] Postgres env from Secret (password) and ConfigMap (user, db name)
- [ ] Comment in manifest: "In production use RDS or a StatefulSet with a StorageClass, not a Deployment"

## Acceptance criteria
- `kubectl get pvc` shows `Bound`
- Postgres pod reaches `Running`
- Data survives `kubectl rollout restart deployment/db` (test by inserting a row, restarting, reading it back)
EOF
)"

create_issue \
  "Redis Deployment (in-cluster, ephemeral)" \
  "type:story,epic:k8s,area:infra,priority:medium" \
  "$(cat <<'EOF'
## Description
Redis for cache + rate-limit state. No persistence — intentionally. Documenting *why* is the learning outcome here.

## Tasks
- [ ] `k8s/redis-deployment.yaml`: 1 replica, `redis:7-alpine`, no volume
- [ ] Comment in manifest: "Ephemeral by design. Cache: OK to lose on restart. Rate-limit state: acceptable brief inaccuracy. In production, use ElastiCache."
- [ ] Resource requests: 64Mi memory, 100m CPU

## Acceptance criteria
- Redis pod reaches `Running`
- App connects to Redis via the service (created in the next story)
- Design trade-off documented in the manifest and README
EOF
)"

create_issue \
  "Service manifests (app, db, redis)" \
  "type:story,epic:k8s,area:infra,priority:high" \
  "$(cat <<'EOF'
## Description
Services so pods can find each other via stable DNS names, and (for the app only) so external traffic can reach it via Ingress.

## Tasks
- [ ] `k8s/app-service.yaml`: `ClusterIP`, port 80 → target 3000, name `app-service`
- [ ] `k8s/db-service.yaml`: `ClusterIP`, port 5432, name `db-service` (internal only — Postgres should never be exposed)
- [ ] `k8s/redis-service.yaml`: `ClusterIP`, port 6379, name `redis-service` (internal only)
- [ ] Config values referencing service DNS: `POSTGRES_HOST=db-service`, `REDIS_HOST=redis-service`

## Acceptance criteria
- All three services apply without errors
- `kubectl exec` into the app pod and successfully resolve `db-service` and `redis-service`
- Postgres and Redis are NOT reachable from outside the cluster (verify with `curl` from your host — should fail)

## Design note
Why not `NodePort`? Ingress is idiomatic in modern K8s and mirrors what you'd use on EKS with an ALB Ingress Controller.
EOF
)"

create_issue \
  "ConfigMap + Secret for configuration" \
  "type:story,epic:k8s,area:infra,priority:high" \
  "$(cat <<'EOF'
## Description
Split config from code and non-secret from secret. Wire it into the app Deployment via `envFrom`.

## Tasks
- [ ] `k8s/configmap.yaml` — `app-config`:
  ```yaml
  POSTGRES_HOST: db-service
  POSTGRES_USER: appuser
  POSTGRES_DB: urlshortener
  REDIS_HOST: redis-service
  REDIS_PORT: "6379"
  LOG_LEVEL: info
  CACHE_TTL_SECONDS: "3600"
  ```
- [ ] `k8s/secret.yaml` — `app-secrets` with base64-encoded `POSTGRES_PASSWORD`
- [ ] `k8s/secret.example.yaml` committed (template); `k8s/secret.yaml` git-ignored
- [ ] Reference both in `app-deployment.yaml` via `envFrom`
- [ ] Reference the Secret in `db-deployment.yaml` for Postgres password

## Acceptance criteria
- App deployment picks up env from both ConfigMap and Secret
- `kubectl exec` into app pod, verify env vars are present
- `k8s/secret.yaml` is in `.gitignore` and NOT committed
- `k8s/secret.example.yaml` shows the shape without real values

## Learning note
K8s Secrets are base64-encoded, not encrypted at rest by default. In Epic 6 we'll note the upgrade path (SOPS, sealed-secrets, or AWS Secrets Manager via the External Secrets Operator).
EOF
)"

create_issue \
  "Ingress + HorizontalPodAutoscaler" \
  "type:story,epic:k8s,area:infra,priority:medium" \
  "$(cat <<'EOF'
## Description
Expose the app via nginx-ingress (minikube's ingress addon) and add an HPA so replicas scale with CPU load.

## Tasks
- [ ] `k8s/ingress.yaml`:
  - `ingressClassName: nginx`
  - Host: `url-shortener.local` (add to `/etc/hosts` pointing at `minikube ip`)
  - Route `/` → `app-service:80`
- [ ] `k8s/hpa.yaml`:
  - Target: `app` deployment
  - `minReplicas: 2`, `maxReplicas: 5`
  - Metric: CPU utilisation, target 70%
- [ ] Load-test recipe in the story (using `hey` or `ab`) that reliably triggers scale-up
- [ ] Verify with `kubectl get hpa` and `kubectl get pods` during load

## Acceptance criteria
- `curl http://url-shortener.local/health` returns 200
- Under sustained load, `kubectl get hpa` shows utilisation climb and replicas scale from 2 to 3+
- After load stops, replicas scale back down (may take several minutes — HPA has stabilisation windows)
- Ingress and HPA manifests committed

## Depends on
- All previous Epic 5 stories
EOF
)"

# ==================== EPIC 6: Terraform =====================================

create_issue \
  "Terraform bootstrap + ECR repository as code" \
  "type:story,epic:terraform,area:infra,priority:high" \
  "$(cat <<'EOF'
## Description
Set up Terraform with the AWS provider and provision the ECR repository as code (replacing any console-created one from the original plan).

## Tasks
- [ ] Install Terraform (document version in README, e.g. 1.7+)
- [ ] `terraform/` directory: `main.tf`, `providers.tf`, `variables.tf`, `outputs.tf`
- [ ] Provider config: AWS, region from variable
- [ ] Backend: local state for learning (`terraform.tfstate` in `.gitignore`)
- [ ] Comment: production would use an S3 backend + DynamoDB lock table; show the config snippet
- [ ] Resource: `aws_ecr_repository` named `url-shortener`, image scanning on push
- [ ] Output: `ecr_repository_url`
- [ ] `terraform init && terraform plan && terraform apply`
- [ ] Verify in AWS console; then `terraform destroy` and re-apply to prove idempotency

## Acceptance criteria
- `terraform apply` provisions the ECR repo
- `terraform.tfstate` is git-ignored
- `terraform destroy` cleanly removes everything
- README documents the S3-backend upgrade path

## Learning note
Local state is fine for a solo learning project. On any team, remote state + locking is non-negotiable.
EOF
)"

create_issue \
  "IAM user + least-privilege policy for CI/CD (Terraform)" \
  "type:story,epic:terraform,area:infra,priority:high" \
  "$(cat <<'EOF'
## Description
Create the IAM user that GitHub Actions will use to push to ECR — but as code, and with a minimal policy.

## Tasks
- [ ] `terraform/iam.tf`:
  - `aws_iam_user "ci_ecr_pusher"`
  - `aws_iam_policy` with actions limited to `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:BatchGetImage`
  - Scope the policy to the specific ECR repo ARN, not `*`
  - `aws_iam_user_policy_attachment`
- [ ] `aws_iam_access_key` resource with `lifecycle { ignore_changes = [status] }`
- [ ] Sensitive outputs: `access_key_id` and `secret_access_key` (marked `sensitive = true`)
- [ ] Instructions: `terraform output -raw ci_access_key_secret` to retrieve for GitHub Secrets

## Acceptance criteria
- IAM user + policy visible in AWS console
- Policy is scoped to the single ECR repo (not `*`)
- Access key can be retrieved from Terraform output
- Policy JSON committed and readable

## Learning note
For production, use GitHub Actions OIDC federation instead of static access keys — no long-lived credentials. Note this in the code comments and the ARCHITECTURE.md.
EOF
)"

create_issue \
  "CloudWatch log group + retention policy (Terraform)" \
  "type:story,epic:terraform,area:infra,priority:medium" \
  "$(cat <<'EOF'
## Description
Provision the CloudWatch log group that Epic 7 will ship logs into. Retention policy is the whole point — default CloudWatch retention is "forever", which burns money.

## Tasks
- [ ] `terraform/logs.tf`:
  - `aws_cloudwatch_log_group "app"` named `/url-shortener/app`
  - `retention_in_days = 14` (with a comment explaining the trade-off: cost vs debugging)
- [ ] Output the log group ARN

## Acceptance criteria
- Log group exists in AWS console after `terraform apply`
- Retention is 14 days, not "Never expire"
- Log group ARN is a Terraform output

## Learning note
The default retention "Never expire" is one of the most common AWS cost surprises. Always set it explicitly, and make it a small number for anything below production.
EOF
)"

# ==================== EPIC 7: Observability =================================

create_issue \
  "Structured logging with pino" \
  "type:story,epic:observability,area:backend,priority:medium" \
  "$(cat <<'EOF'
## Description
Replace every `console.log` with a structured pino logger. This is the single-most-impactful observability upgrade for any Node app.

## Tasks
- [ ] `npm install pino pino-http`
- [ ] `src/logger.ts` — configured pino instance, level from `LOG_LEVEL` env var
- [ ] `pino-http` middleware in Express — attaches a logger to every request with a request ID
- [ ] Replace all `console.log` / `console.error` in the codebase
- [ ] Ensure logs are single-line JSON in production; pino-pretty only in dev

## Acceptance criteria
- Every log line in production mode is valid JSON with `level`, `time`, `msg`
- Request logs include a unique request ID
- `LOG_LEVEL=debug` shows debug logs; `LOG_LEVEL=info` hides them
- No `console.*` calls remain in `src/` (verify with a grep in CI, optionally)
EOF
)"

create_issue \
  "Prometheus /metrics endpoint" \
  "type:story,epic:observability,area:backend,priority:medium" \
  "$(cat <<'EOF'
## Description
Expose a Prometheus-format metrics endpoint with both default Node metrics and custom application counters.

## Tasks
- [ ] `npm install prom-client`
- [ ] `src/metrics.ts` — Registry with default metrics (memory, CPU, event loop lag)
- [ ] Custom counters:
  - `urls_created_total` — increments on successful `POST /shorten`
  - `redirects_served_total{cache="hit|miss"}` — increments on `GET /:code`
  - `rate_limit_rejections_total{endpoint}` — increments on 429s
- [ ] `GET /metrics` endpoint returning Prometheus text format
- [ ] `/metrics` should NOT be rate-limited but SHOULD be considered internal (add a code comment about IP restriction / auth in production)

## Acceptance criteria
- `curl /metrics` returns valid Prometheus text format
- Custom counters increment during normal use (verify by hitting endpoints then re-checking `/metrics`)
- Default Node.js metrics present (event loop lag etc.)
- Documented note about protecting `/metrics` in production
EOF
)"

create_issue \
  "Ship container logs to CloudWatch" \
  "type:story,epic:observability,area:devops,priority:medium" \
  "$(cat <<'EOF'
## Description
Get logs off the pod and into the CloudWatch log group provisioned in Epic 6.

## Tasks
- [ ] Add a `winston-cloudwatch` or `pino-cloudwatch` transport for direct-to-CloudWatch shipping (simplest for a learning project)
- [ ] Configure via env vars: `CLOUDWATCH_LOG_GROUP`, `CLOUDWATCH_REGION`, disabled by default in dev
- [ ] Use AWS SDK v3 with the IAM permissions granted via the CI user or a scoped runtime role (document the trade-off)
- [ ] Verify by running the container with credentials and checking the log group in the AWS console

## Acceptance criteria
- With CloudWatch env vars set, logs appear in the log group within ~1 minute of being emitted
- With CloudWatch env vars unset, the app runs normally with stdout-only logging
- No AWS credentials committed to the repo

## Learning note
The "proper" K8s way is a Fluent Bit DaemonSet reading from the node's `/var/log/containers/`. The app-side approach here is simpler and teaches the AWS SDK — noted trade-off in ARCHITECTURE.md.
EOF
)"

# ==================== EPIC 8: CI/CD ========================================

create_issue \
  "GitHub Actions: lint + test on PR" \
  "type:story,epic:cicd,area:devops,priority:high" \
  "$(cat <<'EOF'
## Description
Establish the base CI pipeline. Every PR runs lint, typecheck, and the full test suite before merge.

## Tasks
- [ ] `.github/workflows/ci.yml` triggered on `pull_request` and `push` to any branch
- [ ] Steps:
  1. `actions/checkout@v4`
  2. `actions/setup-node@v4` with Node 20
  3. Cache `node_modules` via `actions/setup-node` caching
  4. `npm ci`
  5. `npm run lint` (ESLint)
  6. `npm run typecheck` (`tsc --noEmit`)
  7. `npm test` (Jest — including integration if Docker is available on the runner)
- [ ] Add branch protection rule requiring this workflow to pass before merge

## Acceptance criteria
- Every PR triggers the workflow
- All steps run and results reported in the PR
- Merge blocked if CI fails
- Total CI time under 3 minutes
EOF
)"

create_issue \
  "Container image scanning with Trivy" \
  "type:story,epic:cicd,area:devops,priority:medium" \
  "$(cat <<'EOF'
## Description
Add a Trivy scan step to the CI pipeline. Fail the build on HIGH or CRITICAL vulnerabilities, and upload SARIF to the GitHub Security tab.

## Tasks
- [ ] Extend `ci.yml` (or a new `security.yml`) with:
  1. Build the Docker image
  2. Run `aquasecurity/trivy-action@master` with `severity: HIGH,CRITICAL`, `exit-code: 1`
  3. Upload SARIF results via `github/codeql-action/upload-sarif@v3`
- [ ] Ignore file `.trivyignore` for known false-positives (document each with a comment)
- [ ] Runs on every PR and every push to main

## Acceptance criteria
- Trivy scan appears in the workflow run
- HIGH/CRITICAL CVEs fail the build
- SARIF results visible under Security → Code scanning alerts
- README explains the security scanning gate
EOF
)"

create_issue \
  "Push image to ECR on merge to main" \
  "type:story,epic:cicd,area:devops,priority:high" \
  "$(cat <<'EOF'
## Description
The main deployment pipeline: on merge to main, authenticate to AWS, build the image, tag it with the commit SHA and `latest`, and push both to ECR.

## Tasks
- [ ] `.github/workflows/deploy.yml` triggered on `push` to `main`
- [ ] Steps:
  1. `actions/checkout@v4`
  2. `aws-actions/configure-aws-credentials@v4` using `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` from GitHub Secrets
  3. `aws-actions/amazon-ecr-login@v2`
  4. `docker build` with two tags: `${{ github.sha }}` and `latest`
  5. `docker push` both tags
- [ ] Store secrets in GitHub: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `ECR_REPOSITORY` (the URI from Terraform output)
- [ ] Never log the secrets (use `::add-mask::` if necessary)

## Acceptance criteria
- Merge to main triggers the workflow
- Image appears in ECR tagged with the commit SHA and `latest`
- Workflow logs contain no credential values

## Learning note
Static access keys are fine for a learning project. The production upgrade is OIDC federation between GitHub Actions and AWS — no long-lived credentials in GitHub. Document this in ARCHITECTURE.md.
EOF
)"

create_issue \
  "Kubectl deploy step (manual for minikube, EKS path documented)" \
  "type:story,epic:cicd,area:devops,priority:medium" \
  "$(cat <<'EOF'
## Description
Close the CI/CD loop by documenting how the freshly-pushed ECR image reaches a cluster. For local minikube this is a manual `kubectl set image` command; for EKS it's an additional workflow step. Both should be spelled out.

## Tasks
- [ ] Add a section to the README titled "Deploying an updated image":
  - **Local minikube**: `kubectl set image deployment/app app=<ecr-uri>:<sha>` (or re-tag `url-shortener:local` and restart)
  - **EKS (production path)**: sample workflow step using `aws eks update-kubeconfig` + `kubectl set image`
- [ ] Optional: add the EKS deploy step to `deploy.yml` as a `commented-out` block so the shape is visible
- [ ] Document the rolling-update behaviour: `maxUnavailable: 0` from Epic 5 = zero-downtime

## Acceptance criteria
- README section exists with both minikube and EKS commands
- The EKS path is present in the workflow file (commented) so the shape is discoverable
- Rolling-update behaviour explained with the manifest reference
EOF
)"

# ==================== EPIC 9: Documentation =================================

create_issue \
  "Comprehensive README with architecture diagram" \
  "type:story,epic:docs,area:docs,priority:high" \
  "$(cat <<'EOF'
## Description
The README is the single most important file in the repo for portfolio purposes. Structure it so a reader can understand the project in 90 seconds and reproduce it in 15 minutes.

## Tasks
- [ ] Sections:
  1. **What it is** — 2-3 sentences
  2. **Architecture diagram** — Mermaid preferred (renders on GitHub) with app, Postgres, Redis, ECR, GitHub Actions, CloudWatch
  3. **Tech stack table** — Layer | Technology | Purpose
  4. **Local development** — `docker compose up` and endpoint verification
  5. **Kubernetes deployment** — the exact `kubectl apply` order
  6. **CI/CD pipeline** — pipeline diagram + description
  7. **AWS setup** — `terraform apply` + GitHub Secrets
  8. **What I learned** — concise, honest, non-marketing

## Acceptance criteria
- Renders cleanly on GitHub (Mermaid diagram visible)
- Someone can go from clone to running local stack using only the README
- All commands copy-pasteable
- No broken links
EOF
)"

create_issue \
  "ARCHITECTURE.md — decisions and trade-offs" \
  "type:story,epic:docs,area:docs,priority:high" \
  "$(cat <<'EOF'
## Description
Interview-grade documentation of *why* each significant technical choice was made — not just what.

## Tasks
- [ ] `docs/ARCHITECTURE.md` covering at minimum:
  - **nanoid vs base62 counter** — collision math, why nanoid for this project, when the counter approach wins
  - **Cache-aside vs write-through** — read-heavy workload rationale
  - **minikube vs EKS** — the $72/month decision, and why every manifest is EKS-ready
  - **Deployment vs StatefulSet for Postgres** — learning trade-off, prod would use RDS
  - **Static IAM keys vs OIDC** — what we do now, what production does
  - **K8s Secrets vs AWS Secrets Manager** — same trade-off note
  - **Local Terraform state vs S3 backend** — same
- [ ] Each entry: 1 paragraph decision, 1 paragraph trade-off, 1 line "how to upgrade"

## Acceptance criteria
- File exists and is linked from README
- At least 6 decisions documented
- Every decision has an "upgrade path" line
EOF
)"

create_issue \
  "SYSTEM-DESIGN.md — URL shortener as a case study" \
  "type:story,epic:docs,area:docs,priority:medium" \
  "$(cat <<'EOF'
## Description
Turn this project into a system-design talking piece. Most senior interviews will ask "walk me through a project" or "design a URL shortener" — this document is the script.

## Tasks
- [ ] `docs/SYSTEM-DESIGN.md` covering:
  - **Scale assumptions** — reads/writes per day at 1×, 10×, 100× current
  - **Storage estimates** — bytes per record × records = DB size at each scale
  - **Read:write ratio** — why the cache is worthwhile (typical ~100:1 in URL shorteners)
  - **Cache hit-rate target** — what to aim for and why
  - **What breaks at each scale** — DB writes, connection pool, single Redis node, Ingress throughput
  - **The upgrade path** — Aurora / RDS Proxy → read replicas → Redis Cluster → CDN in front of redirects
- [ ] Link from the README

## Acceptance criteria
- File exists and is linked from README
- Each scale tier (1×, 10×, 100×) has explicit numbers, not hand-waving
- At least one specific bottleneck identified per scale tier

## Why this matters
This turns the project from "I built a URL shortener with Docker and Kubernetes" into "I built a URL shortener, and here's exactly how I'd scale it to 100M requests/day" — which is a completely different interview conversation.
EOF
)"

echo ""
echo "=============================================="
echo "  Done. Created $(wc -l < .issues-created.log) issues."
echo "  URLs logged to: .issues-created.log"
echo "=============================================="
