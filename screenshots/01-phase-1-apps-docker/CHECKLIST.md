# 01 — Phase 1: Applications and Docker

- [ ] `P1-01-orders-browser-gui.png` — Orders app in browser.
- [ ] `P1-02-orders-api-response.png` — `/orders` JSON response.
- [ ] `P1-03-users-browser-gui.png` — Users app in browser.
- [ ] `P1-04-users-api-response.png` — `/users` JSON response.
- [ ] `P1-05-fastapi-swagger-docs.png` — Users `/docs` Swagger UI.
- [ ] `P1-06-health-endpoints-200.png` — Successful health/API requests.
- [ ] `P1-07-node-tests-passed.png` — `npm test` passing.
- [ ] `P1-08-python-pytest-passed.png` — `pytest` showing all tests passed.
- [ ] `P1-09-docker-images.png` — Both local images with tags/sizes.
- [ ] `P1-10-docker-compose-services.png` — `docker compose ps`, both services running.
- [ ] `P1-11-containers-non-root.png` — Container `id` showing non-root UID.
- [ ] `P1-12-multistage-dockerfiles.png` — Both Dockerfiles showing build/runtime stages and `USER`.

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
