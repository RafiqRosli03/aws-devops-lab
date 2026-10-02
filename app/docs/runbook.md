# Runbook — Apply, Verify, Teardown

Operational procedure for the lab. **The environment is not meant to run 24/7** —
apply at the start of a session, destroy at the end.

## Prerequisites
- AWS CLI configured for account `497862079645` (`aws sts get-caller-identity`)
- Terraform ≥ 1.10, kubectl, Helm, Docker
- Region `ap-southeast-5`

## Bring up (session start)

```bash
# 1. State backend (only the very first time)
cd infra/bootstrap && terraform init && terraform apply

# 2. Main environment (~15-20 min, EKS is slow)
cd ../envs/dev
terraform init
terraform apply -var-file dev.tfvars

# 3. Connect kubectl
aws eks update-kubeconfig --region ap-southeast-5 --name devops-lab-dev
kubectl get nodes

# 4. One-time cluster add-ons (not managed by the app pipeline)
helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --set clusterName=devops-lab-dev --set region=ap-southeast-5 \
  --set vpcId=<vpc-id> --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::497862079645:role/devops-lab-dev-alb-controller
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 5. Deploy the hardened app manifests (or let the GitLab pipeline do it)
kubectl apply -k k8s/base
```

## Verify

```bash
kubectl get pods -n dev                 # 2 per app, Running
kubectl get ingress -n dev              # ALB address
kubectl get hpa -n dev                  # CPU targets
curl http://<alb>/orders ; curl http://<alb>/users   # 200
```

## Tear down (session end — stops the bill)

**Order matters.** The ALB is created by the Kubernetes Ingress, not Terraform —
delete it first or it's orphaned and keeps billing.

```bash
# 1. Remove k8s objects (deletes the ALB via the Ingress) + any manual LB services
kubectl delete -k k8s/base
kubectl delete svc -n dev --all --ignore-not-found

# 2. Destroy all Terraform-managed infra (cluster, VPC, NAT, ECR, KMS,
#    GuardDuty, Security Hub, dashboard, SNS, alarm)
cd infra/envs/dev
terraform destroy -var-file dev.tfvars

# 3. (Optional) leave the bootstrap S3/DynamoDB — near-free, needed next time
```

### Post-teardown check (confirm nothing left billing)
```bash
aws elbv2 describe-load-balancers --region ap-southeast-5 --query "LoadBalancers[].LoadBalancerName"
aws ec2 describe-nat-gateways --region ap-southeast-5 --filter Name=state,Values=available
aws eks list-clusters --region ap-southeast-5
```
All should be empty.

## Cost reference

| Resource | ~Hourly | ~Monthly if 24/7 |
|----------|---------|------------------|
| EKS control plane | $0.10 | ~$73 |
| worker nodes (t3.small) | $0.025 ea | ~$18 ea |
| NAT Gateway | $0.045 + data | ~$33 |
| ALB | $0.025 | ~$18 |
| GuardDuty + Security Hub | usage | ~$5-15 |
| **Running total** | **~$0.28/hr (~RM1.30)** | **~$210 (~RM1,000)** |

**Watch item:** desired node count is 2; failed applies once left it at 4. Check
`kubectl get nodes` and reconcile with `terraform apply` if needed.
