# ---------------------------------------------------------------------------
# ALB CONTROLLER module - IRSA role + IAM policy for the AWS Load Balancer
# Controller. The controller runs in the cluster and creates ALBs for Ingress
# objects. It authenticates to AWS via IRSA (IAM Roles for Service Accounts):
# the cluster OIDC provider lets the controller's ServiceAccount assume this
# role - no node-wide credentials.
# ---------------------------------------------------------------------------

# The official IAM policy published by the controller project.
resource "aws_iam_policy" "this" {
  name   = "${var.cluster_name}-alb-controller"
  policy = file("${path.module}/iam_policy.json")
  tags   = var.tags
}

# Trust policy: the kube-system/aws-load-balancer-controller ServiceAccount
# (via the cluster OIDC provider) may assume this role.
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
