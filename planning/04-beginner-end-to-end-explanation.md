# AWS DevOps Lab — Beginner End-to-End Explanation

This document explains the complete AWS DevOps project in simple words: what was built, how every part connects, how both CI/CD workflows operate, what happens when a user opens the application, how the platform is protected and monitored, and what a DevOps engineer normally does.

For detailed implementation commands and exact resource records, also see `app/DOCUMENTATION.md` and `app/docs/`.

---

## 1. The project in one sentence

We built two small applications, packed them into Docker containers, created an AWS environment for them, and built automatic pipelines that test, package, deploy, monitor, and protect them whenever the code or infrastructure changes.

The two applications are:

1. **Orders application** — Node.js + Express
2. **Users application** — Python + FastAPI

The applications are deliberately simple. The main learning goal is the delivery system around them.

---

## 2. Easy analogy: a small city and delivery factory

Think of the project as building and operating a small city.

| Project component | Easy meaning |
|---|---|
| Application code | Workers doing business tasks |
| GitLab repository | Official book containing every approved plan |
| Git commit | A numbered version of the plan |
| CI/CD pipeline | Automatic testing factory and delivery team |
| Docker image | A sealed box containing the app and its requirements |
| Container | A running copy of that sealed box |
| Amazon ECR | Secure warehouse for Docker images |
| Kubernetes / EKS | City manager that runs, replaces, and scales containers |
| Pod | One running copy of an app |
| Deployment | Instructions saying how many copies must run |
| Service | Stable internal reception desk for changing pods |
| ALB / Ingress | Public front gate and traffic officer |
| VPC | Private land and road network |
| Public subnet | Road area that can face the internet |
| Private subnet | Protected area for worker machines |
| NAT Gateway | One-way internet exit for private machines |
| IAM role | Job badge containing permissions |
| OIDC | Temporary visitor pass proving GitLab's identity |
| Terraform | Blueprint and automatic construction machine |
| Terraform state | Terraform's record of what it already built |
| CloudWatch | Cameras, meters, logs, dashboard, and alarms |
| GuardDuty | Security guard looking for suspicious activity |
| Security Hub | Central security findings board |
| KMS | Encryption key-management room |
| Secrets Manager | Locked cabinet for passwords and secret values |

The main idea is:

> **Terraform builds the AWS city. GitLab delivers the applications. Kubernetes operates them. CloudWatch watches them. AWS security services detect and report security problems.**

---

## 3. Complete architecture

```text
Developer changes code
        |
        v
Git commit and push to GitLab
        |
        +--------------------------------+
        |                                |
        | apps/** changed                | infra/** changed
        v                                v
APPLICATION PIPELINE              INFRASTRUCTURE PIPELINE
Test                              Format and validate
Authenticate to AWS               Read remote state
Build Docker image                Terraform plan
Push image to ECR                 Manual approval
Deploy to EKS                     Terraform apply
        |                                |
        +----------------+---------------+
                         |
                         v
                  AWS environment
                         |
               Public ALB Ingress
                    /          \
               /orders        /users
                  |              |
           orders Service   users Service
                  |              |
             Node pods      Python pods
                         |
                         v
       CloudWatch + GuardDuty + Security Hub
```

There are two independent workflows in one `.gitlab-ci.yml` file:

- The **application workflow** handles source-code changes.
- The **infrastructure workflow** handles Terraform changes.

They are separated because infrastructure changes are more powerful and dangerous than normal application changes.

---

# Part A — Build phases

## 4. Phase 1 — Applications and tests

### Orders application

The Node.js/Express application provides:

- `GET /health` — confirms it is alive;
- `GET /orders` — returns orders;
- `POST /orders` — creates an order;
- `/` — displays a simple page.

### Users application

The Python/FastAPI application provides:

- `GET /health`;
- `GET /users`;
- `POST /users`;
- `/docs` — interactive API documentation.

Both use in-memory data. Data disappears when a container restarts. This is suitable for a learning lab, but a real production system needs a database.

