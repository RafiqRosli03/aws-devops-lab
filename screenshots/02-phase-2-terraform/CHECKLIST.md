# 02 — Phase 2: Terraform Infrastructure

- [ ] `P2-01-terraform-module-structure.png` — `infra/bootstrap`, modules, and `envs/dev` in VS Code.
- [ ] `P2-02-terraform-validate-success.png` — `terraform fmt` and `terraform validate` success.
- [ ] `P2-03-terraform-plan-no-changes.png` — plan summary or `No changes`.
- [ ] `P2-04-terraform-outputs.png` — EKS/ECR/IAM/KMS output names; redact identifiers publicly.
- [ ] `P2-05-s3-state-versioning.png` — state bucket versioning enabled.
- [ ] `P2-06-s3-state-encryption-public-block.png` — encryption + Block Public Access.
- [ ] `P2-07-vpc-resource-map.png` — VPC, 2 public/2 private subnets, routes, IGW, NAT.
- [ ] `P2-08-eks-cluster-active.png` — EKS status Active and Kubernetes version.
- [ ] `P2-09-eks-node-group.png` — managed node group status/scaling.
- [ ] `P2-10-kubectl-nodes-ready.png` — `kubectl get nodes -o wide`.
- [ ] `P2-11-ecr-repositories.png` — orders/users ECR repositories.
- [ ] `P2-12-ecr-sha-images-scan.png` — immutable SHA tags and scan status.
- [ ] `P2-13-gitlab-oidc-provider.png` — IAM OIDC provider (no tokens).
- [ ] `P2-14-iam-project-roles.png` — deploy, Terraform, and ALB controller roles.
- [ ] `P2-15-kms-key-rotation.png` — customer-managed key/rotation.
- [ ] `P2-16-secrets-manager-names.png` — secret names only; never retrieve values.

## Useful commands

```powershell
Set-Location "app\infra\envs\dev"
terraform fmt -recursive -check ../../
terraform validate
terraform plan -var-file dev.tfvars
terraform output
kubectl get nodes -o wide
```
