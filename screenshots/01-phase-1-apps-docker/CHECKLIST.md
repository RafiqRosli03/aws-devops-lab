# 01 — Phase 1: Applications and Docker

- [x] `P1-01-orders-browser-gui.png` — Orders app in browser. _(have: GUI APP.png)_
- [x] `P1-02-orders-api-response.png` — `/orders` JSON response. _(have: API APP.png)_
- [ ] `P1-03-users-browser-gui.png` — Users app in browser. _(not clearly captured — only one GUI shot)_
- [ ] `P1-04-users-api-response.png` — `/users` JSON response. _(not clearly captured — only one API shot)_
- [x] `P1-05-fastapi-swagger-docs.png` — Users `/docs` Swagger UI. _(have: FastAPI Swagger Documentation.png)_
- [x] `P1-06-health-endpoints-200.png` — Successful health/API requests. _(have: health-check app.png)_
- [x] `P1-07-node-tests-passed.png` — `npm test` passing. _(have: node-test-pass.png)_
- [x] `P1-08-python-pytest-passed.png` — `pytest` showing all tests passed. _(have: python test.png)_
- [x] `P1-09-docker-images.png` — Both local images with tags/sizes. _(have: Docker Image.png)_
- [x] `P1-10-docker-compose-services.png` — `docker compose ps`, both services running. _(have: Docker Compose Services.png)_
- [x] `P1-11-containers-non-root.png` — Container `id` showing non-root UID. _(have: Non-root container proof.png; also Docker Harden test.png)_
- [x] `P1-12-multistage-dockerfiles.png` — Both Dockerfiles showing build/runtime stages and `USER`. _(have: Multi-stage Dockerfiles.png)_

## Useful commands

```powershell
Set-Location "app\apps\orders-node"
npm test

Set-Location "..\users-python"
docker run --rm -v "${PWD}:/work" -w /work python:3.12 sh -c "pip install -q -r requirements.txt && pytest"

Set-Location "..\.."
docker compose up -d --build
docker compose ps
```
