# ---------------------------------------------------------------------------
# IAM / OIDC MODULE - lets GitLab CI assume an AWS role WITHOUT static keys.
# Creates the GitLab OIDC provider + a deploy role scoped to your project.
# ---------------------------------------------------------------------------

# GitLab's OIDC ID tokens are signed by this issuer. For gitlab.com it's
# https://gitlab.com ; for self-hosted use your instance URL.
data "tls_certificate" "gitlab" {
  url = "${var.gitlab_url}/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "gitlab" {
  url             = var.gitlab_url
  client_id_list  = [var.gitlab_url]
  thumbprint_list = [data.tls_certificate.gitlab.certificates[0].sha1_fingerprint]
  tags            = var.tags
}

# Trust policy: only ID tokens from YOUR GitLab project path may assume the role.
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.gitlab.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.gitlab_url, "https://", "")}:aud"
      values   = [var.gitlab_url]
    }
    condition {
      test     = "StringLike"
      variable = "${replace(var.gitlab_url, "https://", "")}:sub"
      # Scope to your project path, e.g. "project_path:your-group/devops-lab:*"
      values = ["project_path:${var.gitlab_project_path}:*"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "${var.name}-gitlab-deploy"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

# Least-privilege deploy permissions: push to ECR, talk to EKS, read secrets.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid    = "EcrAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = var.ecr_repository_arns
  }
  statement {
    sid       = "EksDescribe"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = [var.eks_cluster_arn]
  }
  statement {
    sid       = "ReadSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = var.secret_arns
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.name}-gitlab-deploy-policy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

# ---------------------------------------------------------------------------
# TERRAFORM ROLE - a SEPARATE, more privileged role the Terraform CI/CD
# pipeline assumes (kept distinct from the narrow app-deploy role above).
# Reuses the same GitLab OIDC provider; same project-scoped trust.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "terraform" {
  name               = "${var.name}-gitlab-terraform"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

# Broad permissions so Terraform can manage the full stack (VPC/EKS/ECR/KMS/
# Secrets). PowerUserAccess covers most services but NOT IAM, so IAM management
# (this project creates IAM roles/policies) is added explicitly below.
# NOTE: broad by design for a lab. For production, scope to only the services
# and actions actually used.
resource "aws_iam_role_policy_attachment" "terraform_poweruser" {
  role       = aws_iam_role.terraform.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# IAM + state-backend access that PowerUserAccess does not grant.
data "aws_iam_policy_document" "terraform_extra" {
  statement {
    sid    = "IamManagement"
    effect = "Allow"
    actions = [
      "iam:*"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "TerraformStateBackend"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "terraform_extra" {
  name   = "${var.name}-gitlab-terraform-extra"
  role   = aws_iam_role.terraform.id
  policy = data.aws_iam_policy_document.terraform_extra.json
}
