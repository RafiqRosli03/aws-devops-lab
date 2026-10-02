# Remote state - uses the S3 bucket + DynamoDB table created by infra/bootstrap.
# Run `terraform init` here AFTER the bootstrap apply has completed.
terraform {
  backend "s3" {
    bucket  = "devops-lab-tfstate-497862079645"
    key     = "envs/dev/terraform.tfstate"
    region  = "ap-southeast-5"
    encrypt = true
    # Terraform >= 1.10 supports native S3 state locking (no DynamoDB needed).
    use_lockfile = true
  }
}
