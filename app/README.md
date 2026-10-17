# DevOps Project — Application Monorepo

Two small microservices used to drive the full DevOps workflow (see the plan files
in the parent folder). Phase 1 = local only, no AWS.

## Apps

| App | Stack | Port | Endpoints |
|-----|-------|------|-----------|
| `apps/orders-node` | Node.js + Express | 3000 | `GET /health`, `GET /orders`, `POST /orders` |
| `apps/users-python` | Python + FastAPI | 8000 | `GET /health`, `GET /users`, `POST /users` |

## Run locally (Docker)

```bash
docker compose up --build
# then:
curl http://localhost:3000/health
curl http://localhost:8000/health
curl http://localhost:3000/orders
curl http://localhost:8000/users
```

FastAPI also serves auto docs at http://localhost:8000/docs

## Run tests (without Docker)

Node:
```bash
cd apps/orders-node
npm install
npm test
```

Python:
```bash
cd apps/users-python
python -m venv .venv
. .venv/Scripts/activate   # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
pytest
```

## Container security baked in (Phase 1)
- Multi-stage builds (small runtime images)
- Non-root user in both images
- Tests run at build time (fail fast)
- `.dockerignore` keeps the build context minimal

## Next
Phase 2 (Terraform) creates ECR repos `orders-node` and `users-python` and the EKS
cluster these images deploy to. See `../planning/06-PHASE-2.md`.
