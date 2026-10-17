# DevOps Project — Master Plan (High-Level Overview)

## Purpose

One end-to-end DevOps lab project on AWS that covers the four core DevOps skills:
**CI/CD, Containers & Orchestration, Infrastructure as Code, and Cloud.** We build
two small microservices (Node.js + Python) and drive both through one identical
DevOps workflow, proving the pipeline is language-agnostic.

The apps are intentionally simple. The value is the pipeline, the containers, the
infra-as-code, and the AWS wiring around them.

## The two applications

| App | Stack | Role | Endpoints |
|-----|-------|------|-----------|
| App A | Node.js + Express | "orders" REST API | `GET /health`, `GET /orders`, `POST /orders` |
| App B | Python + FastAPI | "users" REST API | `GET /health`, `GET /users`, `POST /users` |

Both use in-memory data (no database — this is a lab).

## Tech stack / defaults

| Area | Choice |
|------|--------|
| Orchestrator | Amazon EKS (real Kubernetes) |
| CI/CD | GitLab CI (OIDC to AWS, no static keys) |
| Registry | Amazon ECR (one repo per app) |
| IaC | Terraform (remote state in S3, native S3 state locking) |
| Region | `ap-southeast-5` |
| Extras | KMS, Secrets Manager, CloudWatch, GuardDuty, Security Hub |

## Code hosting vs CI/CD — read this (avoids confusion)

Two different "git" platforms appear in this project, on purpose:

- **GitHub** — where this repository is published as a **portfolio mirror**
  (`github.com/RafiqRosli03/aws-devops-lab`). Browse the code here.
- **GitLab** — the **CI/CD engine** the pipeline is written for. The
  `.gitlab-ci.yml`, OIDC trust, and runners are GitLab-specific. To actually *run*
  the pipeline, the repo is pushed to a GitLab project and GitLab's OIDC provider is
  trusted by AWS IAM (see Phase 3).

**Why both:** GitLab CI was chosen to learn industry-standard, self-contained YAML
pipelines with OIDC-to-AWS. GitHub is the public showcase. They are not in conflict —
one hosts/shows the code, the other runs the delivery pipeline. Everywhere these docs
say "git push triggers the pipeline", that push is to the GitLab project.

> **Note on remote state locking:** the implementation uses S3 native state locking
> (no separate DynamoDB table). Older notes mentioning a DynamoDB lock table describe
> the classic approach; the native S3 lock is the newer equivalent.

## High-level flow

```text
Developer git push
      |
      v
GitLab CI pipeline (lint -> test -> build -> push image -> deploy)
      |  authenticates to AWS via OIDC (no long-lived keys)
      v
Amazon ECR (images)  --->  Amazon EKS (app pods)  <--- Terraform builds all infra
      |
      v
App running on EKS behind an ALB Ingress
      |
CloudWatch + GuardDuty + Security Hub watch the account
```

## The phases at a glance

| Phase | Title | Summary |
|-------|-------|---------|
| [1](PHASE-1.md) | Two Applications + Docker | Build both apps, unit tests, multi-stage non-root Dockerfiles, run locally with docker-compose. No AWS yet (local, zero cost). |
| [2](PHASE-2.md) | Infrastructure as Code (Terraform) | Stand up VPC, ECR, EKS, IAM/OIDC, KMS, Secrets Manager entirely from Terraform. `apply` builds it, `destroy` removes it. |
| [2.5](PHASE-2.5.md) | Separate Terraform CI/CD pipeline | Terraform itself behind GitLab CI: validate → plan → gated apply, on its own OIDC role. |
| [3](PHASE-3.md) | App CI/CD Pipeline (GitLab CI) | Every push builds/tests/pushes/deploys both apps. Path filters, caching, ECR tagging by git SHA, dev→prod promotion with a manual gate, OIDC auth. |
| [4](PHASE-4.md) | Kubernetes Hardening | Deployments/Services + shared ALB Ingress (`/orders`, `/users`), RBAC, network policies, non-root/read-only pods, secrets from Secrets Manager, HPA. |
| [5](PHASE-5.md) | Cloud Posture & Observability | CloudWatch logs/metrics/dashboard, alarm → SNS, GuardDuty + Security Hub, cost hygiene. Confirm full teardown. |

