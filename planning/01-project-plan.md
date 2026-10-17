# DevOps Project — Planning

Planning space for one end-to-end DevOps lab project on AWS that covers the four
core DevOps skills: **CI/CD, Containers & Orchestration, Infrastructure as Code, and
Cloud**. Security tooling (SAST/DAST/SCA/signing) layers on later via the
`DevSecOps-Roadmap` plan — here we build the DevOps backbone first.

---

## 1. The project (one line)

Take a small web app, containerize it, deploy it to **Kubernetes on AWS (EKS)**, and
drive the whole thing through an automated **CI/CD pipeline**, with **all infrastructure
defined as code (Terraform)**.

The app is not the point — the pipeline, the containers, the infra-as-code, and the
AWS wiring are the point.

---

## 2. What each roadmap skill maps to

| Core DevOps skill | Where it lives in this project |
|-------------------|--------------------------------|
| **CI/CD** (GitLab CI) | Pipeline that builds, tests, pushes image, deploys on every push |
| Pipeline stages, artifacts, caching, promotion, gating | build -> test -> push -> deploy, with dev -> prod promotion |
| Secrets handling | AWS Secrets Manager + GitLab OIDC (no static AWS keys in the pipeline) |
| **Docker** | Multi-stage Dockerfile, minimal/distroless base, non-root, read-only FS |
| **Kubernetes** | EKS: pods, deployments, services, ingress, RBAC, network policies, secrets |
| **IaC (Terraform)** | VPC, EKS, IAM/OIDC, ECR, KMS, Secrets Manager all in Terraform |
| **Cloud (AWS) deep** | IAM & identity, VPC networking, KMS, ECR, EKS, CloudWatch logging |
| CSPM concepts + GuardDuty advantage | Enable GuardDuty + Security Hub; central findings view |

---

## 3. High-level architecture

```
Developer git push
      |
      v
GitLab CI pipeline
  1. Lint + unit tests
  2. Build Docker image (multi-stage, non-root)
  3. Auth to AWS via OIDC (no static keys)
  4. Push image to Amazon ECR
  5. terraform apply  (VPC, EKS, IAM, KMS, Secrets Manager)
  6. Deploy to EKS (kubectl/helm) with RBAC + network policies
      |
      v
App running on EKS behind an ingress / ALB
      |
GuardDuty + Security Hub + CloudWatch watching the account
```

(Security scanning stages — SAST, SCA, Trivy, tfsec/Checkov — get inserted between
build and deploy when we move into the DevSecOps phase.)

---

## 4. Suggested phases (build order)

1. **Phase 1 - App + Docker:** write/pick a small app, containerize it properly
   (multi-stage build, non-root user, minimal base). Run locally with `docker run`.
2. **Phase 2 - IaC:** Terraform for VPC + ECR + EKS + IAM/OIDC + KMS + Secrets Manager.
   `terraform apply` builds it, `terraform destroy` removes it.
3. **Phase 3 - CI/CD:** GitLab CI pipeline — build, test, push to ECR, deploy to EKS.
   GitLab authenticates to AWS via **OIDC** (no long-lived keys).
4. **Phase 4 - Kubernetes hardening:** RBAC, network policies, resource limits,
   non-root security context, secrets from Secrets Manager (not plaintext).
5. **Phase 5 - Cloud posture + observability:** enable GuardDuty + Security Hub,
   ship logs to CloudWatch, one dashboard + one alert.

Stop after any phase and still have something demonstrable.

---

## 5. LOCKED decisions

Goal driving these choices: learn the FULL DevOps workflow using famous,
industry-standard tools (transferable skills over cheapest option).

| Decision | Choice | Why |
|----------|--------|-----|
| Orchestrator | **Amazon EKS** | Kubernetes is the industry-standard orchestrator and on nearly every DevOps job spec. AWS-proprietary ECS Fargate teaches less transferable skill. Tear down between sessions to control cost. |
| App A | **Node.js + Express** | fresh, minimal JSON/static API, built from scratch |
| App B | **Python + FastAPI** | fresh, minimal API; FastAPI over Flask = modern, free input validation + auto API docs (/docs) |
| CI/CD | **GitLab CI** | industry-famous, self-contained YAML pipelines; supports OIDC to AWS |
| Registry | **Amazon ECR** | native to EKS (frictionless image pulls); GitLab handles the pipeline, ECR holds images |
| IaC | **Terraform** | the industry-standard IaC tool |
| Region | **ap-southeast-5** | consistent with the other labs |
| App source | **build fresh from scratch** | both apps written new, not reused from the attack lab |

Notes:
- **GitLab CI + OIDC to AWS** keeps the "no static keys" design intact.
- **Why ECR and not GitLab Container Registry:** EKS pulls from ECR natively without
  cross-registry auth inside the cluster. Common real-world combo: GitLab pipeline +
  ECR images.

---

## 6. Cost note (important)

- **EKS control plane:** ~$0.10/hr (~$73/month) + worker node EC2 + any ALB.
- Strategy: `terraform apply` at the start of a session, `terraform destroy` at the
  end. Never leave EKS running overnight for a lab.
- Cheaper variant: swap EKS for **ECS Fargate** (no control-plane fee, pay-per-use) if
  cost is the main constraint — but you lose raw Kubernetes practice.

---

## 7. Definition of done (for the whole project)

- `git push` triggers a pipeline that builds, tests, pushes to ECR, and deploys to EKS
  with no manual steps.
- The entire AWS environment stands up and tears down from Terraform alone.
- The app runs on EKS with RBAC + network policies + non-root + no plaintext secrets.
- GuardDuty + Security Hub are on, and CloudWatch shows app/infra logs with one alert.

---

## 8. Decisions — RESOLVED

- [x] EKS or ECS Fargate? -> **EKS** (industry-standard Kubernetes; tear down between sessions).
- [x] App language + framework? -> **Node.js + Express** and **Python + FastAPI**.
- [x] CI tool? -> **GitLab CI** (OIDC to AWS, no static keys).
- [x] Region? -> **ap-southeast-5**.
- [x] Reuse attack-lab app or fresh? -> **Fresh minimal apps, built from scratch.**
- [x] Registry? -> **Amazon ECR** (native to EKS).

All decisions locked. Next step: build Phase 1 (both apps + Docker) — local, zero cost.
See [05-PHASE-1.md](05-PHASE-1.md).
