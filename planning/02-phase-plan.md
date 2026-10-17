# DevOps Project — 5-Phase Plan (Two Apps: Node + Python)

Detailed, phase-by-phase plan. We build **two microservices** so the project mirrors
a real multi-language platform:

- **App A — Node.js** (Express REST API) — e.g. a simple "orders" API.
- **App B — Python** (FastAPI REST API) — e.g. a simple "users" API.

Both are deliberately small. The value is in the pipeline, containers, IaC, and AWS
wiring around them — and in proving the same DevOps workflow handles two different
language stacks.

Defaults used (change if needed): **EKS**, **GitLab CI**, **Amazon ECR**,
**Terraform**, region **ap-southeast-5**.

Legend: [DoD] = Definition of Done (how you know the phase is finished).

---

## Phase 1 — Two Applications + Docker

**Objective:** Build both apps and containerize each one properly. End the phase able
to run both locally with a single `docker run` (or `docker compose up`).

### What we do
1. **App A (Node.js / Express)**
   - Minimal REST API: `GET /health`, `GET /orders`, `POST /orders` (in-memory data).
   - Add unit tests (Jest or node:test).
   - Write a **multi-stage Dockerfile**:
     - Stage 1 (build): install deps, run tests/build.
     - Stage 2 (runtime): copy only what's needed onto a slim/distroless Node base.
     - Run as **non-root** user, `readOnlyRootFilesystem`-friendly, expose the app port.
2. **App B (Python / FastAPI)**
   - Minimal REST API: `GET /health`, `GET /users`, `POST /users` (in-memory data).
   - Add unit tests (pytest).
   - Write a **multi-stage Dockerfile**:
     - Stage 1 (build): install into a venv / wheels.
     - Stage 2 (runtime): copy venv onto a slim/distroless Python base.
     - Run as **non-root**, minimal packages, expose the app port.
3. **Local orchestration**
   - A `docker-compose.yml` to run both apps together for local testing.
4. **Repo layout** (monorepo):
   ```
   /apps
     /orders-node      (App A: src, tests, Dockerfile)
     /users-python     (App B: src, tests, Dockerfile)
   docker-compose.yml
   README.md
   ```

### DoD
- `docker build` succeeds for both apps and images are small (slim/distroless).
- Both containers run as non-root and respond on `/health`.
- `docker compose up` brings both apps up locally and you can hit both endpoints.
- Unit tests pass for both apps.

**Skills hit:** Docker (multi-stage, layers, registries-ready, best practices),
non-root/read-only container security basics, two-language build discipline.

---

## Phase 2 — Infrastructure as Code (Terraform)

**Objective:** Stand up the entire AWS environment from Terraform. No click-ops.

### What we do
1. **Terraform project structure**
   ```
   /infra
     /modules          (network, ecr, eks, iam-oidc, observability)
     /envs
       /dev            (dev.tfvars, backend config)
     main.tf, variables.tf, outputs.tf
   ```
2. **Remote state:** S3 bucket + DynamoDB lock table for Terraform state.
3. **Networking module:** VPC (10.0.0.0/16), public + private subnets across 2 AZs,
   Internet Gateway, NAT Gateway, route tables.
4. **ECR module:** one repository per app (`orders-node`, `users-python`).
5. **EKS module:** EKS control plane + a managed node group in the private subnets.
6. **IAM/OIDC module:** the GitLab OIDC provider + a deploy role GitLab CI can
   assume (foundation for Phase 3 — no static keys).
7. **KMS + Secrets Manager:** a KMS key and a couple of app secrets (placeholder).
8. Run **`terraform apply`** to build, capture outputs (cluster name, ECR URLs, role ARN).

### DoD
- `terraform apply` builds VPC + ECR + EKS + IAM/OIDC + KMS + Secrets cleanly.
- `terraform destroy` tears it all down with no orphaned resources.
- `kubectl get nodes` shows the EKS worker nodes Ready.
- Outputs give you everything Phase 3 needs (ECR URIs, cluster name, deploy role ARN).

**Skills hit:** Terraform (modules, state, apply/destroy), AWS VPC/networking, EKS,
IAM/OIDC, KMS, ECR — all as code.

---

## Phase 3 — CI/CD Pipeline (GitLab CI)

**Objective:** Every `git push` builds, tests, pushes images, and deploys both apps to
EKS automatically — with no long-lived AWS keys.

### What we do
1. **OIDC auth:** GitLab CI assumes the AWS deploy role via OIDC (from Phase 2).
2. **Pipeline — build & test stage (per app):**
   - Detect which app changed (path filters) so only what changed rebuilds.
   - Run lint + unit tests for Node and Python respectively.
   - Use dependency **caching** (npm cache, pip cache) to speed builds.
3. **Pipeline — package stage (per app):**
   - Build the Docker image, tag with the git SHA, push to the app's **ECR** repo.
   - Store the image tag as a pipeline **artifact/output**.
