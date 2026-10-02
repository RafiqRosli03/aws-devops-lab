# 08 — Teardown Evidence

Capture only after all live evidence is complete.

- [ ] `TD-01-k8s-resources-deleted.png` — Ingress/workloads removed.
- [ ] `TD-02-alb-deleted.png` — no remaining ALBs.
- [ ] `TD-03-terraform-destroy-complete.png` — final destroy summary.
- [ ] `TD-04-no-eks-clusters.png` — empty EKS list.
- [ ] `TD-05-no-available-nat.png` — no available NAT Gateways.
- [ ] `TD-06-guardduty-securityhub-removed.png` — Terraform-managed security services removed/disabled.
- [ ] `TD-07-state-backend-retained.png` — optional S3 state backend retained intentionally.

## Correct teardown order

```powershell
Set-Location app
kubectl delete -k k8s/base
kubectl delete svc -n dev --all --ignore-not-found

Set-Location "infra\envs\dev"
terraform destroy -var-file dev.tfvars
```

## Post-checks

```powershell
aws elbv2 describe-load-balancers --region ap-southeast-5 --query "LoadBalancers[].LoadBalancerName"
aws eks list-clusters --region ap-southeast-5
aws ec2 describe-nat-gateways --region ap-southeast-5 --filter "Name=state,Values=available" --query "NatGateways[].NatGatewayId"
```