### Automated tests

Tests are small exams for the code. They check things such as:

- Does `/health` return HTTP 200?
- Can valid data be created?
- Is invalid data rejected?

Orders uses Node's test runner. Users uses pytest. If tests fail, the pipeline stops before deployment.

---

## 5. Phase 1 — Docker containers

Docker prevents the common problem: “It works on my laptop but not on the server.”

A Docker image contains the application, runtime, libraries, and startup command. Running the image creates a container.

Both apps use multi-stage builds:

1. **Build stage:** install dependencies and run tests.
2. **Runtime stage:** copy only files needed to run.

Both containers run as a normal Linux user instead of root. This reduces possible damage if an application is compromised.

Docker Compose starts both locally:

```text
orders-node  -> localhost:3000
users-python -> localhost:8000
```

---

## 6. Phase 2 — AWS infrastructure with Terraform

Terraform is Infrastructure as Code. Instead of manually clicking many AWS Console buttons, text files describe the required infrastructure.

### Main commands

| Command | Meaning |
|---|---|
| `terraform init` | Prepare Terraform and download required providers/modules |
| `terraform fmt` | Format files neatly |
| `terraform validate` | Check configuration structure |
| `terraform plan` | Show proposed changes without applying them |
| `terraform apply` | Make AWS match the approved plan |
| `terraform destroy` | Remove Terraform-managed infrastructure |

### Terraform state

Terraform state is Terraform's memory. It records which AWS resources belong to the configuration.

State is stored in an encrypted, versioned S3 bucket with public access blocked. Native state locking prevents two Terraform operations from changing the same state simultaneously.

The state bucket must be created first by `infra/bootstrap`. After bootstrap, the main environment can use remote state.

### Network

Terraform creates:

- one VPC (`10.0.0.0/16`);
- two public subnets;
- two private subnets;
- Internet Gateway;
- NAT Gateway;
- route tables.

The ALB uses public subnets because internet users must reach it. EKS worker nodes use private subnets so they are not directly exposed.

### ECR

ECR is the private Docker-image warehouse. It contains separate repositories for `orders-node` and `users-python`.

Images use immutable Git SHA tags. For example:

```text
users-python:04c1edad
```

This means a running image can be traced to the exact Git commit that produced it.

### EKS

EKS is AWS-managed Kubernetes. Kubernetes maintains the requested number of application copies, restarts failed pods, sends traffic only to ready pods, performs rolling updates, and supports autoscaling.

### KMS and Secrets Manager

KMS manages encryption keys. Secrets Manager stores secret values outside source code.

The lab creates secret placeholders, but the current applications do not need actual secrets and do not mount them. A production system would connect Secrets Manager using the Secrets Store CSI Driver or External Secrets.

---

# Part B — CI/CD workflows

## 7. What CI/CD means

**Continuous Integration (CI)** means every change is automatically checked and tested.

**Continuous Delivery/Deployment (CD)** means tested software can be automatically delivered to an environment.

This project automatically deploys to development. Production is intended to require human approval.

---

## 8. How GitLab selects work

This is a monorepo containing applications, infrastructure, Kubernetes manifests, and pipeline configuration.

Path rules select jobs:

- `apps/orders-node/**` change → orders jobs;
- `apps/users-python/**` change → users jobs;
- `infra/**` change → Terraform jobs.

This saves time by avoiding unrelated builds.

---

## 9. Infrastructure pipeline workflow

```text
Terraform code changed
        |
        v
Push or merge request
        |
        v
tf:validate
        |
        v
tf:plan
        |
        v
Human reviews proposed changes
        |
        v
tf:apply manual approval
        |
        v
AWS changes
```

### Validate

Checks formatting and configuration validity. It catches syntax and reference errors before AWS is changed.

### Plan

Terraform compares:

1. code — what should exist;
2. remote state — what Terraform remembers;
3. AWS — what really exists.

It then produces a proposed plan such as:

```text
Plan: 2 to add, 1 to change, 0 to destroy
```

