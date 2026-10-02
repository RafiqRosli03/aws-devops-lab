output "deploy_role_arn" {
  description = "Role ARN GitLab CI assumes via OIDC (set in .gitlab-ci.yml)."
  value       = aws_iam_role.deploy.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.gitlab.arn
}

output "terraform_role_arn" {
  description = "Role ARN the Terraform CI/CD pipeline assumes via OIDC."
  value       = aws_iam_role.terraform.arn
}
