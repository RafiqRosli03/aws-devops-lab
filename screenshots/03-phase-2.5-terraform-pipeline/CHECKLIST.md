# 03 — Phase 2.5: Terraform CI/CD Pipeline

- [x] `P2-5-01-infra-pipeline-overview.png` — `tf:validate` and `tf:plan` green, `tf:apply` manual. _(have: Green Infrastructure Pipeline.png)_
- [x] `P2-5-02-tf-validate-job-log.png` — init/fmt/validate and success. _(have: Terraform Validate log.png)_
- [x] `P2-5-03-tf-plan-job-log.png` — final plan summary or `No changes`. _(have: Terraform plan job log.png)_
- [x] `P2-5-04-manual-apply-gate.png` — play button/manual action visible. _(have: Terraform Apply with manual toggle.png)_
- [x] `P2-5-05-terraform-oidc-identity.png` — assumed Terraform role evidence; redact account ID. _(have: OIDC Token Credentials.png)_

## Suggested caption

> Terraform CI/CD automatically validates and plans infrastructure changes while keeping apply behind human approval and using temporary OIDC credentials.

Do not screenshot GitLab CI/CD variable values or the OIDC token.
