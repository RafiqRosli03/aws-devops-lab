output "repository_urls" {
  description = "Map of repo name -> repository URL (for the CI pipeline)."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "repository_arns" {
  value = { for k, r in aws_ecr_repository.this : k => r.arn }
}
