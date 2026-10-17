# 06 — Phase 5: Observability and Security

> Status: no screenshots captured in this folder yet — all items below are pending.

- [ ] `P5-01-cloudwatch-addon-active.png` — EKS CloudWatch observability add-on Active.
- [ ] `P5-02-cloudwatch-agent-pods.png` — controller/agents Running.
- [ ] `P5-03-container-insights-log-groups.png` — application/dataplane/host/performance groups.
- [ ] `P5-04-real-app-log-stream.png` — orders/users pod log stream and safe event.
- [ ] `P5-05-cloudwatch-dashboard-overview.png` — CPU, memory, ALB requests, 5xx widgets.
- [ ] `P5-06-alarm-ok-state.png` — normal ALB 5xx alarm state and threshold.
- [ ] `P5-07-alarm-history-ok-to-alarm.png` — controlled test transition to ALARM.
- [ ] `P5-08-sns-subscription-confirmed.png` — SNS subscription Confirmed; hide email.
- [ ] `P5-09-guardduty-enabled-summary.png` — GuardDuty detector/summary.
- [ ] `P5-10-security-hub-summary.png` — findings and severity summary.
- [ ] `P5-11-security-hub-fsbp-standard.png` — AWS Foundational Security Best Practices enabled.
- [ ] `P5-12-cost-explorer-services.png` — cost by service/date range after billing data appears.

## Useful commands

```powershell
kubectl get pods -n amazon-cloudwatch
aws cloudwatch describe-alarms --region ap-southeast-5
aws guardduty list-detectors --region ap-southeast-5
aws securityhub describe-hub --region ap-southeast-5
```

Do not create a real attack for the GuardDuty screenshot. Use the enabled dashboard and existing findings.
