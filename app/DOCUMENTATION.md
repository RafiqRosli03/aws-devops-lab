# DevOps Lab — AWS EKS CI/CD Platform — Full Documentation

Single consolidated document covering the whole project: the plan, what was built in
each phase, how it was verified, the problems hit and fixed, and the operational
runbook. Read top to bottom.

> Per-phase docs also live in `docs/` if you want them separately. This file is the
> all-in-one version.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Technology & Decisions](#3-technology--decisions)
4. [Phase 1 — Applications + Docker](#4-phase-1--applications--docker)
5. [Phase 2 — Infrastructure as Code (Terraform)](#5-phase-2--infrastructure-as-code-terraform)
6. [Phase 2.5 — Separate Terraform CI/CD Pipeline](#6-phase-25--separate-terraform-cicd-pipeline)
7. [Phase 3 — CI/CD Pipeline (GitLab CI)](#7-phase-3--cicd-pipeline-gitlab-ci)
8. [Phase 4 — Kubernetes Hardening](#8-phase-4--kubernetes-hardening)
9. [Phase 5 — Observability & Security Posture](#9-phase-5--observability--security-posture)
10. [Live Resource Identifiers](#10-live-resource-identifiers)
11. [Runbook — Apply / Verify / Teardown](#11-runbook--apply--verify--teardown)
12. [Cost Reference](#12-cost-reference)
13. [Problems Hit & How They Were Fixed](#13-problems-hit--how-they-were-fixed)

---

## 1. Project Overview

An end-to-end DevOps project on AWS covering the four core disciplines: **containers,
Infrastructure as Code, CI/CD, and cloud operations**.

Two small microservices — a Node.js/Express "orders" API and a Python/FastAPI "users"
API — are driven through one identical, **language-agnostic** delivery workflow. The
apps are intentionally simple; the value is the pipeline, the containers, the
infra-as-code, and the AWS wiring around them.

- **Account:** `497862079645`
- **Region:** `ap-southeast-5` (Malaysia)
- **Portfolio mirror:** `github.com/RafiqRosli03/aws-devops-lab` (GitHub — browse the code)
- **CI/CD project:** `RafiqRosli03/devops-lab` (GitLab — runs the pipeline; this path is what the OIDC trust is scoped to)
- **Cluster:** `devops-lab-dev` (Amazon EKS, Kubernetes 1.31)

**Build order & dependencies:** Phase 1 (local) → Phase 2 (infra the apps deploy onto)
→ Phase 3 (pipeline that fills the infra) → Phase 4 (harden the running workloads) →
Phase 5 (observe & secure). Each phase depends on the previous; you can stop after any
phase and still have something demonstrable.

---

## 2. Architecture

```
Developer ──git push──► GitLab
   │
   ├── apps/** changed ──► APP PIPELINE
   │      test → ecr-login(OIDC) → build(Kaniko→ECR, SHA tag) → deploy(EKS/dev) → deploy-prod(gated)
   │
   └── infra/** changed ─► INFRA PIPELINE
          tf-validate → tf-plan → tf-apply(gated)

ECR (images) ──► EKS (hardened pods) ◄── Terraform builds all infra
   │
   ▼
Single ALB Ingress  →  /orders (Node)  ·  /users (Python)
   │
   ▼
CloudWatch (logs + metrics + dashboard + alarm→SNS) · GuardDuty · Security Hub
```

**Flow in words:** a developer pushes code; GitLab CI tests it, builds a container,
authenticates to AWS via OIDC (no stored keys), pushes the image to ECR tagged by git
SHA, and deploys it to EKS. Terraform builds all the AWS infrastructure the apps run
on. The apps are served through one ALB with path routing. CloudWatch, GuardDuty, and
Security Hub watch the account.

---

## 3. Technology & Decisions

| Area | Choice | Why |
|------|--------|-----|
| Orchestrator | Amazon EKS (Kubernetes) | industry-standard, transferable skill |
| App A | Node.js + Express (orders) | minimal JSON/static API |
| App B | Python + FastAPI (users) | modern, free validation + auto docs |
| CI/CD | GitLab CI | self-contained YAML, OIDC to AWS |
| Registry | Amazon ECR | native to EKS, frictionless pulls |
| IaC | Terraform | industry-standard, remote state in S3 |
| Ingress | AWS Load Balancer Controller (ALB) | single ALB, path routing |
| Secrets/crypto | KMS + Secrets Manager | no plaintext secrets |
| Auth | IAM + OIDC federation | no long-lived AWS keys anywhere |
| Security posture | GuardDuty + Security Hub | account-level threat detection + CSPM |
| Observability | CloudWatch Container Insights | logs, metrics, dashboard, alarms |

**Locked decisions:** EKS (not ECS) for real Kubernetes practice; two fresh apps built
from scratch; GitLab CI + OIDC for keyless auth; ECR because EKS pulls from it natively;
region `ap-southeast-5`.

---

## 4. Phase 1 — Applications + Docker

**Goal:** build both apps and containerize each properly. Local only, no AWS, zero cost.

### Apps
- **orders-node (Node/Express):** `GET /health`, `GET /orders`, `POST /orders`
  (in-memory, 201/400), static GUI, tests via `node --test`, port from `PORT` (3000).
- **users-python (Python/FastAPI):** `GET /health`, `GET /users`, `POST /users`
  (Pydantic validation), static GUI + auto docs at `/docs`, `pytest`, port `PORT` (8000).

### Containers
Both use **multi-stage, non-root** Dockerfiles:
- orders-node: build stage installs deps + runs tests; runtime copies prod deps + src
  onto `node:20-slim`, runs as `node` (UID 1000).
- users-python: build stage installs deps to an isolated prefix; runtime copies onto
  `python:3.12-slim`, runs as `appuser` (UID 1000).

Verified to run under read-only root FS + non-root + tmpfs `/tmp` (needed for Phase 4
PSA restricted). `docker-compose.yml` runs both locally.

### Definition of Done — met
- [x] Both apps implemented, unit tests pass
- [x] Multi-stage non-root Dockerfile per app
- [x] `docker compose up` runs both; both `/health` return ok
- [x] Clean Git history

---

## 5. Phase 2 — Infrastructure as Code (Terraform)

**Goal:** stand up the entire AWS environment from Terraform. No click-ops.

### Layout
```
infra/
  bootstrap/      S3 state bucket + DynamoDB lock (local state, run once)
  modules/        network, ecr, eks, iam-oidc, security (+ alb-controller, observability later)
  envs/dev/       wires modules; backend.tf; dev.tfvars (gitignored)
```

### Remote state (bootstrap first)
`infra/bootstrap` creates (local state): S3 bucket `devops-lab-tfstate-497862079645`
(versioned, AES256, public-access blocked) + DynamoDB `devops-lab-tf-locks`.
`envs/dev/backend.tf` then uses native S3 locking (`use_lockfile`, Terraform ≥ 1.10).

### What gets built
| Module | Resources |
|--------|-----------|
| network | VPC 10.0.0.0/16, 2 public + 2 private subnets, IGW, 1 NAT, routes, EKS/ELB subnet tags |
| ecr | `orders-node`, `users-python` — IMMUTABLE, scan-on-push, expire untagged >14d |
| eks | control plane + managed node group (t3.small, 2–4), addons coredns/kube-proxy/vpc-cni |
| iam-oidc | GitLab OIDC provider; narrow deploy role + broad terraform role |
| security | KMS key (rotation) + Secrets Manager secrets per app |

### Definition of Done — met
- [x] `terraform apply` builds VPC + ECR + EKS + IAM/OIDC + KMS + Secrets
- [x] `kubectl get nodes` shows workers Ready
- [x] Outputs give ECR URIs, cluster name, role ARNs

### Gotchas
- EKS 1.30 AMI deprecated → bumped to **1.31**; EKS upgrades one minor at a time.
- Transient S3 drop left a stale state lock → `terraform force-unlock`.
- `enable_cluster_creator_admin_permissions` makes the `cluster_creator` access entry
  flip between laptop user and CI role across applies (harmless).

---

## 6. Phase 2.5 — Separate Terraform CI/CD Pipeline

**Goal:** manage infrastructure through CI/CD too, kept **separate** from the app
pipeline (industry-standard split). Same `.gitlab-ci.yml`, split by path filters.

### Why separate
| | App pipeline | Infra pipeline |
|---|---|---|
| Changes | many/day | rarely |
| Blast radius | one service | whole environment |
| Permissions | narrow (ECR/EKS/secrets) | broad (VPC/IAM/EKS) |
| Approval | dev auto | plan reviewed, apply gated |

### Separate role
`devops-lab-dev-gitlab-terraform` (PowerUserAccess + IAM + state backend), assumed only
by the infra pipeline. CI/CD var: `AWS_TF_ROLE_ARN`.

### Stages (on `infra/**` changes)
`tf-validate` (fmt + validate) → `tf-plan` (reads live state) → `tf-apply` (**manual gate**).
Auth uses Terraform's native provider OIDC (`AWS_WEB_IDENTITY_TOKEN_FILE`) since the
`hashicorp/terraform` image has no AWS CLI.

### Verified
`tf-validate` + `tf-plan` green; plan showed no changes (state matched live infra),
proving the pipeline works without altering anything. `tf-apply` sits gated.

### Gotcha
Pipeline image must be Terraform ≥ 1.10 (`use_lockfile`); pinned `hashicorp/terraform:1.13`.

---

## 7. Phase 3 — CI/CD Pipeline (GitLab CI)

**Goal:** every push builds, tests, pushes images, deploys both apps to EKS — no
long-lived AWS keys. In `.gitlab-ci.yml`.

### Auth — OIDC, no static keys
GitLab mints a short-lived OIDC token; jobs `assume-role-with-web-identity` the **narrow**
`devops-lab-dev-gitlab-deploy` role (ECR push/pull, `eks:DescribeCluster`, read secrets),
trust scoped to `project_path:RafiqRosli03/devops-lab:*`. CI/CD var: `AWS_ROLE_ARN`.

### Stages (on `apps/**` changes)
| Stage | Image | What |
|-------|-------|------|
| test | node:20 / python:3.12 | `npm test` / `pytest`; path filters so only changed app runs |
| auth (ecr-login) | amazon/aws-cli | assume role, ECR login, write Docker auth artifact |
| build | kaniko | rootless build, push to ECR tagged by **git SHA** |
| deploy | aws-cli + kubectl | `kubectl apply -k k8s/base` then `set image` to new SHA (dev, auto) |
| deploy-prod | " | same, **manual gate** to prod namespace |

### Definition of Done — met
- [x] A push changing one app rebuilds/deploys only that app
- [x] Images in ECR tagged by git SHA
- [x] dev auto-deploys; prod gated
- [x] No static AWS credentials (OIDC only)

### Verified
Full `test → auth → build → deploy` green for both apps; pods Running in `dev`, pulled
from ECR by SHA.

---

## 8. Phase 4 — Kubernetes Hardening

**Goal:** turn the working deployment into a hardened, production-shaped one. Manifests
in `k8s/base/` (Kustomize); pipeline applies them.

### Workloads
Deployment (replicas 2), probes on `/health`, resource requests+limits, ClusterIP
Service per app, dedicated ServiceAccount with `automountServiceAccountToken: false`.

### Pod security (satisfies PSA `restricted`)
`runAsNonRoot`, `runAsUser: 1000`, `readOnlyRootFilesystem` (+ `/tmp` emptyDir),
`allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, `seccompProfile:
RuntimeDefault`.

### Hardening features
- **Pod Security Admission:** `dev` namespace labelled `enforce: restricted`.
  *Verified:* a privileged root pod is rejected (`Forbidden`).
- **RBAC:** per-app Role with no rules + binding; no cluster-admin for workloads.
- **NetworkPolicies:** default-deny ingress+egress, allow DNS egress, allow app ports.
  VPC CNI `enableNetworkPolicy=true` enabled. *Verified:* test pod egress to app blocked.
- **Ingress:** single internet-facing ALB via AWS Load Balancer Controller (IRSA role
  `devops-lab-dev-alb-controller`), routes `/orders` + `/users`. *Verified:* both 200.
  HTTP only (HTTPS needs a real domain + ACM — future work).
- **HPA:** CPU-based, 2→5 at 60%, both apps; metrics-server installed. *Verified:* live CPU.
- **EKS access entry:** grants the deploy role cluster RBAC (fixes Phase 3 kubectl auth).

### Definition of Done — met
- [x] Both apps via one ALB on their paths
- [x] Root/policy-violating pods rejected
- [x] NetworkPolicy blocks disallowed traffic
- [x] No plaintext secrets
- [x] HPA autoscaling in place

### One-time cluster add-ons (not in the app pipeline)
AWS Load Balancer Controller + metrics-server, installed via Helm/manifest; both die
with the cluster on teardown.

---

## 9. Phase 5 — Observability & Security Posture

**Goal:** see and secure the running platform. In `infra/modules/observability/` + EKS addon.

### Logging + metrics — Container Insights
EKS addon `amazon-cloudwatch-observability` (CloudWatch agent + Fluent Bit DaemonSets);
node group has `CloudWatchAgentServerPolicy`. Log groups:
`/aws/containerinsights/devops-lab-dev/{application,dataplane,host,performance}` +
`/aws/eks/devops-lab-dev/cluster`. *Verified:* found a log stream for the users-python pod.

### Dashboard — `devops-lab-dev-dashboard`
Pod CPU, pod memory, ALB request count, ALB 5xx count.

### Alerting
SNS topic `devops-lab-dev-alerts` + email subscription (**must confirm the email**).
Alarm `devops-lab-dev-alb-5xx` fires at `HTTPCode_ELB_5XX_Count ≥ 1`/60s → SNS.
*Verified:* scaled orders-node to 0 → 70× HTTP 503 → metric recorded → alarm went to
**ALARM** → SNS notified; app restored to 2/2.

### Security posture
GuardDuty detector enabled; Security Hub enabled with AWS Foundational Security Best
Practices (findings aggregating). Inspector optional (not enabled).

### Definition of Done — met
- [x] App + cluster logs in CloudWatch
- [x] Dashboard shows live health
- [x] Alarm fires on simulated bad event → SNS
- [x] GuardDuty + Security Hub on with findings

### Note
GuardDuty + Security Hub are account/region-level and bill independently of the cluster;
they're in Terraform so `terraform destroy` removes them.

---

## 10. Live Resource Identifiers

| Resource | Value |
|----------|-------|
| EKS cluster | `devops-lab-dev` |
| ECR — orders | `497862079645.dkr.ecr.ap-southeast-5.amazonaws.com/orders-node` |
| ECR — users | `497862079645.dkr.ecr.ap-southeast-5.amazonaws.com/users-python` |
| App-deploy OIDC role | `devops-lab-dev-gitlab-deploy` |
| Terraform OIDC role | `devops-lab-dev-gitlab-terraform` |
| ALB controller IRSA role | `devops-lab-dev-alb-controller` |
| KMS key | `…key/4956ee56-14d4-428a-b624-d794c7a39f93` |
| CloudWatch dashboard | `devops-lab-dev-dashboard` |
| SNS alerts topic | `devops-lab-dev-alerts` |
| State bucket / lock | `devops-lab-tfstate-497862079645` / `devops-lab-tf-locks` |

---

## 11. Runbook — Apply / Verify / Teardown

### Prerequisites
AWS CLI configured for account `497862079645`; Terraform ≥ 1.10, kubectl, Helm, Docker;
region `ap-southeast-5`.

### Bring up (session start)
```bash
# 1. State backend (first time only)
cd infra/bootstrap && terraform init && terraform apply
# 2. Main env (~15-20 min)
cd ../envs/dev && terraform init && terraform apply -var-file dev.tfvars
# 3. kubectl
aws eks update-kubeconfig --region ap-southeast-5 --name devops-lab-dev && kubectl get nodes
# 4. One-time add-ons
helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --set clusterName=devops-lab-dev --set region=ap-southeast-5 \
  --set vpcId=<vpc-id> --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::497862079645:role/devops-lab-dev-alb-controller
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# 5. Deploy apps (or let the pipeline do it)
kubectl apply -k k8s/base
```

### Verify
```bash
kubectl get pods -n dev        # 2/app Running
kubectl get ingress -n dev     # ALB address
kubectl get hpa -n dev         # CPU targets
curl http://<alb>/orders ; curl http://<alb>/users   # 200
```

### Tear down (session end — stops the bill). **Order matters.**
```bash
# 1. Delete k8s objects FIRST (removes the ALB created by the Ingress)
kubectl delete -k k8s/base
kubectl delete svc -n dev --all --ignore-not-found
# 2. Destroy Terraform infra (cluster, VPC, NAT, ECR, KMS, GuardDuty, Security Hub, SNS, dashboard, alarm)
cd infra/envs/dev && terraform destroy -var-file dev.tfvars
# 3. (Optional) leave bootstrap S3/DynamoDB — near-free, needed next time
```

### Post-teardown check (all should be empty)
```bash
aws elbv2 describe-load-balancers --region ap-southeast-5 --query "LoadBalancers[].LoadBalancerName"
aws ec2 describe-nat-gateways --region ap-southeast-5 --filter Name=state,Values=available
aws eks list-clusters --region ap-southeast-5
```

---

## 12. Cost Reference

| Resource | ~Hourly | ~Monthly if 24/7 |
|----------|---------|------------------|
| EKS control plane | $0.10 | ~$73 |
| worker nodes (t3.small) | $0.025 ea | ~$18 ea |
| NAT Gateway | $0.045 + data | ~$33 |
| ALB | $0.025 | ~$18 |
| GuardDuty + Security Hub | usage | ~$5-15 |
| **Running total** | **~$0.28/hr (~RM1.30)** | **~$210 (~RM1,000)** |

**Discipline:** apply at session start, `terraform destroy` at the end. A short lab
session costs a few ringgit; leaving it running a month is ~RM1,000.
**Watch item:** desired nodes = 2; a failed apply once left 4 — reconcile if needed.

---

## 13. Problems Hit & How They Were Fixed

A record of the real issues encountered (useful for interviews and future debugging):

| # | Problem | Fix |
|---|---------|-----|
| 1 | EKS node group failed: "Requested AMI for version 1.30 not supported" | Bumped cluster to 1.31 (1.30 AMI deprecated); EKS upgrades one minor at a time |
| 2 | Stale Terraform state lock after a network drop | `terraform force-unlock <id>` after confirming no apply running |
| 3 | GitLab empty-project README blocked the first push | Protected branch rejected force-push; merged unrelated histories, kept our README |
| 4 | pytest `ModuleNotFoundError: app` in CI | Added `pyproject.toml` with `pythonpath=["."]` |
| 5 | Kaniko/kubectl images lack AWS CLI → build/deploy failed | Did AWS auth in an `amazon/aws-cli` job; passed Docker auth to Kaniko via artifact; installed static kubectl in deploy |
| 6 | `kubectl` "Unauthorized" from CI | Added EKS access entry mapping the deploy role to cluster-admin |
| 7 | Terraform pipeline failed: `use_lockfile` not expected | Pipeline image must be Terraform ≥ 1.10; pinned 1.13 |
| 8 | NetworkPolicies declared but not enforced | Enabled VPC CNI `enableNetworkPolicy=true` (off by default) |
| 9 | Laptop lost kubectl access after access-entry change | `cluster_creator` entry flip-flops between laptop/CI identity; re-added rafiq-admin, reconciled in Terraform |
| 10 | Manual `kubectl expose` LB services orphaned (not in TF) | Deleted them; replaced with the single ALB Ingress; teardown deletes Ingress first |
