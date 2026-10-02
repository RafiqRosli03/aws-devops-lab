# 05 — Phase 4: Kubernetes Hardening

- [ ] `P4-01-deployments-pods-services-ready.png` — 2/2 Deployments, Ready pods, ClusterIP Services.
- [ ] `P4-02-single-alb-ingress.png` — one Ingress with public ALB address.
- [ ] `P4-03-orders-users-same-alb.png` — `/orders` and `/users` using the same ALB DNS.
- [ ] `P4-04-aws-alb-active-listener.png` — AWS ALB Active, internet-facing, HTTP:80.
- [ ] `P4-05-alb-target-groups-healthy.png` — healthy pod IP targets.
- [ ] `P4-06-lb-controller-pods-running.png` — controller pods Running.
- [ ] `P4-07-security-context-code.png` — non-root, read-only, no escalation, drop ALL, seccomp.
- [ ] `P4-08-psa-root-pod-rejected.png` — restricted PSA `Forbidden` result.
- [ ] `P4-09-namespace-psa-labels.png` — `enforce=restricted` label.
- [ ] `P4-10-serviceaccounts-rbac.png` — dedicated SAs, Roles, RoleBindings.
- [ ] `P4-11-rbac-cannot-get-pods.png` — `kubectl auth can-i` returns `no` for app SA.
- [ ] `P4-12-networkpolicies-list.png` — deny-all, DNS egress, app ingress.
- [ ] `P4-13-vpc-cni-network-policy-enabled.png` — `--enable-network-policy=true`.
- [ ] `P4-14-networkpolicy-blocked-timeout.png` — curl exit 28/timeout from test pod.
- [ ] `P4-15-hpa-live-cpu.png` — HPA CPU targets and 2–5 range.
- [ ] `P4-16-no-plaintext-k8s-secrets.png` — no app secrets in dev namespace.

## Useful commands

```powershell
kubectl get deployments,pods,services -n dev -o wide
kubectl get ingress -n dev
kubectl get hpa -n dev
kubectl get namespace dev --show-labels
kubectl get serviceaccounts,roles,rolebindings -n dev
kubectl auth can-i --as=system:serviceaccount:dev:orders-node get pods -n dev
kubectl get networkpolicy -n dev
kubectl get secrets -n dev
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```
