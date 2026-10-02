# ---------------------------------------------------------------------------
# DEV ENVIRONMENT - wires all modules together.
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = local.tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  name = "devops-lab-dev"
  tags = {
    Project     = "devops-lab"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
  # Constructed EKS cluster ARN (used to scope the GitLab deploy role).
  eks_cluster_arn = "arn:aws:eks:${var.region}:${var.account_id}:cluster/${local.name}"
}

module "network" {
  source   = "../../modules/network"
  name     = local.name
  vpc_cidr = var.vpc_cidr
  tags     = local.tags
}

module "ecr" {
  source           = "../../modules/ecr"
  repository_names = ["orders-node", "users-python"]
  tags             = local.tags
}

module "security" {
  source       = "../../modules/security"
  name         = local.name
  secret_names = ["orders-node", "users-python"]
  tags         = local.tags
}

module "eks" {
  source              = "../../modules/eks"
  cluster_name        = local.name
  cluster_version     = var.cluster_version
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_min            = var.node_min
  node_max            = var.node_max
  node_desired        = var.node_desired
  tags                = local.tags

  # Let the GitLab app-deploy role run kubectl against the cluster.
  # (IAM lets it reach the API; this grants the Kubernetes-side RBAC.)
  access_entries = {
    gitlab_deploy = {
      principal_arn = module.iam_oidc.deploy_role_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}

module "iam_oidc" {
  source              = "../../modules/iam-oidc"
  name                = local.name
  gitlab_url          = var.gitlab_url
  gitlab_project_path = var.gitlab_project_path
  ecr_repository_arns = values(module.ecr.repository_arns)
  eks_cluster_arn     = local.eks_cluster_arn
  secret_arns         = module.security.secret_arns
  tags                = local.tags
}

# IRSA role for the AWS Load Balancer Controller (Phase 4 - creates the ALB).
module "alb_controller" {
  source            = "../../modules/alb-controller"
  cluster_name      = local.name
  oidc_provider_arn = module.eks.oidc_provider_arn
  # Strip the https:// prefix for the IAM condition keys.
  oidc_provider = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  tags          = local.tags
}

# Phase 5: observability + security posture (CloudWatch dashboard/alarm, SNS,
# GuardDuty, Security Hub). Container Insights agent is enabled on the cluster
# via the EKS addon.
module "observability" {
  source         = "../../modules/observability"
  name           = local.name
  region         = var.region
  cluster_name   = local.name
  alert_email    = var.alert_email
  alb_arn_suffix = var.alb_arn_suffix
  tags           = local.tags
}
