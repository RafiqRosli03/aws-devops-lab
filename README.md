# AWS DevOps Lab — End-to-End Project

A hands-on, end-to-end DevOps lab on AWS covering the four core pillars:
**CI/CD, Containers & Orchestration, Infrastructure as Code, and Cloud.**

Two small microservices (Node.js + Python) are driven through one identical DevOps
workflow, proving the pipeline is language-agnostic. The apps are intentionally
simple — the value is the pipeline, the containers, the infra-as-code, and the AWS
wiring around them.

> Status: work in progress. Built phase by phase; each phase is demonstrable on its own.

## Architecture

![High-level architecture: developer pushes to GitLab CI, which authenticates to AWS via OIDC, builds and pushes images to ECR, and deploys to an EKS cluster inside a VPC with public and private subnets. Terraform provisions all infrastructure. CloudWatch, GuardDuty, and Security Hub provide observability and security.](planning/architecture.png)

The full editable source is [`planning/03-hld-architecture.drawio`](planning/03-hld-architecture.drawio) (open with [draw.io](https://draw.io)).

---

## The two applications

| App | Stack | Role | Endpoints |
|-----|-------|------|-----------|
| `app/apps/orders-node` | Node.js + Express | "orders" REST API | `GET /health`, `GET /orders`, `POST /orders` |
| `app/apps/users-python` | Python + FastAPI | "users" REST API | `GET /health`, `GET /users`, `POST /users` |

## Tech stack

| Area | Choice |
|------|--------|
| Orchestrator | Amazon EKS (Kubernetes) |
| CI/CD | GitLab CI (OIDC to AWS — no static keys) |
| Registry | Amazon ECR (one repo per app) |
| IaC | Terraform (remote state in S3, native state locking) |
| Region | ap-southeast-5 |
| Extras | KMS, Secrets Manager, CloudWatch, GuardDuty, Security Hub |

## High-level flow

```
Developer git push
      |
      v
GitLab CI pipeline  (lint -> test -> build -> push image -> deploy)
      |  authenticates to AWS via OIDC (no long-lived keys)
      v
Amazon ECR (images)  -->  Amazon EKS (app pods)  <--  Terraform builds all infra
      |
      v
App running on EKS behind an ALB Ingress
      |
CloudWatch + GuardDuty + Security Hub watch the account
```

---

## Low-level flow (what actually happens, step by step)

The high-level flow above is the story in one breath. This section unpacks it into the
exact steps — useful if you want to understand *how* a `git push` becomes a running,
hardened app, and *how* a user's request reaches it. There are two journeys: the
**delivery flow** (code → running pod) and the **request flow** (user → response).

### A. Delivery flow — from `git push` to a live pod

```
┌─ 1. DEVELOPER ────────────────────────────────────────────────────────────┐
│  git push to the GitLab project (main branch or a merge request).          │
│  GitLab reads .gitlab-ci.yml and decides which jobs run using path rules:  │
│     apps/**  changed  ->  application pipeline (below)                      │
│     infra/** changed  ->  Terraform pipeline (validate -> plan -> apply)    │
└────────────────────────────────────────────────────────────────────────────┘
                                   |
                                   v
┌─ 2. TEST (gate #1 — quality) ──────────────────────────────────────────────┐
│  Only the changed app runs:                                                 │
│    orders-node  ->  npm ci + npm test   (Node test runner)                  │
│    users-python ->  pip install + pytest                                    │
│  If a test fails, the pipeline STOPS here. No image is ever built.          │
└────────────────────────────────────────────────────────────────────────────┘
                                   |
                                   v
┌─ 3. AUTHENTICATE to AWS (no static keys) ──────────────────────────────────┐
│  GitLab mints a short-lived OIDC ID token (audience sts.amazonaws.com).     │
│  The ecr-login job runs on an image that HAS the AWS CLI and calls          │
│    aws sts assume-role-with-web-identity  -> devops-lab-dev-gitlab-deploy   │
│  AWS checks the token's "sub" claim is this exact GitLab project, then      │
│  returns temporary credentials that expire when the job ends.               │
│  It fetches an ECR login token and hands it to the build job as a           │
│  short-lived Docker-auth artifact.                                          │
└────────────────────────────────────────────────────────────────────────────┘
                                   |
                                   v
┌─ 4. BUILD + PUSH the image ────────────────────────────────────────────────┐
│  Kaniko builds the Docker image WITHOUT a privileged Docker daemon          │
│  (rootless, safe for CI). It reads the multi-stage Dockerfile:              │
│     stage 1: install deps + run tests   stage 2: slim, non-root runtime     │
│  The image is tagged with the git SHA (immutable) and pushed to ECR:        │
│     497862079645.dkr.ecr.ap-southeast-5.amazonaws.com/orders-node:<SHA>     │
│  Immutable SHA tags mean every deploy maps to an exact commit = easy rollback│
└────────────────────────────────────────────────────────────────────────────┘
                                   |
                                   v
┌─ 5. DEPLOY to EKS (dev namespace, automatic) ──────────────────────────────┐
│  The deploy job assumes the deploy role again, downloads kubectl, and runs  │
│     aws eks update-kubeconfig --name devops-lab-dev                         │
│  Two authorization doors must both open:                                    │
│     (1) AWS IAM — may this role talk to EKS?                                │
│     (2) EKS access entry — may this identity act INSIDE the cluster?        │
│  It applies k8s/base with Kustomize, then sets the Deployment's image to    │
│  the new SHA and runs:                                                       │
│     kubectl rollout status ... --timeout=180s                               │
│  A green job is NOT enough — rollout status waits until the NEW pods are    │
│  actually Ready before the job passes.                                       │
└────────────────────────────────────────────────────────────────────────────┘
                                   |
                                   v
┌─ 6. PROMOTE to prod (gate #2 — manual) ────────────────────────────────────┐
│  The prod job is "when: manual" — it waits for a human to click. The SAME   │
│  tested SHA image is promoted (never rebuilt), so prod runs exactly what    │
│  dev validated.                                                              │
└────────────────────────────────────────────────────────────────────────────┘
```

### B. Request flow — from a user's browser to a response

```
Internet user requests  http://<ALB-DNS>/orders
      |
      v
(1) ALB (Application Load Balancer) receives it in a PUBLIC subnet.
      |   The ALB was created by the AWS Load Balancer Controller reading the
      |   Kubernetes Ingress (IRSA-scoped, least-privilege IAM — not node-wide).
      v
(2) Ingress path rules route the request:
        /orders*  ->  orders-node Service        /users*  ->  users-python Service
      |
      v
(3) Service (ClusterIP) load-balances to a healthy Pod on an EKS worker node
      |   in a PRIVATE subnet. Only pods passing the readiness probe get traffic.
      v
(4) Pod runs the container: non-root, read-only root FS, all Linux caps dropped,
      |   seccomp RuntimeDefault. A NetworkPolicy default-denies everything except
      |   the traffic explicitly allowed (DNS + the app port).
      v
(5) The app (Express or FastAPI) handles the request and returns JSON.
      |
      v
(6) Response travels back out through the ALB to the user.
            Meanwhile: logs (stdout) + metrics stream to CloudWatch.
```

### What keeps it healthy and safe (always running in the background)

| Concern | Mechanism | What it does |
|---------|-----------|--------------|
| Pod crashes | Deployment (replicas ≥ 2) | Kubernetes recreates the pod automatically |
| Pod alive but not ready | Readiness probe on `/health` | Pulls the pod out of Service traffic until healthy |
| Pod hung | Liveness probe on `/health` | Restarts the container |
| Traffic spike | HPA (2–5 pods, ~60% CPU target) | Scales pods up, then back down when idle |
| Bad deploy | Immutable SHA tags | Redeploy a known-good previous SHA to roll back |
| 5xx errors | CloudWatch alarm → SNS | ALB 5xx breaches threshold → email notification |
| Root/unsafe pod | Pod Security Admission (`restricted`) | Rejects the pod at admission time |
| Unexpected traffic | NetworkPolicy (default-deny) | Blocks anything not explicitly allowed |
| Account threats | GuardDuty + Security Hub | Detect suspicious activity, aggregate findings |

> For an even gentler, analogy-driven walkthrough of all of this, see
> [`planning/04-beginner-end-to-end-explanation.md`](planning/04-beginner-end-to-end-explanation.md).

---

## Repository layout

```
.
├── README.md                 <- you are here (project front page)
├── planning/                 <- all planning + design docs (Markdown, numbered in reading order)
│   ├── 00-MASTER-PLAN.md               high-level overview
│   ├── 01-project-plan.md              planning notes + locked decisions
│   ├── 02-phase-plan.md                condensed single-page phase plan
│   ├── 03-hld-architecture.drawio      high-level design diagram
│   ├── 04-beginner-end-to-end-explanation.md  plain-language walkthrough
│   └── 05-PHASE-1.md ... 10-PHASE-5.md per-phase detailed plans (incl. 07-PHASE-2.5.md)
├── app/                      <- the actual project
│   ├── apps/                      orders-node (Express) + users-python (FastAPI)
│   ├── infra/                     Terraform: bootstrap, modules, envs/dev
│   ├── k8s/                       Kubernetes manifests (base kustomization)
│   ├── docs/                      per-phase build docs + runbook
│   ├── docker-compose.yml         run both apps locally
│   └── .gitlab-ci.yml             CI/CD pipeline
└── screenshots/              <- evidence captures per phase
```

---

## The 5 phases

| Phase | Focus | Outcome |
|-------|-------|---------|
| 1 | Apps + Docker | Both apps containerized (multi-stage, non-root), run locally with `docker compose` |
| 2 | Terraform / IaC | VPC, ECR, EKS, IAM/OIDC, KMS, Secrets Manager — all from code |
| 2.5 | Terraform pipeline | Terraform itself behind GitLab CI: validate → plan → gated apply, on its own OIDC role |
| 3 | App CI/CD (GitLab) | Every push builds, tests, pushes to ECR, deploys to EKS; dev→prod gate |
| 4 | Kubernetes hardening | RBAC, network policies, non-root pods, secrets, HPA, ALB Ingress |
| 5 | Observability & posture | CloudWatch logs/metrics/alarm, GuardDuty + Security Hub |

> Code is hosted on **GitHub** (portfolio mirror) and the CI/CD pipeline targets
> **GitLab CI** (OIDC to AWS). See [`planning/00-MASTER-PLAN.md`](planning/00-MASTER-PLAN.md) for why both.

Planning docs are numbered `00`–`10` in reading order inside `planning/`.

Full detail for each phase lives in `planning/` and the build notes in `app/docs/`.

## Quick start (Phase 1 — local, zero cost)

```bash
cd app
docker compose up --build
# then, in another terminal:
curl http://localhost:3000/health   # orders-node
curl http://localhost:8000/health   # users-python
```

FastAPI auto docs: http://localhost:8000/docs

---

## Cost reminder

EKS control plane (~$0.10/hr) + worker nodes + NAT + ALB cost money while running.
Run `terraform apply` at the start of a session and `terraform destroy` at the end.
Never leave the cluster running overnight for a lab.
