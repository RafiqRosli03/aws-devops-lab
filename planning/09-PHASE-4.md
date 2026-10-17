# Phase 4 — Kubernetes Hardening

> **Environment:** AWS / EKS.
> **Goal:** Turn a working deployment into a hardened, production-shaped one.

## Why this phase

Phase 3 gets the apps **running**. Phase 4 makes them run **safely**: least
privilege, restricted networking, non-root pods, real secrets, and autoscaling.

## Step 1 — Workload objects (per app)

- [ ] Deployment for `orders-node` (replicas ≥ 2).
- [ ] Deployment for `users-python` (replicas ≥ 2).
- [ ] Service (ClusterIP) for each app.
- [ ] Liveness + readiness probes hitting `/health`.
- [ ] Resource requests and limits (CPU/memory) on every container.

## Step 2 — Ingress (single ALB, path-based routing)

- [ ] Install the AWS Load Balancer Controller (IRSA-backed).
- [ ] One Ingress that creates **one** ALB and routes:
  - `/orders*` → `orders-node` Service
  - `/users*` → `users-python` Service
- [ ] HTTPS listener (ACM cert) if you have a domain; HTTP for a pure lab.

## Step 3 — RBAC (least privilege)

- [ ] A dedicated ServiceAccount per app (no default SA).
- [ ] Roles/RoleBindings granting **only** what each app needs (usually nothing cluster-wide).
- [ ] No workload uses `cluster-admin`.
- [ ] If a pod needs AWS access, use IRSA (IAM Roles for Service Accounts) — not node-wide credentials.

## Step 4 — Network policies (default deny)

- [ ] Default-deny ingress **and** egress in the app namespace.
- [ ] Allow ingress to each app **only** from the ALB/ingress controller.
- [ ] Allow egress **only** to what each app needs (DNS, and any dependency).
- [ ] Verify: a pod that isn't explicitly allowed cannot reach the app.

> EKS needs a CNI that enforces policies (e.g. Calico, or VPC CNI network-policy
> enforcement which is **off** by default) — install/enable if needed.

## Step 5 — Pod security context

- [ ] `runAsNonRoot: true`
- [ ] `readOnlyRootFilesystem: true` (mount a writable `emptyDir` if the app needs `/tmp`)
- [ ] `allowPrivilegeEscalation: false`
- [ ] Drop **all** Linux capabilities (add back only if strictly needed)
- [ ] `seccompProfile: RuntimeDefault`
- [ ] Enforce via Pod Security Admission (`restricted`) on the namespace.

## Step 6 — Secrets from Secrets Manager (no plaintext)

- [ ] Install the Secrets Store CSI Driver + AWS provider (or External Secrets).
- [ ] Mount the Phase-2 secrets into the pods at runtime.
- [ ] Confirm **no** plaintext secrets exist in manifests or Kubernetes Secrets.

## Step 7 — Autoscaling

- [ ] Horizontal Pod Autoscaler (HPA) on CPU for at least one app.
- [ ] Confirm the Metrics Server is installed (HPA needs it).
- [ ] Load-test lightly and watch replicas scale up, then back down when idle.

## Step 8 — Verify (prove the hardening works)

- [ ] Both apps reachable through the single ALB on `/orders` and `/users`.
- [ ] A pod spec that runs as root is **rejected** (Pod Security Admission).
- [ ] Network policy blocks a disallowed test pod from reaching an app.
- [ ] No plaintext secrets anywhere; secrets come from Secrets Manager.
- [ ] HPA scales a deployment under load and back down.

## Definition of done — Phase 4

- [ ] Both apps served through one ALB Ingress on their paths.
- [ ] Root / policy-violating pods are rejected by design.
- [ ] Network policy blocks traffic that isn't explicitly allowed.
- [ ] Secrets sourced from Secrets Manager (no plaintext).
- [ ] HPA autoscaling proven.

**Skills hit:** K8s deployments/services/ingress, RBAC, network policies, secrets,
pod security context, autoscaling.

**Next:** [10-PHASE-5.md](10-PHASE-5.md) — observe and secure the running platform.
