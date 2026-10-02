output "kms_key_arn" {
  value = aws_kms_key.this.arn
}

output "secret_arns" {
  value = [for s in aws_secretsmanager_secret.app : s.arn]
}
