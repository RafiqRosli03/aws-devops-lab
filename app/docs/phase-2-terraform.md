# Phase 2 — Infrastructure as Code (Terraform)

**Goal:** stand up the entire AWS environment from Terraform. No click-ops.

## Layout

```
infra/
  bootstrap/            S3 state bucket + DynamoDB lock (local state, run once)
  modules/
    network/           VPC, public/private subnets (2 AZ), IGW, NAT, routes
    ecr/               one repo per app (immutable, scan-on-push, lifecycle)
    eks/               control plane + managed node group (community module)
    iam-oidc/          GitLab OIDC provider + deploy & terraform roles
    security/          KMS key + Secrets Manager placeholders
  envs/dev/            wires modules together; backend.tf; dev.tfvars (gitignored)
```

## Remote state (bootstrap first)

Chicken-and-egg: state must exist before the main stack uses it. `infra/bootstrap`
creates with **local** state:
- S3 bucket `devops-lab-tfstate-497862079645` (versioned, AES256, public access blocked)
- DynamoDB table `devops-lab-tf-locks`

`envs/dev/backend.tf` then uses that bucket with **native S3 locking**
(`use_lockfile = true`, requires Terraform ≥ 1.10).

## What gets built (dev)

| Module | Resources |
|--------|-----------|
| network | VPC 10.0.0.0/16, 2 public + 2 private subnets, IGW, 1 NAT, route tables, EKS/ELB subnet tags |
| ecr | `orders-node`, `users-python` — IMMUTABLE tags, scan-on-push, expire untagged >14d |
| eks | EKS control plane + managed node group (t3.small, 2–4), addons: coredns, kube-proxy, vpc-cni |
| iam-oidc | GitLab OIDC provider; `-gitlab-deploy` (narrow) + `-gitlab-terraform` (broad) roles |
| security | KMS key (rotation on) + Secrets Manager secrets per app |

## Apply procedure

```bash
cd infra/bootstrap && terraform init && terraform apply       # state backend
cd ../envs/dev && terraform init && terraform plan -var-file dev.tfvars
terraform apply -var-file dev.tfvars                          # ~15-20 min (EKS)
aws eks update-kubeconfig --region ap-southeast-5 --name devops-lab-dev
kubectl get nodes
```

## Key outputs
- `eks_cluster_name = devops-lab-dev`
- `ecr_repository_urls` (both apps)
- `gitlab_deploy_role_arn`, `gitlab_terraform_role_arn`
- `kms_key_arn`, `secret_arns`

## Definition of Done — met
- [x] `terraform apply` builds VPC + ECR + EKS + IAM/OIDC + KMS + Secrets
- [x] `kubectl get nodes` shows workers Ready
- [x] Outputs give ECR URIs, cluster name, role ARNs

## Notes / gotchas
- **EKS 1.30 AMI deprecated** at build time — bumped `cluster_version` to **1.31**
  (its node AMI exists). EKS only allows one minor-version upgrade at a time.
- A transient S3 network drop once left a stale state lock; resolved with
  `terraform force-unlock <id>` after confirming no apply was running.
- `enable_cluster_creator_admin_permissions = true` grants cluster admin to whoever
  runs the apply — this causes the `cluster_creator` access entry to flip between the
  laptop user and the CI role across applies (harmless, recreates in seconds).
