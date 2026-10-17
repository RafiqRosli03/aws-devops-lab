# Phase 5 — Cloud Posture & Observability

> **Environment:** AWS / EKS.
> **Goal:** See and secure the running platform — logs, metrics, alerts, and
> account-level security posture.

## Why this phase

A pipeline that deploys is not enough; you must **see** what's running and be
**alerted** when something is wrong. This phase adds observability and cloud security
posture, and confirms cost-clean teardown.

## Step 1 — Logging (app + cluster → CloudWatch)

- [ ] Enable Fluent Bit / CloudWatch Container Insights on the cluster.
- [ ] App logs (stdout) flow to CloudWatch Log groups.
- [ ] Confirm you can find a specific request in the logs.

## Step 2 — Metrics + dashboard

- [ ] Enable Container Insights metrics (pod/node CPU, memory).
- [ ] Build **one** CloudWatch dashboard showing:
  - pod CPU / memory per app
  - ALB request count
  - ALB 5xx error rate
- [ ] *(Stretch)* Prometheus + Grafana for richer Kubernetes metrics.

## Step 3 — Alerting

- [ ] Create an SNS topic + subscribe your email.
- [ ] One CloudWatch alarm on a meaningful signal, e.g.:
  - ALB 5xx error rate above a threshold, **or**
  - pod restart spike / CrashLoopBackOff
- [ ] Alarm → SNS → email notification.
- [ ] Test it: cause a failure and confirm the alert arrives.

## Step 4 — Cloud security posture (CSPM)

- [ ] Enable GuardDuty in the region.
- [ ] Enable Security Hub; connect standards (e.g. AWS Foundational Security Best Practices).
- [ ] Review findings in Security Hub as a single pane.
- [ ] *(Optional)* Enable Inspector to scan the EKS nodes / ECR images for CVEs.

## Step 5 — Cost hygiene + teardown

- [ ] Confirm `terraform destroy` removes EKS, NAT, ALB, node group cleanly.
- [ ] Check Cost Explorer: no lingering ALB / NAT / EKS charges after destroy.
- [ ] Document the "apply at start, destroy at end" session habit.

## Step 6 — Verify

- [ ] App + cluster logs visible in CloudWatch.
- [ ] Dashboard shows live app/infra health.
- [ ] An alarm fires on a simulated bad event and emails you via SNS.
- [ ] GuardDuty + Security Hub enabled with findings aggregated.
- [ ] `terraform destroy` leaves no billable resources behind.

## Definition of done — Phase 5 (and the whole project)

- [ ] App and cluster logs in CloudWatch.
- [ ] One dashboard shows live health; one alarm notifies via SNS.
- [ ] GuardDuty + Security Hub on with aggregated findings.
- [ ] `terraform destroy` = zero leftover billable resources.

**Whole-project done:**

- [ ] `git push` → pipeline → both apps live on EKS, no manual steps.
- [ ] Entire environment from Terraform alone.
- [ ] Hardened workloads (RBAC, netpol, non-root, no plaintext secrets).
- [ ] Observability + security posture in place.

**Skills hit:** logging/metrics/tracing, security monitoring, CSPM concepts,
alerting, cost control.

> **Write-up:** document what each control defends against and demo the pipeline end
> to end. This becomes your portfolio centerpiece.
