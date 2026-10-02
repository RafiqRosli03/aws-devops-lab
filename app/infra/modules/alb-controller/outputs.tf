output "role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller ServiceAccount."
  value       = aws_iam_role.this.arn
}