4. **Pipeline — deploy stage:**
   - `kubectl`/`helm` deploy each app to EKS using the new image tag.
   - **Environment promotion:** deploy to a `dev` namespace automatically; gate
     promotion to a `prod` namespace behind a manual approval (GitLab manual job / protected environment).
5. **Secrets in the pipeline:** pull app secrets from **AWS Secrets Manager** at deploy
   time; nothing hardcoded in the repo or workflow.

### DoD
- A push that changes only the Node app rebuilds/deploys only that app.
- Images land in ECR tagged by git SHA.
- Both apps deploy to the `dev` namespace automatically; `prod` requires approval.
- No AWS access keys exist anywhere in the repo or GitLab CI/CD variables (OIDC only).

**Skills hit:** CI/CD stages, artifacts, caching, environment promotion, gating,
secrets handling, OIDC to cloud — the heart of the project.

---

## Phase 4 — Kubernetes Hardening

**Objective:** Turn a working deployment into a hardened, production-shaped one.

### What we do
1. **Workload objects per app:** Deployment, Service (ClusterIP), and a shared
   **Ingress** (ALB Ingress Controller) routing `/orders` → Node app, `/users` →
   Python app.
2. **RBAC:** least-privilege service accounts per app; no cluster-admin for workloads.
3. **Network Policies:** default-deny, then explicitly allow only needed traffic
   (ingress from ALB, egress to what each app needs).
4. **Pod security:** non-root, `readOnlyRootFilesystem`, drop Linux capabilities,
   `runAsNonRoot`, resource requests/limits, liveness/readiness probes.
5. **Secrets:** mount app secrets from **Secrets Manager** (via the CSI driver or
   External Secrets), not Kubernetes plaintext Secrets.
6. **Autoscaling:** Horizontal Pod Autoscaler on CPU for at least one app.

### DoD
- Both apps reachable through the single ALB Ingress on their paths.
- A pod that tries to run as root or violates policy is rejected/failing by design.
- Network policy blocks traffic that isn't explicitly allowed (test it).
- No plaintext secrets in manifests; secrets come from Secrets Manager.
- HPA scales a deployment up under load and back down when idle.

**Skills hit:** Kubernetes deployments/services/ingress, RBAC, network policies,
secrets, security context, autoscaling.

---

## Phase 5 — Cloud Posture & Observability

**Objective:** See and secure the running platform. Logs, metrics, alerts, and
account-level security posture.

### What we do
1. **Logging:** ship app + cluster logs to **CloudWatch Logs** (Fluent Bit /
   Container Insights).
2. **Metrics + dashboards:** enable **Container Insights**; build one CloudWatch
   dashboard showing pod CPU/memory, ALB request count, and error rate. (Optionally
   Prometheus + Grafana as a stretch goal.)
3. **Alerting:** one CloudWatch alarm on a meaningful signal (e.g. 5xx error rate or
   pod restart spike) → SNS notification.
4. **Cloud security posture (CSPM):** enable **GuardDuty** and **Security Hub** in the
   region; review findings in a single pane. (Leverages your existing GuardDuty
   experience.)
5. **Cost hygiene:** confirm `terraform destroy` cleans everything; note the daily
   spin-up/tear-down habit for EKS.

### DoD
- App and cluster logs visible in CloudWatch.
- One dashboard shows live app/infra health.
- One alarm fires on a simulated bad event and notifies via SNS.
- GuardDuty + Security Hub enabled with findings aggregated.
- `terraform destroy` leaves no billable resources behind.

**Skills hit:** logging/metrics/tracing, security monitoring, CSPM concepts,
alerting, cost control.

---

## How the two apps flow through all phases

| Phase | App A (Node) | App B (Python) |
|-------|--------------|----------------|
| 1 Docker | Express API, Jest tests, multi-stage image | FastAPI, pytest, multi-stage image |
| 2 IaC | ECR repo `orders-node` | ECR repo `users-python` |
| 3 CI/CD | build/test/push/deploy via path filter | build/test/push/deploy via path filter |
| 4 K8s | Deployment + `/orders` ingress path | Deployment + `/users` ingress path |
| 5 Obs | logs/metrics/alarms | logs/metrics/alarms |

Building two different language stacks through one identical pipeline is the point —
it proves the DevOps workflow is language-agnostic, which is exactly what senior
reviewers look for.

---

## Suggested pace

- Phase 1: ~1 week (two apps + Docker).
- Phase 2: ~1–2 weeks (Terraform + EKS is the biggest learning curve).
- Phase 3: ~1–2 weeks (pipeline + OIDC).
- Phase 4: ~1 week (hardening).
- Phase 5: ~1 week (observability + posture).

Do them in order; each phase depends on the previous one. Stop after any phase and you
still have something demonstrable.

---

## Cost reminder

EKS control plane (~$0.10/hr) + node EC2 + NAT + ALB cost money while running.
`terraform apply` at the start of a session, `terraform destroy` at the end. Never
leave the cluster running overnight for a lab.
