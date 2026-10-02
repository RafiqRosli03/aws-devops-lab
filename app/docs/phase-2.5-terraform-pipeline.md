# Phase 2.5 — Separate Terraform CI/CD Pipeline

**Goal:** manage infrastructure through CI/CD too, kept **separate** from the app
pipeline — the industry-standard split. Lives in the same `.gitlab-ci.yml`, gated by
path filters so `infra/**` changes trigger infra jobs and `apps/**` changes trigger app
jobs.

## Why separate pipelines

| | App pipeline | Infra pipeline |
|---|---|---|
| Changes | many times/day | rarely |
| Blast radius | one service | whole environment |
| AWS permissions | narrow (ECR/EKS/secrets) | broad (VPC/IAM/EKS) |
| Approval | dev auto | plan reviewed, apply gated |

Mixing them would force a full `terraform plan` on every app code change and give the
app deploy dangerously broad permissions. Separation keeps least privilege intact.

## Separate privileged role

A second OIDC role `devops-lab-dev-gitlab-terraform` (PowerUserAccess + IAM
management + state-backend S3/DynamoDB) is assumed only by the infra pipeline. The
narrow app-deploy role is untouched.

Required CI/CD variable: `AWS_TF_ROLE_ARN = arn:aws:iam::497862079645:role/devops-lab-dev-gitlab-terraform`

## Stages (triggered by `infra/**` changes)

| Stage | What |
|-------|------|
| tf-validate | `terraform fmt -check` + `terraform validate` |
| tf-plan | `terraform plan` (reads live state; artifact saved) |
| tf-apply | **manual gate** — `terraform apply` after a human reviews the plan |

Auth uses Terraform's native AWS provider OIDC support
(`AWS_WEB_IDENTITY_TOKEN_FILE` + `AWS_ROLE_ARN`), since the `hashicorp/terraform`
image has no AWS CLI — the same env vars authenticate both the S3 backend and the
provider.

## Gotcha
- Pipeline image **must be Terraform ≥ 1.10** — `backend.tf` uses native S3 locking
  (`use_lockfile`), which 1.9 rejects. Pinned to `hashicorp/terraform:1.13`.

## Verified
`tf-validate` + `tf-plan` ran green; plan showed no changes (live infra matched state),
proving the pipeline reads remote state and authenticates correctly without touching
anything. `tf-apply` sits as a manual gate.
