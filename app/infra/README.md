# Phase 2 — Infrastructure as Code (Terraform)

Builds the entire AWS foundation the apps deploy onto. **Nothing is applied yet** —
this is written for review first.

Account: `497862079645` · Region: `ap-southeast-5`

## Layout

```
infra/
  bootstrap/         one-time: S3 state bucket + DynamoDB lock table
  modules/
    network/         VPC, subnets, IGW, NAT, route tables
    ecr/             one repo per app
    eks/             EKS control plane + managed node group
    iam-oidc/        GitLab OIDC provider + deploy role
    security/        KMS key + Secrets Manager secrets
  envs/
    dev/             wires the modules together for the dev environment
```

## Order of operations (when you're ready to apply)

1. **Bootstrap the state backend first** (chicken-and-egg: state needs to exist
   before the main stack can use it):
   ```bash
   cd infra/bootstrap
   terraform init
   terraform apply         # creates the S3 bucket + DynamoDB lock table
   ```
2. **Then the main environment:**
   ```bash
   cd infra/envs/dev
   terraform init          # uses the S3 backend from step 1
   terraform plan          # REVIEW before applying
   terraform apply         # builds VPC + ECR + EKS + IAM/OIDC + KMS + Secrets
   ```
3. **Connect kubectl:**
   ```bash
   aws eks update-kubeconfig --region ap-southeast-5 --name devops-lab-dev
   kubectl get nodes
   ```
4. **Tear down when idle (stops the cost):**
   ```bash
   cd infra/envs/dev
   terraform destroy
   ```

## COST WARNING (read before apply)

These run 24/7 while up and are the bulk of the bill:

| Resource | Rough cost |
|----------|-----------|
| EKS control plane | ~$0.10/hr (~$73/mo) |
| 2x t3.small worker nodes | ~$0.04/hr (~$30/mo) |
| NAT Gateway | ~$0.045/hr (~$32/mo) + data |
| Application Load Balancer (Phase 4) | ~$0.025/hr (~$18/mo) |

Strategy: `terraform apply` at the start of a session, `terraform destroy` at the end.
ECR storage, KMS, Secrets Manager are negligible by comparison.

> Prerequisite not yet met: the AWS CLI is not configured on this machine. Before any
> apply, configure credentials for account 497862079645 (e.g. `aws configure` or SSO)
> with permissions to create VPC/EKS/IAM/ECR/KMS resources in ap-southeast-5.