An engineer must inspect this carefully, especially any resource marked for deletion or replacement.

### Plan artifact and manual apply

The saved plan is passed to the apply job as a short-lived artifact. The apply job waits for a person to click the manual button.

Infrastructure receives a manual gate because one mistake can affect networking, IAM, EKS, or the entire environment.

### Infrastructure OIDC role

GitLab uses `devops-lab-dev-gitlab-terraform`, a powerful temporary role used only for infrastructure.

OIDC workflow:

1. GitLab creates a signed identity token.
2. AWS confirms it belongs to the approved GitLab project.
3. AWS gives temporary credentials.
4. Credentials expire after the job.

This is safer than storing permanent AWS access keys.

---

## 10. Application pipeline workflow

```text
Application changed
        |
        v
Push to GitLab
        |
        v
1. Run tests
        |
        v
2. Authenticate to AWS and ECR
        |
        v
3. Build Docker image with Kaniko
        |
        v
4. Push Git-SHA image to ECR
        |
        v
5. Apply Kubernetes manifests
        |
        v
6. Update deployment to the new image
        |
        v
7. Wait for successful rollout
```

### Test stage

Node uses `npm ci` and `npm test`. Python installs requirements and runs pytest. Any failure stops the flow.

### Authentication stage

The `ecr-login` job assumes the narrower `devops-lab-dev-gitlab-deploy` role using OIDC. It requests an ECR login token and creates a short-lived Docker authentication artifact.

### Build stage

Kaniko reads each Dockerfile, builds the image without a privileged Docker daemon, applies the Git SHA tag, and pushes the result to ECR.

### Deploy stage

The job:

1. assumes the deployment role;
2. downloads kubectl;
3. creates kubeconfig for `devops-lab-dev`;
4. applies `k8s/base` using Kustomize;
5. changes the affected Deployment to the newly built SHA image;
6. waits up to 180 seconds for rollout success.

A successful command is not enough. `kubectl rollout status` waits until Kubernetes reports that the new pods are healthy.

### Two authorization doors

EKS has two permission layers:

1. AWS IAM decides whether the role may contact EKS.
2. Kubernetes authorization decides what that identity may do inside the cluster.

The first deployment initially failed because IAM worked but Kubernetes did not recognize the role. An EKS access entry fixed it.

### Production limitation

The current Kustomize base hardcodes namespace `dev`. Although manual production jobs exist, there is no real production overlay. Proper production support needs separate `k8s/overlays/dev` and `k8s/overlays/prod` configurations.

---

# Part C — Kubernetes runtime

## 11. Kubernetes objects

### Pod

A pod is the smallest running unit. Each app pod contains one application container.

### Deployment

A Deployment says, “Keep this number of healthy copies running.” Each application requests two replicas. If one pod crashes, Kubernetes creates another.

### Service

Pod IP addresses change when pods are replaced. A Service provides one stable internal name and distributes traffic to healthy matching pods.

### Ingress and ALB

Ingress contains public routing rules:

```text
/orders -> orders-node Service
/users  -> users-python Service
```

The AWS Load Balancer Controller reads the Ingress and creates an AWS Application Load Balancer.

### HPA

The Horizontal Pod Autoscaler observes CPU usage. It maintains between two and five pods, targeting approximately 60% CPU utilization.

---

## 12. Kubernetes security

### Pod Security Admission

The `dev` namespace enforces the restricted profile. It rejects dangerous pods that run as root, use privileged mode, allow privilege escalation, retain unnecessary Linux capabilities, or lack an approved seccomp profile.

A privileged root pod was tested and correctly rejected.

### Container controls

Application containers use:

- `runAsNonRoot: true`;
- UID 1000;
- read-only root filesystem;
- `allowPrivilegeEscalation: false`;
- all Linux capabilities dropped;
- RuntimeDefault seccomp;
- writable temporary `/tmp` volume only.

### RBAC

Each application has its own ServiceAccount. Because the apps do not call the Kubernetes API, their Roles contain no permissions.

