# Phase 4 — Kubernetes Hardening

**Goal:** turn the working deployment into a hardened, production-shaped one. Manifests
live in `k8s/base/` (Kustomize); the pipeline applies them.

## Workloads (`orders-node.yaml`, `users-python.yaml`)
- Deployment, **replicas: 2**, liveness + readiness probes on `/health`
- Resource requests + limits on every container
- ClusterIP Service per app (`:80` → container port)
- Dedicated ServiceAccount per app, `automountServiceAccountToken: false`

## Pod security context (satisfies PSA `restricted`)
- `runAsNonRoot: true`, `runAsUser: 1000`
- `readOnlyRootFilesystem: true` (+ writable `/tmp` emptyDir)
- `allowPrivilegeEscalation: false`
- `capabilities.drop: ["ALL"]`
- `seccompProfile: RuntimeDefault`

## Pod Security Admission (`namespace.yaml`)
`dev` namespace labelled `pod-security.kubernetes.io/enforce: restricted`.
**Verified:** a privileged root pod is rejected with `Forbidden`.

## RBAC (`rbac.yaml`)
Per-app Role with **no rules** (apps need no K8s API access) + RoleBinding to the SA.
No workload uses cluster-admin.

## NetworkPolicies (`networkpolicy.yaml`)
- `default-deny-all` (ingress + egress) for the namespace
- `allow-dns-egress` (UDP/TCP 53)
- `allow-app-ingress` to app ports 3000/8000
- **Enforcement:** VPC CNI `enableNetworkPolicy=true` set via the EKS addon (off by
  default). **Verified:** a test pod's egress to an app timed out (blocked).

## Ingress — single ALB (`ingress.yaml`)
AWS Load Balancer Controller (installed via Helm, IRSA role
`devops-lab-dev-alb-controller`) creates one internet-facing ALB routing
`/orders → orders-node`, `/users → users-python`. **Verified:** both return 200.
HTTP only (HTTPS needs a real domain + ACM cert — future work).

## HPA (`hpa.yaml`)
CPU-based, 2→5 replicas at 60% utilization, for both apps. metrics-server installed.
**Verified:** HPAs report live CPU (e.g. 2%/60%).

## EKS access entry (fixes Phase 3 kubectl auth)
Terraform grants the `gitlab-deploy` role `AmazonEKSClusterAdminPolicy` via an EKS
access entry so the pipeline's `kubectl` is authorized.

## Pipeline integration
Deploy stage now runs `kubectl apply -k k8s/base` (declarative source of truth) then
`kubectl set image` to the exact SHA built this run.

## Definition of Done — met
- [x] Both apps served through one ALB on their paths
- [x] Root / policy-violating pods rejected by PSA
- [x] NetworkPolicy blocks disallowed traffic
- [x] Secrets not plaintext (no K8s Secrets; SA token automount off)
- [x] HPA autoscaling in place

## Install notes (one-time cluster setup, not in the app pipeline)
- AWS Load Balancer Controller via Helm (`eks/aws-load-balancer-controller`)
- metrics-server via upstream manifest
- Both die with the cluster on teardown.
