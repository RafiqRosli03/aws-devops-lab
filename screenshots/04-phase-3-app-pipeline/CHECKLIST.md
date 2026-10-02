# 04 — Phase 3: Application CI/CD Pipeline

- [ ] `P3-01-full-green-app-pipeline.png` — test → auth → build → deploy green; production manual.
- [ ] `P3-02-node-test-job.png` — Node test success in GitLab.
- [ ] `P3-03-python-test-job.png` — pytest success in GitLab.
- [ ] `P3-04-oidc-ecr-login-job.png` — successful assumed deploy role and ECR auth; no credentials.
- [ ] `P3-05-kaniko-orders-build-push.png` — orders image SHA/digest pushed.
- [ ] `P3-06-kaniko-users-build-push.png` — users image SHA/digest pushed.
- [ ] `P3-07-ecr-sha-tags.png` — matching SHA tags in both ECR repositories.
- [ ] `P3-08-orders-deploy-rollout.png` — Kustomize apply, image update, rollout success.
- [ ] `P3-09-users-deploy-rollout.png` — Kustomize apply, image update, rollout success.
- [ ] `P3-10-orders-path-filter.png` — only orders jobs run after orders-only change.
- [ ] `P3-11-users-path-filter.png` — only users jobs run after users-only change.
- [ ] `P3-12-gitlab-environments.png` — dev environment and manual production gate.

## Suggested caption

> GitLab CI tests both language stacks, authenticates to AWS using OIDC, builds images with Kaniko, pushes immutable SHA tags to ECR, and rolls them out to EKS.