## How the two apps flow through all phases

| Phase | App A (Node) | App B (Python) |
|-------|--------------|----------------|
| 1 | Express API, tests, multi-stage image | FastAPI, pytest, multi-stage image |
| 2 | ECR repo `orders-node` | ECR repo `users-python` |
| 3 | build/test/push/deploy (path filter) | build/test/push/deploy (path filter) |
| 4 | Deployment + `/orders` ingress path | Deployment + `/users` ingress path |
| 5 | logs / metrics / alarms | logs / metrics / alarms |

## Dependencies between phases

```text
Phase 1 -> nothing (local only)
Phase 2 -> needs Phase 1 images conceptually (repos to push into)
Phase 3 -> needs Phase 2 (ECR, EKS, OIDC role) to deploy into
Phase 4 -> needs Phase 3 (a working deploy) to harden
Phase 5 -> needs Phase 4 (a running hardened app) to observe
```

Do them **in order**. Stop after any phase and still have something demonstrable.

## Suggested pace

| Phase | Estimate |
|-------|----------|
| 1 | ~1 week |
| 2 | ~1–2 weeks (Terraform + EKS is the biggest learning curve) |
| 3 | ~1–2 weeks |
| 4 | ~1 week |
| 5 | ~1 week |

## Definition of done (whole project)

- [ ] `git push` triggers a pipeline that builds, tests, pushes to ECR, and deploys
      both apps to EKS with no manual steps.
- [ ] Entire AWS environment stands up and tears down from Terraform alone.
- [ ] Both apps run on EKS with RBAC + network policies + non-root + no plaintext secrets.
- [ ] GuardDuty + Security Hub on; CloudWatch shows app/infra logs with one alert.

## Cost reminder (important)

EKS control plane (~$0.10/hr ≈ $73/mo) + node EC2 + NAT + ALB cost money while
running. Run `terraform apply` at the **start** of a session and `terraform destroy`
at the **end**. Never leave the cluster running overnight for a lab.

> Cheaper variant: swap EKS for ECS Fargate (no control-plane fee) if cost is the
> main constraint — but you lose raw Kubernetes practice (a listed roadmap skill).

## Reference files

**Planning docs (this `planning/` folder):**

| File | What it is |
|------|------------|
| `00-MASTER-PLAN.md` | This file (high-level overview) |
| `PHASE-1.md` | Detailed plan — apps + Docker |
| `PHASE-2.md` | Detailed plan — Terraform / IaC |
| `PHASE-2.5.md` | Detailed plan — separate Terraform CI/CD pipeline |
| `PHASE-3.md` | Detailed plan — app CI/CD pipeline |
| `PHASE-4.md` | Detailed plan — Kubernetes hardening |
| `PHASE-5.md` | Detailed plan — observability + posture |
| `00-project-plan.md` | Original planning notes + locked decisions |
| `02-phase-plan.md` | Markdown version of the phase plan |
| `01-hld-architecture.drawio` | High-level design diagram (AWS icons) |
| `AWS-DEVOPS-LAB-BEGINNER-END-TO-END-EXPLANATION.md` | Plain-language walkthrough |

**Implementation + build notes (`../app/`):**

| File | What it is |
|------|------------|
| `../README.md` | Repo front page (quick start, layout) |
| `../app/README.md` | Application monorepo guide |
| `../app/DOCUMENTATION.md` | Full implementation record (live resource IDs) |
| `../app/docs/` | Per-phase build docs + `runbook.md` (apply/verify/teardown) |