### NetworkPolicies

The namespace has default-deny networking, DNS egress allowance, and application-port allowances. VPC CNI network-policy enforcement was enabled because it is disabled by default.

A test pod was unable to reach an app and timed out, proving enforcement worked.

Current limitation: ingress on app ports is allowed from any source instead of being precisely restricted to the intended ALB path.

### IRSA

The AWS Load Balancer Controller uses a dedicated ServiceAccount and IAM role. It receives only the AWS permissions required to manage load balancers instead of giving those permissions to every workload.

---

# Part D — Browser request workflow

## 13. What happens when a user opens `/orders`

1. The browser resolves the ALB DNS name.
2. The request reaches the public ALB.
3. The ALB reads the Ingress rules.
4. `/orders` selects the orders backend.
5. The request is sent to a healthy orders pod.
6. Express processes it and returns JSON.
7. The response travels through the ALB back to the browser.
8. Logs and metrics are sent to CloudWatch.

The `/users` request follows the same path to the FastAPI pods.

### Health probes

- **Liveness probe:** asks if the app is alive; repeated failure causes restart.
- **Readiness probe:** asks if the app can receive traffic; failure temporarily removes it from service traffic.

---

# Part E — Monitoring and security detection

## 14. CloudWatch

CloudWatch receives application logs, pod/node metrics, ALB metrics, and alarm data.

The dashboard displays:

- pod CPU;
- pod memory;
- ALB request count;
- ALB 5xx count.

### Alarm workflow

The alarm was tested by scaling orders-node to zero pods and sending requests:

```text
No healthy pods
      -> ALB returns HTTP 503
      -> CloudWatch records 5xx
      -> alarm changes from OK to ALARM
      -> SNS sends notification
      -> application restored to 2 replicas
```

The SNS email subscription must be confirmed through AWS's email before email delivery works.

## 15. GuardDuty and Security Hub

GuardDuty watches AWS activity for suspicious behavior. It detects and reports; it is not a firewall.

Security Hub gathers security findings and evaluates AWS Foundational Security Best Practices in one central location.

Inspector was optional in the plan but is not enabled in the current implementation.

---

# Part F — Failures and recovery

## 16. What happens when something fails

| Failure | Result |
|---|---|
| Unit test fails | Pipeline stops before image build |
| Docker build fails | No new image reaches ECR |
| Deployment fails | GitLab job fails; old healthy version may remain |
| Pod crashes | Deployment creates a replacement |
| App is alive but not ready | Readiness probe removes it from traffic |
| CPU increases | HPA can create more pods |
| ALB produces 5xx errors | CloudWatch alarm sends SNS notification |

### Rollback

Because image tags are immutable Git SHAs, a known-good old image can be selected and redeployed. This gives exact version traceability.

---

# Part G — Teardown and cost

## 17. Safe teardown order

1. Delete Kubernetes Ingress and manifests.
2. Wait for the Load Balancer Controller to delete the ALB.
3. Run `terraform destroy` for the main environment.
4. Confirm EKS, NAT Gateway, and ALB are gone.
5. Optionally keep the near-free state backend.

Ingress must be removed first. If the EKS cluster is destroyed before the controller removes the ALB, the ALB could remain orphaned and continue billing.

The fully running lab is approximately RM1.30 per hour depending on usage. IaC makes it possible to destroy the environment and rebuild it later.

---

# Part H — Generic DevOps engineer process

## 18. What DevOps means

DevOps joins software development and system operations into one repeatable process.

A DevOps engineer builds a safe road from an idea to a working service. That road should be automatic, repeatable, secure, observable, recoverable, and cost-aware.

## 19. Generic DevOps lifecycle

### 1. Understand requirements

Ask what the application does, who uses it, expected traffic, availability, security, compliance, and budget.

### 2. Design architecture

Choose networking, compute, storage/database, identity, deployment, monitoring, backup, and disaster recovery.

### 3. Store everything in Git

Store app code, Dockerfiles, IaC, Kubernetes manifests, pipelines, and documentation together with reviewable history.

