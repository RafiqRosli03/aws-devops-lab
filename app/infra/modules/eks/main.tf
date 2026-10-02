# ---------------------------------------------------------------------------
# EKS MODULE - wraps the community terraform-aws-modules/eks module.
# Control plane + one managed node group in the private subnets.
# ---------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Public API endpoint so you can run kubectl from your laptop in the lab.
  cluster_endpoint_public_access = true

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Give the Terraform caller admin on the cluster (so kubectl works right away).
  enable_cluster_creator_admin_permissions = true

  # Additional IAM principals granted Kubernetes access (e.g. the GitLab deploy role).
  access_entries = var.access_entries

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      # Enable Kubernetes NetworkPolicy enforcement in the VPC CNI (off by
      # default). Required for our default-deny NetworkPolicies to actually
      # block traffic (Phase 4).
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
      })
    }
    # Phase 5: CloudWatch Container Insights - deploys the CloudWatch agent +
    # Fluent Bit as DaemonSets to ship pod/node metrics and container logs.
    amazon-cloudwatch-observability = {}
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min
      max_size       = var.node_max
      desired_size   = var.node_desired
      # Phase 5: let the CloudWatch agent on the nodes ship logs/metrics.
      iam_role_additional_policies = {
        CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
    }
  }

  tags = var.tags
}
