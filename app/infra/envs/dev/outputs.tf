# Outputs Phase 3 (GitLab CI) will consume.
# (infra pipeline smoke test trigger)

output "region" {
  value = var.region
}

output "ecr_repository_urls" {
  description = "Push images here (map: app -> URL)."
  value       = module.ecr.repository_urls
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "gitlab_deploy_role_arn" {
  description = "Narrow role the APP pipeline assumes via OIDC (ECR/EKS/secrets)."
  value       = module.iam_oidc.deploy_role_arn
}

output "gitlab_terraform_role_arn" {
  description = "Privileged role the TERRAFORM pipeline assumes via OIDC."
  value       = module.iam_oidc.terraform_role_arn
}

output "kms_key_arn" {
  value = module.security.kms_key_arn
}

output "secret_arns" {
  value = module.security.secret_arns
}

output "kubeconfig_command" {
  description = "Run this to connect kubectl."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "alb_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller."
  value       = module.alb_controller.role_arn
}