### 4. Support local development

Developers should be able to run tests and containers locally before using cloud resources.

### 5. Build CI checks

Run formatting, linting, unit tests, security scans, IaC validation, and builds automatically.

### 6. Produce an immutable artifact

Build one versioned Docker image. Promote that same tested image between environments instead of rebuilding unknown differences.

### 7. Provision infrastructure as code

Use a workflow like:

```text
Pull request -> validate -> plan -> review -> apply
```

### 8. Deploy to development or staging

Deploy automatically and run smoke checks: health endpoint, API request, pod readiness, logs, and error rate.

### 9. Approve production promotion

After validation, promote the exact tested artifact using protected branches/environments and approval gates.

### 10. Observe continuously

Watch logs, metrics, traces, uptime, errors, latency, cost, and security findings.

### 11. Respond to incidents

Acknowledge the alert, identify impact, inspect telemetry, mitigate or roll back, find root cause, document it, and improve preventive controls.

### 12. Improve continuously

```text
Plan -> Code -> Test -> Build -> Release -> Deploy -> Operate -> Monitor -> Learn -> Plan again
```

## 20. Normal junior DevOps work

A junior DevOps engineer may:

- investigate failed CI jobs;
- update Dockerfiles;
- run or review Terraform plans;
- update infrastructure variables/modules;
- inspect pods and logs with kubectl;
- investigate CloudWatch alarms;
- tune IAM permissions;
- patch dependencies or images;
- update runbooks and diagrams;
- check cloud spending;
- work with developers during deployments and incidents.

---

# Part I — Honest production-readiness review

## 21. What works and was verified

- Two applications and automated tests
- Multi-stage, non-root Docker images
- Terraform AWS foundation and remote state
- Separate app and infrastructure pipeline paths
- OIDC authentication with temporary credentials
- ECR images tagged by Git SHA
- Automatic EKS development deployment
- Hardened pods and restricted Pod Security Admission
- Single ALB path routing
- HPA and NetworkPolicy enforcement
- CloudWatch logs, metrics, dashboard, and alarm
- GuardDuty and Security Hub

## 22. What should improve before production

1. Add separate dev/prod Kustomize overlays.
2. Trigger deployment for `k8s/**` changes.
3. Remove the race where parallel app jobs both apply the entire base.
4. Provide all Terraform variables to GitLab CI; ignored `dev.tfvars` is not available there.
5. Reduce the deploy role's Kubernetes cluster-admin permission.
6. Mount Secrets Manager values when apps need secrets.
7. Manage the Load Balancer Controller and Metrics Server declaratively.
8. Tighten NetworkPolicy ingress to the intended source.
9. Add HTTPS using a domain, ACM certificate, DNS record, and ALB HTTPS listener.
10. Add a persistent database.
11. Add SAST, dependency, container, IaC, and secret scanning.
12. Add backup, disaster recovery, and proper multi-environment/account design.

---

## 23. Interview-ready summary

> I built a two-service AWS DevOps platform using Terraform, GitLab CI, Docker, ECR, and EKS. Infrastructure and application changes use separate path-filtered workflows and separate OIDC IAM roles, so no static AWS credentials are stored. Application changes are tested, built by Kaniko, tagged with the Git SHA, pushed to ECR, and automatically deployed to a hardened EKS development environment. Kubernetes uses non-root read-only pods, probes, resource limits, restricted Pod Security Admission, RBAC, NetworkPolicies, HPA, and one ALB for path routing. CloudWatch collects logs and metrics and sends ALB 5xx alarms through SNS, while GuardDuty and Security Hub provide cloud security monitoring. The environment is reproducible and removable with Terraform to control cost.

## 24. Five sentences to remember

1. **Git stores the truth and history.**
2. **CI tests every change before delivery.**
3. **Docker creates one repeatable application package.**
4. **Terraform builds AWS; Kubernetes keeps applications running.**
5. **CloudWatch and AWS security services report when something is wrong.**
