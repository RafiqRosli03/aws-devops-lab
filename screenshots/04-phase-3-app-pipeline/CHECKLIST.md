# 04 — Phase 3: Application CI/CD Pipeline

- [x] `P3-01-full-green-app-pipeline.png` — test → auth → build → deploy green; production manual. _(have: Full green application pipeline.png)_
- [x] `P3-02-node-test-job.png` — Node test success in GitLab. _(have: Node test CI log.png)_
- [x] `P3-03-python-test-job.png` — pytest success in GitLab. _(have: Python test CI log.png)_
- [x] `P3-04-oidc-ecr-login-job.png` — successful assumed deploy role and ECR auth; no credentials. _(have: OIDCECR authentication job.png)_
- [x] `P3-05-kaniko-orders-build-push.png` — orders image SHA/digest pushed. _(have: Kaniko image build (Build Order Node).png + Kaniko job executer log (Build Order node).png)_
- [x] `P3-06-kaniko-users-build-push.png` — users image SHA/digest pushed. _(have: Kaniko image Builder (Build Users python node).png + Kaniko job executer (Build python node).png)_
- [x] `P3-07-ecr-sha-tags.png` — matching SHA tags in both ECR repositories. _(have: Orders node ECR SHA tags.png, Users-python ECR SHA tags.png, the repository list from ECR.png)_
- [x] `P3-08-orders-deploy-rollout.png` — Kustomize apply, image update, rollout success. _(have: Deployment Job Success (orders-node).png)_
- [x] `P3-09-users-deploy-rollout.png` — Kustomize apply, image update, rollout success. _(have: Deployment Job Success (users-python).png)_
- [ ] `P3-10-orders-path-filter.png` — only orders jobs run after orders-only change. _(not captured)_
- [ ] `P3-11-users-path-filter.png` — only users jobs run after users-only change. _(not captured)_
- [ ] `P3-12-gitlab-environments.png` — dev environment and manual production gate. _(partially shown in the full-green pipeline; a dedicated environments view is not captured)_

## Suggested caption

> GitLab CI tests both language stacks, authenticates to AWS using OIDC, builds images with Kaniko, pushes immutable SHA tags to ECR, and rolls them out to EKS.
