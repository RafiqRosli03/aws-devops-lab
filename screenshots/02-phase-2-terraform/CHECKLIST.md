# 02 — Phase 2: Terraform Infrastructure

- [x] `P2-01-terraform-module-structure.png` — `infra/bootstrap`, modules, and `envs/dev` in VS Code. _(have: Terraform-module-structure.png)_
- [x] `P2-02-terraform-validate-success.png` — `terraform fmt` and `terraform validate` success. _(have: Terraform format and validation.png)_
- [x] `P2-03-terraform-plan-no-changes.png` — plan summary or `No changes`. _(have: Terraform plan.png)_
- [x] `P2-04-terraform-outputs.png` — EKS/ECR/IAM/KMS output names; redact identifiers publicly. _(have: terraform-output.png)_
- [x] `P2-05-s3-state-versioning.png` — state bucket versioning enabled. _(have: s3 bucket versioning.png)_
- [x] `P2-06-s3-state-encryption-public-block.png` — encryption + Block Public Access. _(have: s3 bucket default encryption.png — confirm Block Public Access is also visible)_
- [x] `P2-07-vpc-resource-map.png` — VPC, 2 public/2 private subnets, routes, IGW, NAT. _(have: VPC resource map.png; also EKS networking summary.png)_
- [x] `P2-08-eks-cluster-active.png` — EKS status Active and Kubernetes version. _(have: EKS Status,kubernetes version.png)_
- [x] `P2-09-eks-node-group.png` — managed node group status/scaling. _(have: EKS Node Group.png)_
- [x] `P2-10-kubectl-nodes-ready.png` — `kubectl get nodes -o wide`. _(have: Ready Kubernetes node.png)_
- [x] `P2-11-ecr-repositories.png` — orders/users ECR repositories. _(have: ECR Reposittories.png)_
- [ ] `P2-12-ecr-sha-images-scan.png` — immutable SHA tags and scan status. _(SHA tags captured in Phase 3 folder; scan status not clearly shown here)_
- [x] `P2-13-gitlab-oidc-provider.png` — IAM OIDC provider (no tokens). _(have: IAM OIDC provider.png)_
- [x] `P2-14-iam-project-roles.png` — deploy, Terraform, and ALB controller roles. _(have: IAM Roles.png)_
- [x] `P2-15-kms-key-rotation.png` — customer-managed key/rotation. _(have: KMS Project Key.png — confirm rotation is visible)_
- [x] `P2-16-secrets-manager-names.png` — secret names only; never retrieve values. _(have: Secret Manager.png)_

## Useful commands

```powershell
Set-Location "app\infra\envs\dev"
terraform fmt -recursive -check ../../
terraform validate
terraform plan -var-file dev.tfvars
terraform output
kubectl get nodes -o wide
```
