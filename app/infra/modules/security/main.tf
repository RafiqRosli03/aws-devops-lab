# ---------------------------------------------------------------------------
# SECURITY MODULE - a KMS key and placeholder app secrets in Secrets Manager.
# Real secret values are set out-of-band, NOT stored in Terraform code/state.
# ---------------------------------------------------------------------------

resource "aws_kms_key" "this" {
  description             = "${var.name} app secrets/logs encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}

# Placeholder secrets - one per app. Values are set later via the console/CLI,
# so no secret material lives in this repo or in Terraform state.
resource "aws_secretsmanager_secret" "app" {
  for_each   = toset(var.secret_names)
  name       = "${var.name}/${each.value}"
  kms_key_id = aws_kms_key.this.arn
  tags       = var.tags
}
