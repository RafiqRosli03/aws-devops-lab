# Phase 1 — Applications + Docker

**Goal:** build two small microservices and containerize each properly. Local only,
no AWS, zero cost. The two different language stacks exist to prove the later pipeline
is language-agnostic.

## What was built

### App A — orders-node (Node.js + Express)
- `GET /health` → `{"status":"ok"}` (used by K8s probes later)
- `GET /orders` → list orders (in-memory)
- `POST /orders` → create an order (201, 400 on bad input)
- Static GUI served from `public/`
- Tests: `node --test` (built-in runner), `npm test`
- Port from `PORT` env var (default 3000)

### App B — users-python (Python + FastAPI)
- `GET /health`, `GET /users`, `POST /users` (Pydantic validation, 201/400)
- Static GUI + FastAPI auto-docs at `/docs`
- Tests: `pytest` with FastAPI `TestClient`
- Port from `PORT` env var (default 8000)

## Containerization

Both use **multi-stage, non-root** Dockerfiles:

- **orders-node:** build stage installs deps + runs tests (fail fast); runtime stage
  copies only prod `node_modules` + `src` onto `node:20-slim`, runs as the built-in
  `node` user (UID 1000).
- **users-python:** build stage installs deps into an isolated prefix; runtime stage
  copies them onto `python:3.12-slim`, creates and runs as `appuser` (UID 1000).

Both verified to run under hardened constraints (read-only root FS, non-root, tmpfs
`/tmp`) — important for the Phase 4 Pod Security Admission `restricted` profile.

`docker-compose.yml` runs both locally:
```bash
docker compose up --build
curl localhost:3000/health   # orders
curl localhost:8000/health   # users
```

## Layout

```
apps/
  orders-node/   src/ tests/ public/ Dockerfile package.json
  users-python/  app/ tests/ pyproject.toml Dockerfile requirements.txt
docker-compose.yml
```

## Definition of Done — met
- [x] Both apps implemented with passing unit tests
- [x] Multi-stage, non-root Dockerfile per app
- [x] `docker compose up` runs both; both `/health` return ok
- [x] Committed to Git with clean history

## Notes / gotchas
- `pyproject.toml` with `[tool.pytest.ini_options] pythonpath=["."]` was added so
  `from app.main import app` resolves in a clean CI container (discovered in Phase 3).
