# AWS DevOps Lab — End-to-End Project

A hands-on, end-to-end DevOps lab on AWS covering the four core pillars:
**CI/CD, Containers & Orchestration, Infrastructure as Code, and Cloud.**

Two small microservices (Node.js + Python) are driven through one identical DevOps
workflow, proving the pipeline is language-agnostic. The apps are intentionally
simple — the value is the pipeline, the containers, the infra-as-code, and the AWS
wiring around them.

> Status: work in progress. Built phase by phase; each phase is demonstrable on its own.

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
| IaC | Terraform (remote state in S3 + DynamoDB lock) |
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

## Repository layout

```
.
├── README.md                 <- you are here (project front page)
├── planning/                 <- all planning + design docs
│   ├── 00-MASTER-PLAN.txt         high-level overview
│   ├── 00-project-plan.md         planning notes + locked decisions
│   ├── 02-phase-plan.md           detailed 5-phase plan
│   ├── 01-hld-architecture.drawio high-level design diagram
│   ├── PHASE-1.txt ... PHASE-5.txt per-phase detailed plans
│   └── AWS-DEVOPS-LAB-BEGINNER-END-TO-END-EXPLANATION.md
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
| 3 | CI/CD (GitLab) | Every push builds, tests, pushes to ECR, deploys to EKS; dev→prod gate |
| 4 | Kubernetes hardening | RBAC, network policies, non-root pods, secrets, HPA, ALB Ingress |
| 5 | Observability & posture | CloudWatch logs/metrics/alarm, GuardDuty + Security Hub |

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
