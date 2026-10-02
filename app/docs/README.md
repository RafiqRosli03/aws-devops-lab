# DevOps Lab — AWS EKS CI/CD Platform

An end-to-end DevOps project on AWS covering the four core disciplines: **containers,
Infrastructure as Code, CI/CD, and cloud operations**. Two microservices (Node.js and
Python) are driven through one identical, language-agnostic delivery workflow — proving
the pipeline, not the apps, is the point.

- **Account:** `497862079645`
- **Region:** `ap-southeast-5` (Malaysia)
- **Repo:** `RafiqRosli03/devops-lab` (GitLab)
- **Cluster:** `devops-lab-dev` (Amazon EKS, Kubernetes 1.31)

## Architecture (high level)

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
CloudWatch (logs+metrics+dashboard+alarm→SNS) · GuardDuty · Security Hub
```

## Technology

| Area | Choice |
|------|--------|
| Apps | Node.js/Express (orders), Python/FastAPI (users) |
| Containers | Docker (multi-stage, non-root), Kubernetes (EKS) |
| Registry | Amazon ECR (immutable, scan-on-push) |
| IaC | Terraform (remote state in S3 + native lock) |
| CI/CD | GitLab CI (OIDC to AWS, no static keys) |
| Ingress | AWS Load Balancer Controller (ALB) |
| Security | IAM/OIDC, KMS, Secrets Manager, Pod Security Admission, NetworkPolicies, GuardDuty, Security Hub |
| Observability | CloudWatch Container Insights, dashboard, SNS alarm |

## The five phases

| Phase | Title | Doc |
|-------|-------|-----|
| 1 | Applications + Docker | [phase-1-apps-docker.md](phase-1-apps-docker.md) |
| 2 | Infrastructure as Code (Terraform) | [phase-2-terraform.md](phase-2-terraform.md) |
| 2.5 | Separate Terraform CI/CD pipeline | [phase-2.5-terraform-pipeline.md](phase-2.5-terraform-pipeline.md) |
| 3 | CI/CD pipeline (GitLab CI) | [phase-3-cicd.md](phase-3-cicd.md) |
| 4 | Kubernetes hardening | [phase-4-k8s-hardening.md](phase-4-k8s-hardening.md) |
| 5 | Observability + security posture | [phase-5-observability.md](phase-5-observability.md) |

Also see **[runbook.md](runbook.md)** for the apply/verify/teardown procedure and
cost control.

## Live resource identifiers (dev)

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

## Cost note

EKS control plane + worker EC2 + NAT + ALB run ~**$0.28/hr (~RM1.30/hr)**, i.e.
~$210/month if left 24/7. Discipline: `terraform apply` at the start of a work
session, `terraform destroy` at the end. GuardDuty and Security Hub bill at the
account/region level independently of the cluster. See [runbook.md](runbook.md).
