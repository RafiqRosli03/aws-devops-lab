# Phase 1 — Two Applications + Docker

> **Environment:** Local only. No AWS. Zero cost.
> **Goal:** Build both apps and containerize each properly. End able to run both
> locally with `docker compose up`.

## Why this phase

Everything downstream (registry, pipeline, Kubernetes) needs a working, tested,
containerized app to carry. We build two — Node and Python — so the whole project
proves the DevOps workflow is language-agnostic.

## Step 1 — Repo layout (monorepo)

```text
devops-project/
  apps/
    orders-node/          (App A)
      src/
      tests/
      Dockerfile
      package.json
    users-python/         (App B)
      app/
      tests/
      Dockerfile
      requirements.txt
  docker-compose.yml
  README.md
  .gitignore
  .dockerignore
```

- Monorepo keeps both apps and shared config together; the pipeline later uses path
  filters so only the changed app rebuilds.
- `.gitignore`: `node_modules`, `__pycache__`, `.venv`, `*.env`, terraform state, etc.
- `.dockerignore`: keep build context small (no `node_modules`, no `.git`).

## Step 2 — App A: Node.js (Express) "orders" API

**Endpoints:**

| Method | Path | Returns |
|--------|------|---------|
| GET | `/health` | `{"status":"ok"}` |
| GET | `/orders` | list orders (in-memory array) |
| POST | `/orders` | add an order, return it |

**Tasks:**

- [ ] Init: `package.json` with Express + a test runner (Jest or built-in `node:test`).
- [ ] Implement the API in `src/` (keep routes and app separate for testability).
- [ ] Write unit tests in `tests/` (test `/health` and the orders endpoints).
- [ ] Add npm scripts: `start`, `test`.
- [ ] Read the listen port from an env var (`PORT`, default 3000).

**Good practices to bake in now:**

- No secrets in code; read config from env vars.
- Return proper status codes (201 on create, 400 on bad input).
- Log to stdout (containers capture stdout).

## Step 3 — App B: Python (FastAPI) "users" API

**Endpoints:**

| Method | Path | Returns |
|--------|------|---------|
| GET | `/health` | `{"status":"ok"}` |
| GET | `/users` | list users (in-memory list) |
| POST | `/users` | add a user, return it |

**Tasks:**

- [ ] `requirements.txt`: fastapi + uvicorn + pytest + httpx (for the test client).
- [ ] Implement the API in `app/` (FastAPI app object importable for tests).
- [ ] Write pytest tests in `tests/` (test `/health` and the users endpoints).
- [ ] Read the listen port from an env var (`PORT`, default 8000).

**Good practices:**

- Pydantic models for request validation (FastAPI gives this for free).
- Read config from env vars, no secrets in code.
- Log to stdout.

## Step 4 — Dockerfile: App A (Node, multi-stage, non-root)

Structure (concept, not final code):

```dockerfile
# Stage 1 - build
FROM node:20-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm test        # tests run at build time - fail fast

# Stage 2 - runtime
FROM node:20-slim AS runtime         # or gcr.io/distroless/nodejs20
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/src ./src
COPY --from=build /app/package.json ./
USER node                            # non-root
EXPOSE 3000
CMD ["node", "src/index.js"]
```

**Checklist:**

- [ ] Multi-stage (build stage + slim runtime stage).
- [ ] Runs as non-root (`USER node` or a created user).
- [ ] Small final image (slim or distroless base).
- [ ] `.dockerignore` excludes `node_modules`/`.git` from context.

## Step 5 — Dockerfile: App B (Python, multi-stage, non-root)

Structure (concept):

```dockerfile
# Stage 1 - build
FROM python:3.12-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2 - runtime
FROM python:3.12-slim AS runtime     # or a distroless python base
WORKDIR /app
COPY --from=build /install /usr/local
COPY app ./app
RUN useradd -m appuser
USER appuser                         # non-root
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Checklist:**

- [ ] Multi-stage (deps built separately from runtime).
- [ ] Runs as non-root.
- [ ] Small final image.
- [ ] No build tools left in the runtime image.

## Step 6 — Local orchestration (docker-compose)

`docker-compose.yml` runs both apps together:

```yaml
services:
  orders-node:
    build: ./apps/orders-node
    ports: ["3000:3000"]
  users-python:
    build: ./apps/users-python
    ports: ["8000:8000"]
```

**Tasks:**

- [ ] `docker compose build`
- [ ] `docker compose up`
- [ ] Hit both: `curl localhost:3000/health` and `curl localhost:8000/health`

## Step 7 — Verify

- [ ] `docker build` succeeds for **both** apps.
- [ ] Both final images are small (check: `docker images`).
- [ ] `docker run` shows each container runs as non-root (`docker exec ... whoami`).
- [ ] Both `/health` endpoints return ok.
- [ ] Unit tests pass for both apps.

## Definition of done — Phase 1

- [ ] Two apps (Node + Python) implemented with passing unit tests.
- [ ] A working multi-stage, non-root Dockerfile for each.
- [ ] `docker compose up` brings both up locally and both `/health` return ok.
- [ ] Repo committed to Git with clean history and a README.

**Skills hit:** Docker (multi-stage, layers, best practices), non-root/read-only
container security basics, two-language build discipline, Git hygiene.

**Next:** [PHASE-2.md](PHASE-2.md) — Terraform builds the AWS home for these images.
