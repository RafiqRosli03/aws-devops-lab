# Phase 5 — Observability & Security Posture

**Goal:** see and secure the running platform — logs, metrics, alerts, and
account-level security posture. Defined in `infra/modules/observability/` + the EKS
addon.

## Logging + metrics — CloudWatch Container Insights
EKS addon `amazon-cloudwatch-observability` deploys the CloudWatch agent + Fluent Bit
as DaemonSets; the node group has `CloudWatchAgentServerPolicy`.

Log groups created:
- `/aws/containerinsights/devops-lab-dev/application` — container stdout
- `.../dataplane`, `.../host`, `.../performance` — cluster/node metrics
- `/aws/eks/devops-lab-dev/cluster`

**Verified:** found a log stream for the `users-python` pod (app stdout flowing).

## Dashboard — `devops-lab-dev-dashboard`
One CloudWatch dashboard (Terraform `aws_cloudwatch_dashboard`) with:
- Pod CPU utilization (Container Insights)
- Pod memory utilization
- ALB request count
- ALB 5xx error count

## Alerting — SNS + alarm
- SNS topic `devops-lab-dev-alerts` + email subscription
  (**requires confirming the subscription email** before delivery works)
- CloudWatch alarm `devops-lab-dev-alb-5xx`: fires when `HTTPCode_ELB_5XX_Count ≥ 1`
  in a 60s period → SNS

**Verified:** scaled orders-node to 0 → generated 70× HTTP 503 → the 5xx metric
recorded → alarm transitioned to **ALARM** → SNS notified. App then restored to 2/2.

## Security posture
- **GuardDuty** detector enabled in the region
- **Security Hub** enabled with **AWS Foundational Security Best Practices**; findings
  aggregating. (Inspector optional, not enabled.)

## Definition of Done — met
- [x] App + cluster logs in CloudWatch
- [x] One dashboard shows live health
- [x] An alarm fires on a simulated bad event → SNS
- [x] GuardDuty + Security Hub on with findings aggregated

## Note
GuardDuty and Security Hub are account/region-level — they continue to bill (small)
even after the cluster is destroyed, unless disabled. They are in Terraform, so
`terraform destroy` removes them.
