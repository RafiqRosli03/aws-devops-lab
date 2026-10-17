# Phase 2 — Infrastructure as Code (Terraform)

> **Environment:** AWS. Costs money while running (EKS/NAT/ALB). Tear down when idle.
> **Goal:** Stand up the **entire** AWS environment from Terraform. No click-ops.

## Why this phase

The pipeline (Phase 3) needs somewhere to push images and deploy to. We build that
"somewhere" as code so it is repeatable, reviewable, and destroyable in one command.

## Step 1 — Terraform project structure

```text
infra/
  bootstrap/          one-time: S3 state bucket + lock (see Step 2)
  modules/
    network/          VPC, subnets, IGW, NAT, route tables
    ecr/              one repo per app
    eks/              control plane + managed node group
    iam-oidc/         GitLab OIDC provider + deploy & terraform roles
    security/         KMS key, Secrets Manager secrets
    observability/    CloudWatch dashboard, SNS alarm, GuardDuty, Security Hub (used in Phase 5)
    alb-controller/   IRSA role for the AWS Load Balancer Controller (used in Phase 4)
  envs/
    dev/
      main.tf         calls the modules
      variables.tf
      outputs.tf
      dev.tfvars      gitignored - holds env specifics; see dev.tfvars.example
      backend.tf      remote state config
```

**Principle:** modules are reusable building blocks; `envs/dev` wires them together.

> All seven modules are defined up front so later phases only add Kubernetes/config
> on top — no Terraform rework. The `observability` and `alb-controller` modules
> aren't exercised until Phases 5 and 4 respectively, but they live here because they
> are infrastructure.

## Step 2 — Remote state (do this FIRST)

Terraform state must live remotely and be locked so it is safe and shareable.

- [ ] Create an S3 bucket for state (versioning **on**, encryption **on**, public access **off**).
- [ ] Enable state locking.
- [ ] Configure `backend.tf` to use them.
- [ ] `terraform init` (confirms the backend works).

> The state bucket is created by a tiny bootstrap Terraform (`infra/bootstrap/`) once;
> everything else is managed by the main config.
>
> **Locking:** the implementation uses S3 **native** state locking (no separate
> DynamoDB table). The classic approach used a DynamoDB lock table; the newer S3
> native lock does the same job with one less resource. Either is fine — the goal is
> that two Terraform runs can't corrupt the same state at once.

## Step 3 — Network module

- [ ] VPC `10.0.0.0/16`.
- [ ] 2 public subnets (AZ-a, AZ-b) → for ALB + NAT.
- [ ] 2 private subnets (AZ-a, AZ-b) → for EKS worker nodes.
- [ ] Internet Gateway on the VPC.
- [ ] NAT Gateway in a public subnet (egress for private nodes).
- [ ] Route tables: public → IGW, private → NAT.
- [ ] Tag subnets for EKS/ELB discovery (`kubernetes.io/role/elb`, etc.).

## Step 4 — ECR module

- [ ] Repo `orders-node`.
- [ ] Repo `users-python`.
- [ ] Enable image scanning on push (free basic scan).
- [ ] Lifecycle policy to expire old untagged images (cost hygiene).
- [ ] Output the repo URIs (Phase 3 needs them).

## Step 5 — EKS module

- [ ] EKS control plane (managed) in the VPC.
- [ ] Managed node group in the **private** subnets (e.g. 2× t3.small/medium).
- [ ] Node group autoscaling min/desired/max (e.g. 2/2/4).
- [ ] OIDC provider for the cluster (needed for IRSA — pod-level IAM later).
- [ ] Cluster add-ons: VPC CNI, CoreDNS, kube-proxy.
- [ ] Output cluster name + endpoint (Phase 3 + kubectl need them).

> **Tip:** the community `terraform-aws-modules/eks` module saves a lot of time here.

## Step 6 — IAM / OIDC module (for GitLab CI)

This is what lets the pipeline authenticate to AWS **without** static keys.

- [ ] Create the GitLab OIDC identity provider in IAM (issuer = your GitLab URL, e.g. `https://gitlab.com`).
- [ ] Create a deploy role that trusts the GitLab OIDC provider, scoped to **your**
      project (and optionally a branch/environment) via the `sub` condition.
- [ ] Attach least-privilege policies: push to ECR, describe/update EKS, read the
      needed Secrets Manager secrets.
- [ ] Output the role ARN (Phase 3 workflow uses it).

## Step 7 — Security module (KMS + Secrets Manager)

- [ ] KMS key (used to encrypt secrets / logs).
- [ ] A couple of placeholder secrets in Secrets Manager (e.g. app config).
- [ ] Restrict who can decrypt (the deploy role / app IRSA role only).

## Step 8 — Apply, verify, destroy-test

- [ ] `terraform plan` (review what will be created).
- [ ] `terraform apply` (build everything).
- [ ] `aws eks update-kubeconfig ...` then `kubectl get nodes` → nodes Ready.
- [ ] Confirm ECR repos exist, role ARN output present.
- [ ] `terraform destroy` (prove clean teardown) — then apply again for Phase 3.

## Definition of done — Phase 2

- [ ] `terraform apply` builds VPC + ECR + EKS + IAM/OIDC + KMS + Secrets cleanly.
- [ ] `terraform destroy` removes everything with no orphaned resources.
- [ ] `kubectl get nodes` shows EKS workers Ready.
- [ ] Outputs give ECR URIs, cluster name, and the deploy role ARN.

> **Teardown order:** once Phase 4 creates an ALB via the Load Balancer Controller,
> always delete the Kubernetes Ingress **first** and let the controller remove the
> ALB before running `terraform destroy`. Destroying EKS while the ALB still exists
> can orphan the ALB and keep billing. (See the runbook in `app/docs/`.)

**Skills hit:** Terraform (modules, remote state, apply/destroy), AWS VPC/networking,
EKS, IAM/OIDC, KMS, ECR — all as code.

**Next:** [PHASE-2.5.md](PHASE-2.5.md) — put Terraform itself behind a validated,
gated pipeline — then [PHASE-3.md](PHASE-3.md) — the app pipeline that fills this
environment.
