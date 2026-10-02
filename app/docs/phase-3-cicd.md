# Phase 3 — CI/CD Pipeline (GitLab CI)

**Goal:** every push builds, tests, pushes images, and deploys both apps to EKS —
with no long-lived AWS keys. Defined in `.gitlab-ci.yml`.

## Authentication — OIDC, no static keys

GitLab mints a short-lived OIDC ID token (`id_tokens`, audience `https://gitlab.com`).
Jobs call `aws sts assume-role-with-web-identity` to assume the **narrow**
`devops-lab-dev-gitlab-deploy` role (ECR push/pull, `eks:DescribeCluster`, read
secrets). The role's trust policy is scoped to `project_path:RafiqRosli03/devops-lab:*`.

Required CI/CD variable: `AWS_ROLE_ARN = arn:aws:iam::497862079645:role/devops-lab-dev-gitlab-deploy`

## Stages (app pipeline, triggered by `apps/**` changes)

| Stage | Image | What |
|-------|-------|------|
| test | node:20 / python:3.12 | `npm test` / `pytest`; path filters so only the changed app runs |
| auth (ecr-login) | amazon/aws-cli | assume role, `ecr get-login-password`, write Docker auth as a short-lived artifact |
| build | kaniko (debug) | rootless image build, push to ECR tagged by **git SHA** (immutable) |
| deploy | amazon/aws-cli + kubectl | `kubectl apply -k k8s/base` then `set image` to the new SHA (dev, auto) |
| deploy-prod | " | same, **manual gate** (`when: manual`) to a `prod` namespace |

## Design decisions / gotchas (all real, hit during build)

1. **Kaniko and kubectl images have no AWS CLI.** First attempt failed. Fixed by doing
   AWS auth in an `amazon/aws-cli` job: `ecr-login` writes the Docker config as an
   artifact that Kaniko consumes; the deploy job installs a static kubectl binary.
2. **pytest import error in CI** (`ModuleNotFoundError: app`). Fixed by adding
   `pyproject.toml` with `pythonpath=["."]` (Phase 1 note).
3. **EKS authorization** — `kubectl` failed with "Unauthorized" because the deploy role
   had IAM access to the API but **no Kubernetes RBAC**. Fixed with an EKS **access
   entry** mapping the deploy role to `AmazonEKSClusterAdminPolicy` (added in Terraform,
   see Phase 4 doc).
4. **ECR is IMMUTABLE** → tag by git SHA, never overwrite. Enables exact rollback.

## Definition of Done — met
- [x] A push changing one app rebuilds/deploys only that app (path filters)
- [x] Images land in ECR tagged by git SHA
- [x] Both apps auto-deploy to dev; prod requires manual approval
- [x] No static AWS credentials anywhere (OIDC only)

## Verified
Full pipeline run `test → auth → build → deploy` went green for both apps; pods
confirmed Running in the `dev` namespace, pulled from ECR by SHA.
