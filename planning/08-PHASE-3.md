# Phase 3 — CI/CD Pipeline (GitLab CI)

> **Environment:** GitLab CI → AWS (via OIDC). This is the heart of the project.
> **Goal:** Every `git push` builds, tests, pushes images, and deploys **both** apps
> to EKS automatically — with no long-lived AWS keys.

## Why this phase

This is the "DevOps" part. Manual deploys don't scale and aren't repeatable. The
pipeline turns a `git push` into a tested, deployed application automatically.

## Step 1 — OIDC auth (no static keys)

GitLab CI authenticates to AWS using OIDC ID tokens (GitLab is the identity provider;
AWS IAM trusts it). No stored AWS keys.

- [ ] In `.gitlab-ci.yml`, request an OIDC token via the `id_tokens:` keyword (audience = `sts.amazonaws.com`).
- [ ] Use that token with `aws sts assume-role-with-web-identity` (or the configure step) to assume the Phase-2 deploy role ARN.
- [ ] The IAM role trust policy must reference the GitLab OIDC provider and be scoped to your project/branch (the `sub` claim).
- [ ] Confirm a test job can run `aws sts get-caller-identity` successfully.

**Result:** zero AWS access keys stored anywhere in the repo or GitLab CI/CD vars.

## Step 2 — Pipeline triggers + change rules

- [ ] Run on commits to `main` and on merge requests (`workflow:rules` / `rules`).
- [ ] Use `rules: changes:` so only the changed app rebuilds:
  - `apps/orders-node/**` → Node jobs
  - `apps/users-python/**` → Python jobs
- [ ] A change to shared infra can rebuild both (your choice).

## Step 3 — Build & test stage (per app)

**Node job** (`image: node:20`):

- [ ] `npm ci` (with GitLab cache on `node_modules` / npm cache).
- [ ] `npm test` (lint + unit tests).

**Python job** (`image: python:3.12`):

- [ ] `pip install` (with GitLab cache on the pip cache dir).
- [ ] `pytest` (+ a linter like ruff/flake8).

**Both:**

- [ ] If tests fail, the pipeline **stops** here (gate #1 — quality).

## Step 4 — Package stage (per app)

- [ ] Log in to ECR (via the OIDC role).
- [ ] `docker build` the app image.
- [ ] Tag with the git SHA (immutable) and optionally `latest` for dev.
- [ ] `docker push` to the app's ECR repo.
- [ ] Pass the image tag to the deploy stage (dotenv artifact / job variable).

> Build images with Kaniko or `docker:dind` in GitLab CI. Kaniko is the common
> rootless choice for building without a privileged Docker daemon.

**Why git SHA tags:** every deploy maps to an exact commit; easy rollback.

## Step 5 — Deploy stage (to EKS)

- [ ] `aws eks update-kubeconfig` for the cluster (Phase 2 output).
- [ ] Deploy each app with `kubectl apply` (or `helm upgrade --install`), passing the new image tag.
- [ ] Deploy to the `dev` namespace **automatically**.
- [ ] Secrets: the deploy pulls app secrets from Secrets Manager at deploy time — nothing hardcoded.

## Step 6 — Environment promotion + gating

- [ ] Define GitLab environments: `dev` (auto) and `prod` (gated).
- [ ] The prod deploy job uses `when: manual` (+ optionally a protected environment with approvers) so promotion needs a click.
- [ ] This demonstrates: dev auto-deploy, prod gated deploy.

## Step 7 — Caching & speed

- [ ] GitLab cache for npm and pip dependencies (keyed by lockfile).
- [ ] Optional: Docker layer caching (Kaniko cache) to speed image builds.

## Step 8 — Verify the whole pipeline

- [ ] Push a change to **only** the Node app → only the Node job runs and deploys.
- [ ] Confirm the image appears in ECR tagged by SHA.
- [ ] Confirm the app updates in the `dev` namespace (`kubectl get pods`).
- [ ] Trigger a prod promotion → confirm it waits for manual approval.
- [ ] Confirm no AWS keys exist anywhere (OIDC only).

## Definition of done — Phase 3

- [ ] A push changing only one app rebuilds/deploys only that app.
- [ ] Images land in ECR tagged by git SHA.
- [ ] Both apps auto-deploy to `dev`; prod requires manual approval.
- [ ] No static AWS credentials anywhere (OIDC only).

**Skills hit:** CI/CD stages, artifacts, caching, environment promotion, gating,
secrets handling, OIDC-to-cloud.

**Next:** [09-PHASE-4.md](09-PHASE-4.md) — harden the running Kubernetes workloads.
